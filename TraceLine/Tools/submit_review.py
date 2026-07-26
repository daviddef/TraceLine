#!/usr/bin/env python3
"""Attaches the newest processed build to an App Store version and submits it for review.

Idempotent-ish: re-running finds the existing draft version and any open review
submission rather than duplicating. Apple allows only one open review submission per app
at a time.

Usage:
    ASC_KEY_ID=... ASC_ISSUER_ID=... APP_ID=... VERSION=1.1 \
    python3 Tools/submit_review.py           # attach build + submit for review
    ... SUBMIT=0 python3 Tools/submit_review.py   # attach build only, do not submit
"""

import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
APP_ID = os.environ["APP_ID"]
VERSION = os.environ.get("VERSION", "1.1")
DO_SUBMIT = os.environ.get("SUBMIT", "1") == "1"
KEY = Path.home() / f".appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"


def tok():
    return jwt.encode({"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 1200,
                       "aud": "appstoreconnect-v1"}, KEY.read_text(),
                      algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None):
    h = {"Authorization": f"Bearer {tok()}", "Content-Type": "application/json"}
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(f"{BASE}{path}", method=method, headers=h, data=data)
    try:
        with urllib.request.urlopen(req) as r:
            p = r.read()
            return r.status, (json.loads(p) if p else {})
    except urllib.error.HTTPError as e:
        b = e.read()
        try:
            return e.code, (json.loads(b) if b else {})
        except json.JSONDecodeError:
            return e.code, {"raw": b.decode()[:400]}


def newest_valid_build():
    """The most recently uploaded build that has finished processing."""
    s, d = call("GET", f"/builds?filter[app]={APP_ID}&limit=20&sort=-uploadedDate")
    for b in d.get("data", []):
        if b["attributes"].get("processingState") == "VALID":
            return b["id"], b["attributes"].get("version")
    return None, None


def main():
    # The draft version we are submitting.
    s, d = call("GET", f"/apps/{APP_ID}/appStoreVersions?limit=20")
    ver = next((v for v in d["data"] if v["attributes"]["versionString"] == VERSION), None)
    if not ver:
        print(f"No version {VERSION} found — create it first.")
        return
    ver_id = ver["id"]
    print(f"Version {VERSION}: {ver_id}  state={ver['attributes']['appStoreState']}")

    # Attach the newest processed build.
    build_id, build_ver = newest_valid_build()
    if not build_id:
        print("No VALID (processed) build yet — wait for processing and re-run.")
        return
    s, r = call("PATCH", f"/appStoreVersions/{ver_id}/relationships/build",
                {"data": {"type": "builds", "id": build_id}})
    print(f"Attach build {build_ver} ({build_id}): {'ok' if s in (200, 204) else 'FAIL ' + str(s) + ' ' + json.dumps(r)[:300]}")
    if s not in (200, 204):
        return

    if not DO_SUBMIT:
        print("SUBMIT=0 — build attached, stopping before review submission.")
        return

    # Reuse an open review submission if one exists, else create it.
    s, d = call("GET", f"/apps/{APP_ID}/reviewSubmissions?filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_PROGRESS&limit=1")
    if d.get("data"):
        sub_id = d["data"][0]["id"]
        print("Reusing open review submission:", sub_id)
    else:
        s, d = call("POST", "/reviewSubmissions", {"data": {"type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
        if s not in (200, 201):
            print("Create review submission FAILED", s, json.dumps(d)[:400])
            return
        sub_id = d["data"]["id"]
        print("Created review submission:", sub_id)

    # Add this version as an item on the submission (skip if already present).
    s, d = call("GET", f"/reviewSubmissions/{sub_id}/items")
    have = any(i.get("relationships", {}).get("appStoreVersion", {}).get("data", {}).get("id") == ver_id
               for i in d.get("data", []))
    if not have:
        s, d = call("POST", "/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}})
        print(f"Add version to submission: {'ok' if s in (200, 201) else 'FAIL ' + str(s) + ' ' + json.dumps(d)[:400]}")
        if s not in (200, 201):
            return
    else:
        print("Version already on submission.")

    # Submit.
    s, d = call("PATCH", f"/reviewSubmissions/{sub_id}",
                {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    if s in (200, 201):
        print(f"\nSUBMITTED FOR REVIEW — submission {sub_id}, state {d['data']['attributes'].get('state')}")
    else:
        print("SUBMIT FAILED", s, json.dumps(d)[:500])


if __name__ == "__main__":
    main()
