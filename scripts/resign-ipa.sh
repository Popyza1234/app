#!/usr/bin/env bash
# Re-sign an unsigned 3105 IPA with YOUR OWN enterprise certificate.
# Usage: ./scripts/resign-ipa.sh <unsigned.ipa> <signing-identity> <profile.mobileprovision> [output.ipa]
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: code signing requires macOS (security, codesign, PlistBuddy)." >&2
  exit 1
fi

IPA="${1:?usage: resign-ipa.sh <unsigned.ipa> <signing-identity> <profile.mobileprovision> [output.ipa]}"
IDENTITY="${2:?missing signing identity; list them with: security find-identity -v -p codesigning}"
PROFILE="${3:?missing .mobileprovision path}"
OUTPUT="${4:-${IPA%.ipa}-signed.ipa}"

for tool in security codesign unzip zip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: missing $tool" >&2; exit 1; }
done
[ -x /usr/libexec/PlistBuddy ] || { echo "error: missing /usr/libexec/PlistBuddy" >&2; exit 1; }
[ -f "$IPA" ] || { echo "error: IPA not found: $IPA" >&2; exit 1; }
[ -f "$PROFILE" ] || { echo "error: profile not found: $PROFILE" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Unpacking $IPA"
unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[ -n "$APP" ] && [ -d "$APP" ] || { echo "error: no .app inside Payload/" >&2; exit 1; }

echo "==> Reading profile and deriving entitlements"
security cms -D -i "$PROFILE" > "$WORK/profile.plist"
/usr/libexec/PlistBuddy -x -c 'Print :Entitlements' "$WORK/profile.plist" > "$WORK/entitlements.plist"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || true)"
PROFILE_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$WORK/profile.plist" 2>/dev/null || true)"
echo "    Bundle ID:                  $BUNDLE_ID"
echo "    Profile application-id:     $PROFILE_APP_ID"
if [ -n "$PROFILE_APP_ID" ] && [ -n "$BUNDLE_ID" ]; then
  case "$PROFILE_APP_ID" in
    *'*') echo "    warning: wildcard profile - verify it covers $BUNDLE_ID" >&2 ;;
    *".$BUNDLE_ID") ;;
    *) echo "error: profile does not match bundle ID $BUNDLE_ID" >&2; exit 1 ;;
  esac
fi
if [ "$BUNDLE_ID" != "com.apple.mobile.MobileHouseArrest" ]; then
  echo "    warning: bundle ID was changed; the MHA-C2 workflow may break." >&2
fi

cp "$PROFILE" "$APP/embedded.mobileprovision"
rm -rf "$APP/_CodeSignature" "$APP/CodeResources"

echo "==> Signing with: $IDENTITY"
# Older codesign builds may need --generate-entitlement-der for iOS 15+;
# add that flag if the signed app is rejected for missing DER entitlements.
codesign --force --sign "$IDENTITY" \
  --entitlements "$WORK/entitlements.plist" \
  --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

case "$OUTPUT" in
  /*) OUTPUT_ABS="$OUTPUT" ;;
  *)  OUTPUT_ABS="$PWD/$OUTPUT" ;;
esac
rm -f "$OUTPUT_ABS"
(cd "$WORK" && zip -qry "$OUTPUT_ABS" Payload)

echo "==> Wrote signed IPA: $OUTPUT_ABS"
echo "    Next: ./scripts/install-ipa.sh \"$OUTPUT_ABS\""
