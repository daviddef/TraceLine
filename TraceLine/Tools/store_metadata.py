#!/usr/bin/env python3
"""Pushes TraceLine's App Store listing metadata and screenshots to App Store Connect.

Idempotent — re-running updates in place rather than duplicating.

Usage:
    ASC_KEY_ID=... ASC_ISSUER_ID=... APP_ID=... SHOTS_DIR=/path/to/pngs \
    python3 Tools/store_metadata.py
"""

import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
APP_ID = os.environ["APP_ID"]
SHOTS_DIR = Path(os.environ["SHOTS_DIR"]) if os.environ.get("SHOTS_DIR") else None
KEY_PATH = Path.home() / f".appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"

REPO = "https://github.com/daviddef/TraceLine"

CATEGORIES = [
    ("primaryCategory", "GAMES"),
    ("primarySubcategoryOne", "GAMES_PUZZLE"),
    ("primarySubcategoryTwo", "GAMES_ACTION"),
]

SUBTITLE = "Draw. Survive. Don't lift."

DESCRIPTION = """One line. One finger. Don't lift, don't cross.

TraceLine is a game of nerve and planning. Press your finger to the screen and a line follows it. Fill enough of the board before the clock runs out — but the moment you lift your finger, the round is over. Cross your own line, and it's over too.

Every level is a race against your own path. The more you draw, the less room you leave yourself. Plan too little and you strand yourself in a corner with nowhere legal to go. Take too long and the timer beats you.

From level 6, obstacles fall from the top of the screen. Weave around them without breaking your line — and without doubling back into the path you have already drawn.

FEATURES

• One-finger controls. Anyone can play it. Nobody can relax.
• 10 hand-tuned levels across World 1
• Four visual themes: Neon, Clay, Retro and Watercolour
• Three stars per level — clear it, clear it fast, clear it clean
• Game Center leaderboard and achievements
• No ads. No in-app purchases. No account. No sign-up.

Plays entirely offline. Nothing you do leaves your device."""

# 100 characters max, comma-separated. The app name is indexed separately, so it is
# deliberately not repeated here.
KEYWORDS = "line,draw,puzzle,arcade,one line,trace,maze,reflex,minimal,skill,brain,logic,finger,survival"

PROMOTIONAL = ("Ten levels, four themes, and one rule you will break constantly: "
               "don't lift your finger. Now with Game Center leaderboards and achievements.")


def token():
    return jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 1200,
         "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None, raw=None, headers=None):
    url = path if path.startswith("http") else f"{BASE}{path}"
    h = {"Authorization": f"Bearer {token()}"}
    if raw is None:
        h["Content-Type"] = "application/json"
    h.update(headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body else None)
    req = urllib.request.Request(url, method=method, headers=h, data=data)
    try:
        with urllib.request.urlopen(req) as r:
            payload = r.read()
            return r.status, (json.loads(payload) if payload and r.headers.get(
                "Content-Type", "").startswith("application/") else {})
    except urllib.error.HTTPError as e:
        body_ = e.read()
        try:
            return e.code, json.loads(body_) if body_ else {}
        except json.JSONDecodeError:
            return e.code, {"errors": [{"detail": body_.decode()[:200]}]}


def show_errors(label, status, data):
    print(f"  ! {label} ({status})")
    for e in data.get("errors", []):
        print(f"      {e.get('title')}: {e.get('detail')}")


def version_and_localization():
    s, d = call("GET", f"/apps/{APP_ID}/appStoreVersions?limit=1")
    ver = d["data"][0]["id"]
    s, d = call("GET", f"/appStoreVersions/{ver}/appStoreVersionLocalizations")
    return ver, d["data"][0]["id"], d["data"][0]["attributes"]["locale"]


def set_version_metadata(loc_id):
    s, d = call("PATCH", f"/appStoreVersionLocalizations/{loc_id}", {
        "data": {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": {
            "description": DESCRIPTION,
            "keywords": KEYWORDS,
            "promotionalText": PROMOTIONAL,
            "supportUrl": f"{REPO}/issues",
            "marketingUrl": REPO,
        }}})
    if s == 200:
        print(f"Listing text: set (keywords {len(KEYWORDS)}/100 chars)")
    else:
        show_errors("listing text", s, d)


def set_app_info(subtitle_locale):
    s, d = call("GET", f"/apps/{APP_ID}/appInfos")
    info_id = d["data"][0]["id"]

    # One relationship per request: sending them together is rejected. Note there is
    # no GAMES_ARCADE — Apple's Games subcategories are Action, Strategy, Sports,
    # Casual, Trivia, Puzzle, Casino, Family, Adventure, Board.
    for rel, value in CATEGORIES:
        s, d = call("PATCH", f"/appInfos/{info_id}", {
            "data": {"type": "appInfos", "id": info_id,
                     "relationships": {rel: {"data": {"type": "appCategories", "id": value}}}}})
        print(f"Category {rel}: {value}" if s == 200 else "")
        if s != 200:
            show_errors(f"category {rel}={value}", s, d)

    s, d = call("GET", f"/appInfos/{info_id}/appInfoLocalizations")
    for l in d.get("data", []):
        if l["attributes"]["locale"] != subtitle_locale:
            continue
        s2, d2 = call("PATCH", f"/appInfoLocalizations/{l['id']}", {
            "data": {"type": "appInfoLocalizations", "id": l["id"], "attributes": {
                "subtitle": SUBTITLE,
                "privacyPolicyUrl": f"{REPO}/blob/main/PRIVACY.md",
            }}})
        if s2 == 200:
            print(f"Subtitle + privacy policy URL: set ({len(SUBTITLE)}/30 chars)")
        else:
            show_errors("subtitle/privacy url", s2, d2)
    return info_id


def set_age_rating(info_id):
    s, d = call("GET", f"/appInfos/{info_id}/ageRatingDeclaration")
    if not d.get("data"):
        print("  ! no ageRatingDeclaration to patch")
        return
    decl_id = d["data"]["id"]
    # Apple's 2025 questionnaire. Types are not guessable from the field names —
    # healthOrWellnessTopics reads like the other content ratings but is a boolean.
    # None of it applies to a line-drawing puzzle, which resolves to 4+.
    rated_none = [
        "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated",
        "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "horrorOrFearThemes",
        "matureOrSuggestiveThemes", "sexualContentGraphicAndNudity",
        "sexualContentOrNudity", "violenceCartoonOrFantasy", "violenceRealistic",
        "violenceRealisticProlongedGraphicOrSadistic", "gunsOrOtherWeapons",
    ]
    flags_false = [
        "gambling", "unrestrictedWebAccess", "lootBox", "advertising", "messagingAndChat",
        "socialMedia", "socialMediaAgeRestricted", "userGeneratedContent",
        "parentalControls", "ageAssurance", "healthOrWellnessTopics",
    ]
    attrs = {k: "NONE" for k in rated_none}
    attrs.update({k: False for k in flags_false})
    attrs["kidsAgeBand"] = None
    s, d = call("PATCH", f"/ageRatingDeclarations/{decl_id}",
                {"data": {"type": "ageRatingDeclarations", "id": decl_id, "attributes": attrs}})
    print("Age rating: declared (no objectionable content → 4+)" if s == 200 else "")
    if s != 200:
        show_errors("age rating", s, d)


def upload_screenshots(loc_id):
    if not SHOTS_DIR:
        return
    shots = sorted(SHOTS_DIR.glob("0*.png"))
    if not shots:
        print("  ! no screenshots found")
        return

    # Apple has no APP_IPHONE_69: the 6.7" slot is what accepts 6.9" 1320x2868 art.
    display_type = "APP_IPHONE_67"
    s, d = call("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    set_id = next((x["id"] for x in d.get("data", [])
                   if x["attributes"]["screenshotDisplayType"] == display_type), None)
    if not set_id:
        s, d = call("POST", "/appScreenshotSets", {
            "data": {"type": "appScreenshotSets",
                     "attributes": {"screenshotDisplayType": display_type},
                     "relationships": {"appStoreVersionLocalization": {
                         "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})
        if s not in (200, 201):
            return show_errors("create screenshot set", s, d)
        set_id = d["data"]["id"]

    s, d = call("GET", f"/appScreenshotSets/{set_id}/appScreenshots")
    have = {x["attributes"].get("fileName") for x in d.get("data", [])}

    for shot in shots:
        if shot.name in have:
            print(f"Screenshot {shot.name}: already uploaded")
            continue
        blob = shot.read_bytes()

        # 1. Reserve
        s, d = call("POST", "/appScreenshots", {
            "data": {"type": "appScreenshots",
                     "attributes": {"fileName": shot.name, "fileSize": len(blob)},
                     "relationships": {"appScreenshotSet": {
                         "data": {"type": "appScreenshotSets", "id": set_id}}}}})
        if s not in (200, 201):
            show_errors(f"reserve {shot.name}", s, d)
            continue
        shot_id = d["data"]["id"]

        # 2. Upload each chunk to the URL Apple hands back
        for op in d["data"]["attributes"]["uploadOperations"]:
            chunk = blob[op["offset"]:op["offset"] + op["length"]]
            hdrs = {h["name"]: h["value"] for h in op["requestHeaders"]}
            req = urllib.request.Request(op["url"], method=op["method"], data=chunk, headers=hdrs)
            try:
                urllib.request.urlopen(req).read()
            except urllib.error.HTTPError as e:
                print(f"  ! chunk upload failed for {shot.name}: {e.code}")
                break

        # 3. Commit with a checksum so Apple can verify the bytes
        s, d = call("PATCH", f"/appScreenshots/{shot_id}", {
            "data": {"type": "appScreenshots", "id": shot_id, "attributes": {
                "uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
        print(f"Screenshot {shot.name}: uploaded" if s == 200
              else f"  ! commit failed for {shot.name} ({s})")


def main():
    if not KEY_PATH.exists():
        sys.exit(f"API key not found at {KEY_PATH}")
    ver_id, loc_id, locale = version_and_localization()
    print(f"App {APP_ID}, version {ver_id}, locale {locale}\n")
    set_version_metadata(loc_id)
    info_id = set_app_info(locale)
    set_age_rating(info_id)
    upload_screenshots(loc_id)


if __name__ == "__main__":
    main()
