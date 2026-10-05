#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
CORE_SHA=7a542dab1e87679921962a9f056186eca425c0c2
mkdir -p build/core build/game
curl -fL --retry 3 "https://codeload.github.com/libretro/libretro-fceumm/tar.gz/$CORE_SHA" -o build/core.tar.gz
tar -xzf build/core.tar.gz --strip-components=1 -C build/core
# A standalone frontend must provide libretro-common in its static archive.
python3 - <<'PY'
p='build/core/Makefile.common'
s=open(p).read().replace('ifneq ($(STATIC_LINKING), 1)','ifneq ($(V61D_EXTERNAL_COMMON), 1)')
open(p,'w').write(s)
PY
curl -fL --retry 3 https://mario.v61d.chatgpt.site/mario.nes -o build/game/mario.nes
echo 'f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de  build/game/mario.nes' | shasum -a 256 -c -
INCLUDES="$PWD/build/core/src/drivers/libretro/libretro-common/include"
make -C build/core -f Makefile.libretro -j4 platform=unix STATIC_LINKING=1 TARGET=host.a HAVE_HDPACK=0 HAVE_NTSC=0
clang -O2 -I "$INCLUDES" core-smoke.c build/core/host.a -lm -o build/core-smoke
./build/core-smoke build/game/mario.nes
make -C build/core -f Makefile.libretro platform=unix STATIC_LINKING=1 TARGET=host.a HAVE_HDPACK=0 HAVE_NTSC=0 clean
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
make -C build/core -f Makefile.libretro -j4 platform=unix STATIC_LINKING=1 TARGET=fceumm-ios.a HAVE_HDPACK=0 HAVE_NTSC=0 CC="xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -isysroot $SDK_PATH -DIOS" AR="xcrun ar"
APP_PATH="$PWD/build/Payload/V61D Mario.app"
mkdir -p "$APP_PATH"
xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -isysroot "$SDK_PATH" \
  -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter -I "$INCLUDES" \
  -framework UIKit -framework QuartzCore -framework GameController -framework AudioToolbox -framework AVFoundation \
  -Wl,-no_adhoc_codesign NativeMain.m NativeEngine.m build/core/fceumm-ios.a -lm -o "$APP_PATH/V61DMario"
cp Info.plist "$APP_PATH/Info.plist"
cp build/game/mario.nes "$APP_PATH/mario.nes"
cp build/core/Copying "$APP_PATH/COPYING"
xcrun ibtool --compile "$APP_PATH/LaunchScreen.storyboardc" LaunchScreen.storyboard \
  --minimum-deployment-target 15.0 --target-device iphone --target-device ipad
for entry in '120 AppIcon60x60@2x.png' '180 AppIcon60x60@3x.png' '76 AppIcon76x76.png' '152 AppIcon76x76@2x.png' '167 AppIcon83.5x83.5@2x.png'; do
  read -r size name <<< "$entry"
  sips -z "$size" "$size" AppIcon.png --out "$APP_PATH/$name" >/dev/null
done
plutil -lint "$APP_PATH/Info.plist"
file "$APP_PATH/V61DMario"
# Corresponding GPL source: exact patched core plus frontend; game ROM is separate.
mkdir -p build/V61D-Mario-Native-source/frontend
cp NativeMain.m NativeEngine.m NativeEngine.h core-smoke.c build.sh Info.plist README.md LaunchScreen.storyboard AppIcon.png build/V61D-Mario-Native-source/frontend/
cp -R build/core build/V61D-Mario-Native-source/core
find build/V61D-Mario-Native-source/core -type f \( -name '*.o' -o -name '*.a' \) -delete
cd build
ditto -c -k --keepParent Payload V61D-Mario-Native-unsigned.ipa
ditto -c -k --keepParent V61D-Mario-Native-source V61D-Mario-Native-source.zip
unzip -t V61D-Mario-Native-unsigned.ipa
