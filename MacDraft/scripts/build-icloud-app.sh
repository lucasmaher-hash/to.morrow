#!/bin/bash
# Signed app connected to the same production database as the App Store iPhone app.
set -euo pipefail
draft_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="/private/tmp/tomorrow-mac-icloud"
app_path="${1:-$HOME/Applications/to.morrow.app}"
python3 "$draft_root/scripts/generate-xcode-project.py"
xcodebuild -project "$draft_root/TomorrowMac.xcodeproj" -scheme TomorrowMac \
  -configuration Release -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$build_root" -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration build
mkdir -p "$(dirname "$app_path")"
ditto "$build_root/Build/Products/Release/TomorrowMac.app" "$app_path"
codesign --verify --deep --strict "$app_path"
echo "$app_path"
