#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
APP_PATH="$PWD/build/Payload/V61D Mario.app"
mkdir -p "$APP_PATH"
xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -isysroot "$SDK_PATH" \
  -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter \
  -framework UIKit -framework WebKit -Wl,-no_adhoc_codesign \
  main.m -o "$APP_PATH/V61DMario"
cp Info.plist "$APP_PATH/Info.plist"
xcrun ibtool --compile "$APP_PATH/LaunchScreen.storyboardc" LaunchScreen.storyboard \
  --minimum-deployment-target 15.0 --target-device iphone --target-device ipad
for entry in '120 AppIcon60x60@2x.png' '180 AppIcon60x60@3x.png' '76 AppIcon76x76.png' '152 AppIcon76x76@2x.png' '167 AppIcon83.5x83.5@2x.png'; do
  read -r size name <<< "$entry"
  sips -z "$size" "$size" AppIcon.png --out "$APP_PATH/$name" >/dev/null
done
plutil -lint "$APP_PATH/Info.plist"
file "$APP_PATH/V61DMario"
cd build
ditto -c -k --keepParent Payload V61D-Mario-unsigned.ipa
unzip -t V61D-Mario-unsigned.ipa
