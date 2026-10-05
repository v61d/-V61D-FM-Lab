#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIM_ARCH=$(uname -m)
INCLUDES="$PWD/build/core/src/drivers/libretro/libretro-common/include"
make -C build/core -f Makefile.libretro platform=unix STATIC_LINKING=1 TARGET=fceumm-ios.a HAVE_HDPACK=0 HAVE_NTSC=1 clean
make -C build/core -f Makefile.libretro -j4 platform=unix STATIC_LINKING=1 TARGET=fceumm-simulator.a HAVE_HDPACK=0 HAVE_NTSC=1 CC="xcrun --sdk iphonesimulator clang -target $SIM_ARCH-apple-ios15.0-simulator -isysroot $SDK_PATH -DIOS" AR="xcrun ar"
APP_PATH="$PWD/build/Simulator/V61D Mario.app"
mkdir -p "$APP_PATH"
xcrun --sdk iphonesimulator clang -target "$SIM_ARCH-apple-ios15.0-simulator" -isysroot "$SDK_PATH" \
 -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter -I "$INCLUDES" \
 -framework UIKit -framework QuartzCore -framework GameController -framework AudioToolbox -framework AVFoundation -framework ReplayKit -framework UniformTypeIdentifiers \
 NativeMain.m NativeEngine.m MenuController.m SaveStore.m build/core/fceumm-simulator.a -lm -o "$APP_PATH/V61DMario"
cp Info.plist "$APP_PATH/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleSupportedPlatforms:0 iPhoneSimulator' "$APP_PATH/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :UIRequiredDeviceCapabilities' "$APP_PATH/Info.plist"
cp build/game/mario.nes v61d-logo.png "$APP_PATH/"
xcrun ibtool --compile "$APP_PATH/LaunchScreen.storyboardc" LaunchScreen.storyboard --minimum-deployment-target 15.0 --target-device iphone --target-device ipad
codesign --force --sign - "$APP_PATH"
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys;d=json.load(sys.stdin);print(next(x["udid"] for rows in d["devices"].values() for x in rows if x.get("isAvailable") and "iPhone" in x["name"]))')
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" com.v61d.mario --ui-smoke
sleep 12
DATA_PATH=$(xcrun simctl get_app_container "$DEVICE_ID" com.v61d.mario data)
cp "$DATA_PATH/Library/Caches/QA-pass.json" build/QA-pass.json
cat build/QA-pass.json
xcrun simctl io "$DEVICE_ID" screenshot build/QA-settings.png
xcrun simctl terminate "$DEVICE_ID" com.v61d.mario
xcrun simctl launch "$DEVICE_ID" com.v61d.mario --ui-smoke --ui-core
sleep 10
xcrun simctl io "$DEVICE_ID" screenshot build/QA-core.png
xcrun simctl terminate "$DEVICE_ID" com.v61d.mario
xcrun simctl launch "$DEVICE_ID" com.v61d.mario --ui-smoke --ui-game
sleep 10
xcrun simctl io "$DEVICE_ID" screenshot build/QA-game.png
xcrun simctl shutdown "$DEVICE_ID"
