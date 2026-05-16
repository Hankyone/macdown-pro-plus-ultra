#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-Hankyone/macdown-pro-plus-ultra}"
ZIP_PATH="$ROOT/dist/MacDownProPlusUltra.app.zip"
APPCAST_PATH="$ROOT/dist/appcast.xml"
REPO_APPCAST_PATH="$ROOT/appcast.xml"
VERIFY_DIR="$(mktemp -d)"
APP_PATH="$VERIFY_DIR/MacDown Pro Plus Ultra.app"

cleanup() {
  trash "$VERIFY_DIR" 2>/dev/null || true
}
trap cleanup EXIT

cd "$ROOT"

if [[ ! -f "$ZIP_PATH" || ! -f "$APPCAST_PATH" ]]; then
  echo "Missing release assets. Run scripts/build_release.sh first." >&2
  exit 1
fi

ditto -x -k --noextattr --norsrc "$ZIP_PATH" "$VERIFY_DIR"
xattr -cr "$VERIFY_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Zip did not contain $APP_PATH" >&2
  exit 1
fi

codesign --verify --strict --verbose=2 "$APP_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
TAG="v$VERSION"

if ! grep -q "releases/download/$TAG/MacDownProPlusUltra.app.zip" "$APPCAST_PATH"; then
  echo "appcast.xml does not point at $TAG." >&2
  exit 1
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP_PATH" "$APPCAST_PATH" --repo "$REPO" --clobber
else
  gh release create "$TAG" "$ZIP_PATH" "$APPCAST_PATH" \
    --repo "$REPO" \
    --title "MacDown Pro Plus Ultra $VERSION" \
    --notes "Release $VERSION ($BUILD)."
fi

cp "$APPCAST_PATH" "$REPO_APPCAST_PATH"

echo "Published $TAG to $REPO"
echo "Feed: https://raw.githubusercontent.com/$REPO/master/appcast.xml"
