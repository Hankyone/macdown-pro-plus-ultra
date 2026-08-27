#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDown Pro Plus Ultra.app"
ZIP_NAME="MacDownProPlusUltra.app.zip"
REPO="${GITHUB_REPOSITORY:-Hankyone/macdown-pro-plus-ultra}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$ROOT/.secrets/sparkle_dsa_priv.pem}"
SPARKLE_DSA_SIGN_UPDATE="${SPARKLE_DSA_SIGN_UPDATE:-$ROOT/Pods/Sparkle/bin/old_dsa_scripts/sign_update}"
DERIVED_DATA="$ROOT/build/DerivedData"
PRODUCTS="$DERIVED_DATA/Build/Products/Release"
DIST="$ROOT/dist"
TMPDIR="$(mktemp -d)"
XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-macdown-notary}"
RELEASE_VERSION="${RELEASE_VERSION:-}"
RELEASE_BUILD="${RELEASE_BUILD:-}"

cleanup() {
  trash "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT

if [[ ! -f "$SPARKLE_PRIVATE_KEY" ]]; then
  echo "Missing Sparkle private key: $SPARKLE_PRIVATE_KEY" >&2
  echo "Set SPARKLE_PRIVATE_KEY=/path/to/sparkle_dsa_priv.pem." >&2
  exit 1
fi

if [[ ! -x "$SPARKLE_DSA_SIGN_UPDATE" ]]; then
  echo "Missing Sparkle DSA signing tool: $SPARKLE_DSA_SIGN_UPDATE" >&2
  echo "Set SPARKLE_DSA_SIGN_UPDATE=/path/to/old_dsa_scripts/sign_update." >&2
  exit 1
fi

cd "$ROOT"

if [[ -z "$RELEASE_VERSION" || -z "$RELEASE_BUILD" ]]; then
  release_values=()
  while IFS= read -r value; do
    release_values+=("$value")
  done < <(python3 - "$ROOT/appcast.xml" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
enclosure = root.find("./channel/item/enclosure")
if enclosure is None:
    raise SystemExit("Existing appcast has no release enclosure")

version = enclosure.attrib["{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString"]
build = enclosure.attrib["{http://www.andymatuschak.org/xml-namespaces/sparkle}version"]
match = re.fullmatch(r"(.+d)(\d+)", version)
if match is None or not build.isdigit():
    raise SystemExit("Set RELEASE_VERSION and RELEASE_BUILD explicitly")

print(f"{match.group(1)}{int(match.group(2)) + 1}")
print(int(build) + 1)
PY
  )
  RELEASE_VERSION="${RELEASE_VERSION:-${release_values[0]:-}}"
  RELEASE_BUILD="${RELEASE_BUILD:-${release_values[1]:-}}"
fi

if [[ -z "$RELEASE_VERSION" || -z "$RELEASE_BUILD" ]]; then
  echo "Could not determine the next release version and build." >&2
  exit 1
fi

git submodule update --init --recursive
make -C Dependency/peg-markdown-highlight
trash "$ROOT/Dependency/version/version.h" 2>/dev/null || true
pod install

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild \
  -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  MACOSX_DEPLOYMENT_TARGET=26.0 \
  ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO

APP_SRC="$PRODUCTS/$APP_NAME"
APP_TMP="$TMPDIR/$APP_NAME"
FINDER_EXTENSION="$APP_TMP/Contents/PlugIns/MacDownFinderExtension.appex"
SPARKLE_FRAMEWORK="$APP_TMP/Contents/Frameworks/Sparkle.framework"
SPARKLE_AUTOUPDATE="$SPARKLE_FRAMEWORK/Versions/A/Resources/Autoupdate.app"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build did not produce $APP_SRC" >&2
  exit 1
fi

COPYFILE_DISABLE=1 /usr/bin/tar -cf - -C "$PRODUCTS" "$APP_NAME" \
  | COPYFILE_DISABLE=1 /usr/bin/tar -xf - -C "$TMPDIR"

mkdir -p "$FINDER_EXTENSION/Contents/MacOS"
cp "$ROOT/MacDownFinderExtension/Info.plist" "$FINDER_EXTENSION/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $RELEASE_VERSION" "$APP_TMP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RELEASE_BUILD" "$APP_TMP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $RELEASE_VERSION" "$FINDER_EXTENSION/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RELEASE_BUILD" "$FINDER_EXTENSION/Contents/Info.plist"
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun swiftc \
  -emit-executable \
  -parse-as-library \
  -module-name MacDownFinderExtension \
  -framework Cocoa \
  -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain \
  "$ROOT/MacDownFinderExtension/FinderSync.swift" \
  -o "$FINDER_EXTENSION/Contents/MacOS/MacDownFinderExtension"

xattr -cr "$APP_TMP"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  --entitlements "$ROOT/MacDownFinderExtension/MacDownFinderExtension.entitlements" \
  "$FINDER_EXTENSION"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  "$APP_TMP/Contents/SharedSupport/bin/macdown-pppu"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  "$SPARKLE_AUTOUPDATE/Contents/MacOS/fileop"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  "$SPARKLE_AUTOUPDATE"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  "$SPARKLE_FRAMEWORK"
codesign --force --sign "Developer ID Application: Anouar Mansour (K32684A887)" --timestamp --options=runtime \
  "$APP_TMP"
codesign --verify --strict --verbose=2 "$APP_TMP"

NOTARIZATION_ZIP="$TMPDIR/notarization.zip"
NOTARIZATION_RESULT="$TMPDIR/notarization-result.json"
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr "$APP_TMP" "$NOTARIZATION_ZIP"
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun notarytool submit "$NOTARIZATION_ZIP" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait \
  --output-format json > "$NOTARIZATION_RESULT"
python3 - "$NOTARIZATION_RESULT" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    result = json.load(f)

if result.get("status") != "Accepted":
    raise SystemExit(
        f"Notarization {result.get('id', 'submission')} finished with status "
        f"{result.get('status', 'unknown')}"
    )
PY
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun stapler staple "$APP_TMP"
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcrun stapler validate "$APP_TMP"
spctl --assess --type execute --verbose=2 "$APP_TMP"

mkdir -p "$DIST"
ZIP_PATH="$DIST/$ZIP_NAME"
APPCAST_PATH="$DIST/appcast.xml"
trash "$ZIP_PATH" "$APPCAST_PATH" 2>/dev/null || true

COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr "$APP_TMP" "$ZIP_PATH"

VERSION="$RELEASE_VERSION"
BUILD="$RELEASE_BUILD"
SIZE="$(stat -f%z "$ZIP_PATH")"
SIGNATURE="$("$SPARKLE_DSA_SIGN_UPDATE" "$ZIP_PATH" "$SPARKLE_PRIVATE_KEY" | tr -d '\n')"
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
