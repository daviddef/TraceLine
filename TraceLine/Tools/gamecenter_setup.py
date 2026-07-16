#!/usr/bin/env python3
"""Creates TraceLine's Game Center leaderboard and achievements in App Store Connect.

The identifiers here must match the constants in Core/GameCenter.swift — a mismatch
fails silently at runtime, which is exactly the kind of bug that survives to release.

Idempotent: anything that already exists is left alone, so this is safe to re-run.

Usage:
    ASC_KEY_ID=... ASC_ISSUER_ID=... APP_ID=... BUNDLE_ID_RESOURCE=... \
    python3 Tools/gamecenter_setup.py
"""

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
BUNDLE_RESOURCE_ID = os.environ.get("BUNDLE_ID_RESOURCE")
LOCALE = os.environ.get("ASC_LOCALE", "en-AU")
KEY_PATH = Path.home() / f".appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"

BASE = "https://api.appstoreconnect.apple.com/v1"

# Mirrors GameCenter.leaderboardID
LEADERBOARD = {
    "vendor_id": "traceline.highscore.alltime",
    "reference_name": "TraceLine All-Time High Score",
    "title": "All-Time High Score",
}

# Mirrors GameCenter.Achievement. Apple caps the total across all achievements at 1000.
ACHIEVEMENTS = [
    {
        "vendor_id": "traceline.firstclear",
        "reference_name": "First Clear",
        "points": 10,
        "title": "First Trace",
        "before": "Complete level 1.",
        "after": "You completed level 1 without lifting or crossing.",
    },
    {
        "vendor_id": "traceline.nolift10",
        "reference_name": "Ten Levels No Lift",
        "points": 50,
        "title": "Steady Hand",
        "before": "Complete 10 levels.",
        "after": "You completed 10 levels without ever lifting your finger.",
    },
    {
        "vendor_id": "traceline.speedrun",
        "reference_name": "Speedrun",
        "points": 25,
        "title": "Quick Draw",
        "before": "Clear a level with 20 or more seconds remaining.",
        "after": "You cleared a level with 20+ seconds to spare.",
    },
]


def token():
    return jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 900,
         "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(), algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def call(method, path, body=None):
    url = path if path.startswith("http") else f"{BASE}{path}"
    req = urllib.request.Request(
        url, method=method,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body else None,
    )
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            return e.code, {"errors": [{"detail": raw.decode()[:300]}]}


def fail(step, status, data):
    print(f"  FAILED ({status}) {step}")
    for e in data.get("errors", []):
        print(f"    {e.get('title')}: {e.get('detail')}")
    sys.exit(1)


def enable_app_id_capability():
    if not BUNDLE_RESOURCE_ID:
        return
    s, d = call("GET", f"/bundleIds/{BUNDLE_RESOURCE_ID}/bundleIdCapabilities")
    caps = [c["attributes"]["capabilityType"] for c in d.get("data", [])]
    if "GAME_CENTER" in caps:
        print("App ID: GAME_CENTER already enabled")
        return
    s, d = call("POST", "/bundleIdCapabilities", {
        "data": {"type": "bundleIdCapabilities",
                 "attributes": {"capabilityType": "GAME_CENTER"},
                 "relationships": {"bundleId": {"data": {"type": "bundleIds",
                                                         "id": BUNDLE_RESOURCE_ID}}}}})
    if s not in (200, 201):
        fail("enable GAME_CENTER on App ID", s, d)
    print("App ID: GAME_CENTER enabled")


def game_center_detail():
    s, d = call("GET", f"/apps/{APP_ID}/gameCenterDetail")
    if d.get("data"):
        print(f"Game Center: already enabled (detail {d['data']['id']})")
        return d["data"]["id"]
    s, d = call("POST", "/gameCenterDetails", {
        "data": {"type": "gameCenterDetails",
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    if s not in (200, 201):
        fail("enable Game Center for app", s, d)
    print(f"Game Center: enabled (detail {d['data']['id']})")
    return d["data"]["id"]


def existing(detail_id, kind):
    """Map of vendorIdentifier -> resource id for leaderboards or achievements."""
    out, url = {}, f"/gameCenterDetails/{detail_id}/{kind}?limit=200"
    while url:
        s, d = call("GET", url)
        if s != 200:
            return out
        for item in d.get("data", []):
            out[item["attributes"]["vendorIdentifier"]] = item["id"]
        url = d.get("links", {}).get("next")
    return out


def create_leaderboard(detail_id, found):
    vid = LEADERBOARD["vendor_id"]
    if vid in found:
        print(f"Leaderboard: {vid} already exists")
        return
    s, d = call("POST", "/gameCenterLeaderboards", {
        "data": {"type": "gameCenterLeaderboards",
                 "attributes": {
                     "referenceName": LEADERBOARD["reference_name"],
                     "vendorIdentifier": vid,
                     "scoreSortType": "DESC",          # higher score is better
                     "submissionType": "BEST_SCORE",   # keep each player's best
                     "defaultFormatter": "INTEGER",
                 },
                 "relationships": {"gameCenterDetail": {
                     "data": {"type": "gameCenterDetails", "id": detail_id}}}}})
    if s not in (200, 201):
        fail(f"create leaderboard {vid}", s, d)
    lb_id = d["data"]["id"]

    s, d = call("POST", "/gameCenterLeaderboardLocalizations", {
        "data": {"type": "gameCenterLeaderboardLocalizations",
                 "attributes": {"locale": LOCALE, "name": LEADERBOARD["title"]},
                 "relationships": {"gameCenterLeaderboard": {
                     "data": {"type": "gameCenterLeaderboards", "id": lb_id}}}}})
    if s not in (200, 201):
        fail(f"localize leaderboard {vid}", s, d)
    print(f"Leaderboard: created {vid}")


def create_achievements(detail_id, found):
    for a in ACHIEVEMENTS:
        vid = a["vendor_id"]
        if vid in found:
            print(f"Achievement: {vid} already exists")
            continue
        s, d = call("POST", "/gameCenterAchievements", {
            "data": {"type": "gameCenterAchievements",
                     "attributes": {
                         "referenceName": a["reference_name"],
                         "vendorIdentifier": vid,
                         "points": a["points"],
                         "showBeforeEarned": True,
                         "repeatable": False,
                     },
                     "relationships": {"gameCenterDetail": {
                         "data": {"type": "gameCenterDetails", "id": detail_id}}}}})
        if s not in (200, 201):
            fail(f"create achievement {vid}", s, d)
        ach_id = d["data"]["id"]

        s, d = call("POST", "/gameCenterAchievementLocalizations", {
            "data": {"type": "gameCenterAchievementLocalizations",
                     "attributes": {
                         "locale": LOCALE,
                         "name": a["title"],
                         "beforeEarnedDescription": a["before"],
                         "afterEarnedDescription": a["after"],
                     },
                     "relationships": {"gameCenterAchievement": {
                         "data": {"type": "gameCenterAchievements", "id": ach_id}}}}})
        if s not in (200, 201):
            fail(f"localize achievement {vid}", s, d)
        print(f"Achievement: created {vid} ({a['points']} pts)")


def main():
    if not KEY_PATH.exists():
        sys.exit(f"API key not found at {KEY_PATH}")
    enable_app_id_capability()
    detail_id = game_center_detail()
    create_leaderboard(detail_id, existing(detail_id, "gameCenterLeaderboards"))
    create_achievements(detail_id, existing(detail_id, "gameCenterAchievements"))
    total = sum(a["points"] for a in ACHIEVEMENTS)
    print(f"\nDone. Achievement points: {total}/1000.")


if __name__ == "__main__":
    main()
