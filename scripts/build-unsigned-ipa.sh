#!/usr/bin/env bash
# Build dekpop as an unsigned IPA. Run on macOS with Xcode installed.
# Usage: ./scripts/build-unsigned-ipa.sh [output.ipa]
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: this script requires macOS + Xcode (codesign/xcodebuild are Apple-only)." >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Install Xcode, then run: xcode-select --install" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT="${1:-dekpop-unsigned.ipa}"
case "$OUTPUT" in
  /*) OUTPUT_ABS="$OUTPUT" ;;
  *)  OUTPUT_ABS="$ROOT/$OUTPUT" ;;
esac

SYMROOT="$ROOT/build"
echo "==> Building dekpop (target 3105, Release, unsigned)..."
xcodebuild -project "ThreeOneOSFive.xcodeproj" \
  -target 3105 \
  -sdk iphoneos \
  -configuration Release \
  SYMROOT="$SYMROOT" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build

APP="$SYMROOT/Release-iphoneos/dekpop.app"
if [ ! -d "$APP" ]; then
  echo "error: expected $APP (PRODUCT_NAME is dekpop, not 3105/ThreeOneOSFive)." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
rm -f "$OUTPUT_ABS"
(cd "$STAGE" && zip -qry "$OUTPUT_ABS" Payload)

echo "==> Wrote unsigned IPA: $OUTPUT_ABS"
echo "    Verify:  unzip -l \"$OUTPUT_ABS\" | head"
echo "    Next:    ./scripts/resign-ipa.sh \"$OUTPUT_ABS\" \"iPhone Distribution: ...\" profile.mobileprovision"
