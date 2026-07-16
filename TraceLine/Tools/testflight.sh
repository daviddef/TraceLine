#!/bin/bash
# Archives TraceLine and uploads it to TestFlight.
#
# Prerequisites (see README.md § TestFlight):
#   - The bundle ID exists as an App ID in the developer portal AND as an app
#     record in App Store Connect. Upload fails otherwise.
#   - An App Store Connect API key (.p8) in ~/.appstoreconnect/private_keys/
#
# Usage:
#   TEAM_ID=XXXXXXXXXX BUNDLE_ID=com.example.traceline \
#   ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
#   Tools/testflight.sh
#
# Pass BUILD=<n> to set the build number; defaults to a timestamp, which is always
# higher than the last one — App Store Connect rejects a duplicate build number.

set -euo pipefail
cd "$(dirname "$0")/.."

: "${TEAM_ID:?set TEAM_ID (10-char Apple Developer team id)}"
: "${BUNDLE_ID:?set BUNDLE_ID (must match the App Store Connect app record)}"
: "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect API key id)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (App Store Connect issuer UUID)}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
[ -f "$ASC_KEY_PATH" ] || { echo "API key not found at $ASC_KEY_PATH"; exit 1; }

ARCHIVE="build/TraceLine.xcarchive"
EXPORT_DIR="build/export"
OPTS="build/ExportOptions.plist"

# Authenticates provisioning against App Store Connect with the API key, so no
# interactive Xcode account login is needed.
AUTH=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

echo "==> Regenerating project"
xcodegen generate

echo "==> Archiving (build $BUILD, bundle $BUNDLE_ID, team $TEAM_ID)"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p build
xcodebuild archive \
  -project TraceLine.xcodeproj \
  -scheme TraceLine \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  "${AUTH[@]}" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$BUILD"

echo "==> Exporting .ipa"
sed "s/TRACELINE_TEAM_ID/$TEAM_ID/" Tools/ExportOptions.plist > "$OPTS"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTS" \
  "${AUTH[@]}"

IPA=$(find "$EXPORT_DIR" -name "*.ipa" | head -1)
[ -n "$IPA" ] || { echo "no .ipa produced"; exit 1; }

echo "==> Validating $IPA"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "==> Uploading to TestFlight"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "==> Done. Build $BUILD is processing in App Store Connect."
