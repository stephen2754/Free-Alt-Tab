# Building and testing

## Toolchain

Use an Apple silicon Mac running macOS 26 or later. Xcode 27.1 is the reference toolchain, and requires macOS 26.6 or later on the development Mac. The application deployment target is macOS 26.0. Xcode 26 builds are also checked by CI on macOS 26.

Install Xcode, launch it once to finish setup, then select its developer directory:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Clone the complete repository, including vendored ShortcutRecorder sources. No submodule checkout, remote Swift package resolution, npm installation or Apple developer subscription is needed for local development.

```sh
git clone https://github.com/stephen2754/Free-Alt-Tab.git
cd Free-Alt-Tab
```

## Stable local signing

Run the following once to create and trust the local `Free-Alt-Tab Local` signing identity. macOS may ask for Keychain authorization. The script reuses an existing identity; keep it across builds so system permissions remain stable.

```sh
bash scripts/codesign/setup_local.sh
bash ai/build.sh
```

Release uses the same local identity:

```sh
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release \
  -configuration Release -derivedDataPath DerivedData
```

The products are `DerivedData/Build/Products/Debug/Free-Alt-Tab.app` and `DerivedData/Build/Products/Release/Free-Alt-Tab.app`. Launch through Finder or LaunchServices:

```sh
open DerivedData/Build/Products/Debug/Free-Alt-Tab.app
```

To override signing, put `CODE_SIGN_IDENTITY = Your Identity` in the ignored `config/local.xcconfig`. Never commit signing keys. For compile-only checks, pass `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` to `xcodebuild`; such builds are not a substitute for a stable signed app when checking permissions.

## Checks

```sh
python3 scripts/check_project.py
python3 scripts/l10n/validate_localizations.py
python3 scripts/assets/compile_illustrations.py --check
python3 scripts/assets/test_compile_illustrations.py
scripts/check_import.sh
bash ai/build.sh
bash ai/test.sh
```

`ai/test.sh` runs the retained upstream XCTest suite and import checks in Debug. CI also builds Release on macOS 26 and 27, without release credentials or deployment steps. It never publishes application binaries.

`check_import.sh` compiles and runs the same import safety scenarios as the XCTest wrapper, using Command Line Tools alone. On a machine without full Xcode, `validate_localizations.py --catalogs-only` checks language catalogs and format arguments but skips the native `genstrings` source-extraction comparison. Full application builds and XCTest still require Xcode.

To regenerate artwork or localization source after editing:

```sh
swift scripts/assets/create_app_icon.swift
python3 scripts/assets/compile_illustrations.py
bash scripts/l10n/extract_l10n_strings.sh
```

Keep the existing translations when refreshing catalogs. Newly added import messages currently have English fallback text, with Simplified Chinese translations; existing upstream translations are retained.

## CLI

Use the executable inside the running application bundle:

```sh
/Applications/Free-Alt-Tab.app/Contents/MacOS/Free-Alt-Tab --list
```

The CLI options and response shapes follow upstream. The local message-port namespace uses Free-Alt-Tab's bundle identifier, so it does not send commands to the original AltTab process.
