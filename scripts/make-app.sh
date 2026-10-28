#!/bin/zsh
# Build "AK820 Pro.app" from the SwiftPM targets (no Xcode project needed).
# Usage: scripts/make-app.sh [--install]   (--install copies the app to ~/Applications)
set -euo pipefail
cd "${0:A:h}/.."

VERSION="1.1.0"
# ".noindex": Spotlight skips this folder, so only the installed copy shows up in searches.
APP="build.noindex/AK820 Pro.app"

# Record the real SDK version in the binary. Without this the link recorded "sdk 13.0", so macOS
# ran the app in compatibility mode with the old look instead of Liquid Glass.
SDKV="$(xcrun --show-sdk-version)"
LINK=(-Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker "$SDKV")
swift build -c release --product AK820App "${LINK[@]}"
swift build -c release --product ak820 "${LINK[@]}"
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/AK820App" "$APP/Contents/MacOS/AK820 Pro"
cp "$BIN/ak820" "$APP/Contents/Resources/ak820"          # the CLI, bundled for convenience
# The factory GIF is AJAZZ's and isn't in the public repo; bundle it only if you put a copy in assets/.
[[ -f assets/factory-boot.gif ]] && cp assets/factory-boot.gif "$APP/Contents/Resources/"
[[ -f assets/AppIcon.icns ]] || scripts/icon-from-image.sh
cp assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AK820 Pro</string>
    <key>CFBundleDisplayName</key><string>AK820 Pro</string>
    <key>CFBundleIdentifier</key><string>local.lex.ak820</string>
    <key>CFBundleExecutable</key><string>AK820 Pro</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS runs it locally (not notarized; for this Mac only).
codesign --force --sign - "$APP/Contents/Resources/ak820"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/"AK820 Pro.app"
    cp -R "$APP" ~/Applications/
    echo "Installed to ~/Applications/AK820 Pro.app"
fi
