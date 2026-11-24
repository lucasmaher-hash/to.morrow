#!/bin/bash
# Builds the local native Mac draft, including the icon derived from iOS AppIcon.
set -euo pipefail
draft_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="/private/tmp/tomorrow-mac-draft-build"
app_path="${1:-/private/tmp/to.morrow Mac Draft.app}"
swift build --package-path "$draft_root" --scratch-path "$build_root"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$build_root/debug/TomorrowMac" "$app_path/Contents/MacOS/TomorrowMac.updated"
mv "$app_path/Contents/MacOS/TomorrowMac.updated" "$app_path/Contents/MacOS/TomorrowMac"
cp "$draft_root/Assets/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp "$draft_root/Assets/W95FA.otf" "$app_path/Contents/Resources/W95FA.otf"
cp "$draft_root/Assets/W95FA-LICENSE.txt" "$app_path/Contents/Resources/W95FA-LICENSE.txt"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TomorrowMac</string>
<key>CFBundleIdentifier</key><string>com.lucasmaher.tomorrow.macdraft</string>
<key>CFBundleName</key><string>to.morrow Mac Draft</string>
<key>CFBundleDisplayName</key><string>to.morrow Mac Draft</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$app_path"
codesign --force --sign - "$app_path"
codesign --verify "$app_path"
touch "$app_path"
echo "$app_path"
