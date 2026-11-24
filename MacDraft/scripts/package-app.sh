#!/bin/bash
# Offline, ad-hoc-signed preview. App Store archives use the Xcode project.
set -euo pipefail
mac_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="/private/tmp/tomorrow-mac-preview-build"
app_path="${1:-$(mktemp -d /private/tmp/tomorrow-preview.XXXXXX)/to.morrow.app}"
if [[ -e "$app_path" ]]; then
  echo "Refusing to overwrite an existing app: $app_path" >&2
  exit 1
fi
swift build --package-path "$mac_root" --scratch-path "$build_root"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$build_root/debug/TomorrowMac" "$app_path/Contents/MacOS/TomorrowMac"
cp "$mac_root/Assets/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp "$mac_root/Assets/W95FA.otf" "$app_path/Contents/Resources/W95FA.otf"
cp "$mac_root/Assets/W95FA-LICENSE.txt" "$app_path/Contents/Resources/W95FA-LICENSE.txt"
cp "$mac_root/Config/Info.plist" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable TomorrowMac' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.lucasmaher.shove95' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 26.0' "$app_path/Contents/Info.plist"
xattr -cr "$app_path"
codesign --force --sign - "$app_path"
codesign --verify "$app_path"
echo "$app_path"
