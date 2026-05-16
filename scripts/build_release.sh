#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDown Pro Plus Ultra.app"
ZIP_NAME="MacDownProPlusUltra.app.zip"
REPO="${GITHUB_REPOSITORY:-Hankyone/macdown-pro-plus-ultra}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$ROOT/.secrets/sparkle_dsa_priv.pem}"
DERIVED_DATA="$ROOT/build/DerivedData"
PRODUCTS="$DERIVED_DATA/Build/Products/Release"
DIST="$ROOT/dist"
TMPDIR="$(mktemp -d)"

cleanup() {
  trash "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT

if [[ ! -f "$SPARKLE_PRIVATE_KEY" ]]; then
  echo "Missing Sparkle private key: $SPARKLE_PRIVATE_KEY" >&2
  echo "Set SPARKLE_PRIVATE_KEY=/path/to/sparkle_dsa_priv.pem." >&2
  exit 1
fi

cd "$ROOT"

git submodule update --init --recursive
make -C Dependency/peg-markdown-highlight
trash "$ROOT/Dependency/version/version.h" 2>/dev/null || true
pod install

xcodebuild \
  -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  MACOSX_DEPLOYMENT_TARGET=10.13 \
  ARCHS=x86_64 \
  CODE_SIGNING_ALLOWED=NO

APP_SRC="$PRODUCTS/$APP_NAME"
APP_TMP="$TMPDIR/$APP_NAME"
FINDER_EXTENSION="$APP_TMP/Contents/PlugIns/MacDownFinderExtension.appex"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build did not produce $APP_SRC" >&2
  exit 1
fi

COPYFILE_DISABLE=1 /usr/bin/tar -cf - -C "$PRODUCTS" "$APP_NAME" \
  | COPYFILE_DISABLE=1 /usr/bin/tar -xf - -C "$TMPDIR"

mkdir -p "$FINDER_EXTENSION/Contents/MacOS"
cp "$ROOT/MacDownFinderExtension/Info.plist" "$FINDER_EXTENSION/Contents/Info.plist"
swiftc \
  -emit-executable \
  -parse-as-library \
  -module-name MacDownFinderExtension \
  -framework Cocoa \
  -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain \
  "$ROOT/MacDownFinderExtension/FinderSync.swift" \
  -o "$FINDER_EXTENSION/Contents/MacOS/MacDownFinderExtension"

xattr -cr "$APP_TMP"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp=none \
  --entitlements "$ROOT/MacDownFinderExtension/MacDownFinderExtension.entitlements" \
  "$FINDER_EXTENSION"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp=none \
  "$APP_TMP/Contents/SharedSupport/bin/macdown-pppu"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp=none \
  "$APP_TMP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp=none --options=runtime \
  "$APP_TMP"
codesign --verify --strict --verbose=2 "$APP_TMP"

mkdir -p "$DIST"
ZIP_PATH="$DIST/$ZIP_NAME"
APPCAST_PATH="$DIST/appcast.xml"
trash "$ZIP_PATH" "$APPCAST_PATH" 2>/dev/null || true

COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr "$APP_TMP" "$ZIP_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_TMP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_TMP/Contents/Info.plist")"
SIZE="$(stat -f%z "$ZIP_PATH")"
SIGNATURE="$(Pods/Sparkle/bin/sign_update "$ZIP_PATH" "$SPARKLE_PRIVATE_KEY" | tr -d '\n')"
PUBDATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/$ZIP_NAME"

python3 - "$APPCAST_PATH" "$VERSION" "$BUILD" "$SIZE" "$SIGNATURE" "$PUBDATE" "$DOWNLOAD_URL" <<'PY'
import html
import sys

path, version, build, size, signature, pubdate, url = sys.argv[1:]
with open(path, "w", encoding="utf-8") as f:
    f.write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MacDown Pro Plus Ultra Updates</title>
    <item>
      <title>Version {html.escape(version)}</title>
      <pubDate>{html.escape(pubdate)}</pubDate>
      <enclosure
        url="{html.escape(url)}"
        sparkle:version="{html.escape(build)}"
        sparkle:shortVersionString="{html.escape(version)}"
        sparkle:dsaSignature="{html.escape(signature)}"
        length="{html.escape(size)}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
""")
PY

echo "Built $ZIP_PATH"
echo "Built $APPCAST_PATH"
echo "Upload both files to GitHub release v$VERSION."
