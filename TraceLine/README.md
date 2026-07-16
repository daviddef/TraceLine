# TraceLine — iOS

Swift 5.9 / SpriteKit / iOS 16+. iPhone portrait only. Built to the spec in
`../HANDOVER.md` and `../SWIFT_ARCHITECTURE.md`.

## Project generation

`HANDOVER.md` describes creating the project through Xcode's Game template. This repo
uses **XcodeGen** instead so the project is reproducible from a text file —
`TraceLine.xcodeproj` is generated output and shouldn't be hand-edited.

```sh
brew install xcodegen        # if needed
xcodegen generate            # rebuild TraceLine.xcodeproj after adding/removing files
open TraceLine.xcodeproj
```

Adding a source file means dropping it under `TraceLine/` and re-running `xcodegen
generate` — there is no target membership to manage.

## Build, test, run

```sh
xcodebuild -project TraceLine.xcodeproj -scheme TraceLine \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project TraceLine.xcodeproj -scheme TraceLine \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Simulator builds need no signing. Device and archive builds take their identity from
the command line — see § TestFlight.

## Debug launch arguments

| Argument | Effect |
|---|---|
| `--reset-progress` | Wipes stars, scores and theme choice at launch |
| `--unlock-all` | Unlocks every level (reach obstacle levels directly) |
| `--debug-win` | Boots straight into `WinScene` with sample data (DEBUG only) |

```sh
xcrun simctl launch "iPhone 17" com.yourname.traceline --unlock-all
```

## TestFlight

Store listing "TraceLine!", bundle ID `com.defranceski.traceline`.

```sh
TEAM_ID=<team-id> BUNDLE_ID=com.defranceski.traceline \
ASC_KEY_ID=<key-id> ASC_ISSUER_ID=<issuer-uuid> \
Tools/testflight.sh
```

The script archives, exports an `.ipa`, validates it, and uploads. It authenticates
with the App Store Connect API key, so no interactive Xcode login is needed. The build
number defaults to a timestamp — App Store Connect rejects a build number it has seen
before.

Credentials are passed in, never committed — this repo is public. The key id and issuer
UUID come from App Store Connect → Users and Access → Integrations; the matching
`AuthKey_<key-id>.p8` belongs in `~/.appstoreconnect/private_keys/` and must stay out of
git. Both provisioning and upload need the issuer.

**The app record must exist before the first upload.** The App Store Connect API has no
endpoint for creating apps, so it has to be made once in the web UI (Apps → + → New App)
against the bundle ID above. Without it, `altool` fails with:

```
ERROR: Cannot determine the Apple ID from Bundle ID 'com.defranceski.traceline'
```

The App ID itself is already registered in the developer portal — automatic signing
created it, along with the distribution certificate, during the first archive.

The app icon is generated, not hand-drawn — see `Tools/generate_icon.py`. App Store
icons must be opaque; an alpha channel is rejected at upload.

## Game Center

`Tools/gamecenter_setup.py` creates the leaderboard and achievements over the API. The
vendor identifiers it writes must match the constants in `Core/GameCenter.swift` — Game
Center ignores unknown ids silently, so a mismatch shows up as an empty leaderboard and
no error anywhere.

```sh
ASC_KEY_ID=... ASC_ISSUER_ID=... APP_ID=... BUNDLE_ID_RESOURCE=... \
python3 Tools/gamecenter_setup.py
```

Game Center is entitlement-gated (`Resources/TraceLine.entitlements`) *and* gated on the
`GAME_CENTER` capability on the App ID. Without both, `GKLocalPlayer` never authenticates
and every submission no-ops. Note the simulator does not apply profile-based entitlements,
so entitlements can only be verified from a device archive — and simulator Game Center
sign-in is unreliable, so test scores on a real device.

## Store listing

Screenshots are captured from the app itself, at Apple's required 6.9" size:

```sh
xcodebuild test -project TraceLine.xcodeproj -scheme TraceLine -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:TraceLineUITests/ScreenshotTests -resultBundlePath /tmp/shots.xcresult
xcrun xcresulttool export attachments --path /tmp/shots.xcresult --output-path /tmp/shots
```

`Tools/store_metadata.py` then pushes the listing text, categories, age rating and those
screenshots. It is idempotent.

```sh
ASC_KEY_ID=... ASC_ISSUER_ID=... APP_ID=... SHOTS_DIR=/tmp/shots \
python3 Tools/store_metadata.py
```

API quirks worth knowing, all learned the hard way:

- There is no `APP_IPHONE_69` slot. 6.9" art (1320×2868) uploads to `APP_IPHONE_67`.
- There is no `GAMES_ARCADE` subcategory. Games allows Action, Strategy, Sports, Casual,
  Trivia, Puzzle, Casino, Family, Adventure, Board.
- `appInfos` category relationships must be PATCHed one per request.
- `ageRatingDeclaration` hangs off `appInfo`, not `app`, and `healthOrWellnessTopics` is
  a boolean despite reading like the enum-valued content fields.

**Still manual in the web UI** — no API exists for either:

1. Creating the app record (`POST /v1/apps` returns 403 `does not allow 'CREATE'`).
2. The App Privacy questionnaire (all `appDataUsages` endpoints 404). For TraceLine the
   answer is **Data Not Collected** — see [PRIVACY.md](../PRIVACY.md).

## Layout

- `Core/` — `DrawingEngine` (the two rules), `GeometryHelpers`, `Theme`, `GameState`,
  plus `GameCenter` and `Haptics`/`SoundHook` wrappers.
- `Models/` — `LevelConfig` (+ `Resources/levels.json`), `RoundScore`, `PlayerProgress`.
- `Nodes/` — `LineNode`, `ObstacleNode`, `HUDNode`, `GridNode`, `ButtonNode`.
- `Scenes/` — one file per screen; all six are built in code, no `.sks` files.

`DrawingEngine` has no SpriteKit dependency: `GameScene` feeds it touch points and
`ObstacleDescriptor` values, and it answers with a `DrawResult`. That's what makes the
game rules unit-testable — see `TraceLineTests/DrawingEngineTests.swift`.

## Not built in v1

Multiplayer, iCloud sync, IAP, iPad layout, audio assets (hooks only in `SoundHook`),
analytics. Also not built: the pause overlay is minimal and only reachable before a
round starts, and there is no Settings screen (the wireframe shows one; the
architecture spec's file list does not).
