#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDown Pro Plus Ultra"
DERIVED_DATA="$ROOT/build/RunDerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
RUN_APP_DIR="$ROOT/build/RunApp"
APP_BUNDLE="$RUN_APP_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild \
  -workspace "$ROOT/MacDown.xcworkspace" \
  -scheme MacDown \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  MACOSX_DEPLOYMENT_TARGET=26.0 \
  CODE_SIGNING_ALLOWED=NO \
  build

# Run a disposable copy with its own bundle identity and no update feed. This
# prevents Sparkle from replacing an in-progress development build.
trash "$APP_BUNDLE" 2>/dev/null || true
mkdir -p "$RUN_APP_DIR"
ditto "$BUILT_APP" "$APP_BUNDLE"
/usr/libexec/PlistBuddy -c \
  'Set :CFBundleIdentifier com.hankyone.macdown-pro-plus-ultra-debug' \
  "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' \
  "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Delete :SUBetaFeedURL' \
  "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.hankyone.macdown-pro-plus-ultra"'
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
