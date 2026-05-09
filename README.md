# MacDown Pro Plus Ultra

MacDown Pro Plus Ultra is a lightly cursed personal fork of [MacDown](https://github.com/MacDownApp/macdown): the same Markdown editor core, with a crowned icon, Apple Silicon-friendly builds, local signing, a separate bundle identifier, and its own Sparkle update feed.

The app installs alongside upstream MacDown instead of replacing it:

- App name: `MacDown Pro Plus Ultra`
- Bundle ID: `com.hankyone.macdown-pro-plus-ultra`
- Shell helper: `macdown-pppu`
- Update feed: GitHub Releases appcast for this fork

## Development

Requirements:

- Xcode with the macOS SDK
- Git
- CocoaPods
- Homebrew is recommended for the shell helper install path detection

Setup:

```sh
git submodule update --init --recursive
pod install
make -C Dependency/peg-markdown-highlight
```

Build:

```sh
xcodebuild \
  -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  MACOSX_DEPLOYMENT_TARGET=10.13 \
  CODE_SIGNING_ALLOWED=NO
```

## Release Build

The release script builds the app, signs the helper/framework/app bundle, creates a ZIP, and writes a Sparkle `appcast.xml` for GitHub Releases.

```sh
SPARKLE_PRIVATE_KEY=.secrets/sparkle_dsa_priv.pem scripts/build_release.sh
```

The script writes:

- `dist/MacDownProPlusUltra.app.zip`
- `dist/appcast.xml`

Upload both files to a GitHub release named for the app version, for example `v0.1`.

The Sparkle public key is committed at `MacDown/Resources/dsa_pub.pem`. The private key is intentionally ignored and should stay outside Git.

## Upstream

This fork is based on MacDown, originally released under the MIT License. The original README, license, and third-party component licenses are preserved in the repository history and `LICENSE` directory.
