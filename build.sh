#!/bin/zsh
# TearTime.app(인공눈물 타이머)을 애플실리콘, 인텔 겸용으로 만들고 배포용 zip까지 만든다.
# 실행: ./build.sh  (결과: build/TearTime.app, build/TearTime.zip)
set -e
cd "$(dirname "$0")"
VER=0.2
APP="build/TearTime.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/ko.lproj" "$APP/Contents/Resources/en.lproj"
for arch in arm64 x86_64; do
  swiftc -parse-as-library -O -target $arch-apple-macos15.0 main.swift -o build/TearTime-$arch
done
lipo -create build/TearTime-arm64 build/TearTime-x86_64 -output "$APP/Contents/MacOS/TearTime"
rm build/TearTime-arm64 build/TearTime-x86_64
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>TearTime</string>
  <key>CFBundleDisplayName</key><string>TearTime</string>
  <key>CFBundleIdentifier</key><string>io.github.d4ymonth.teartime</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>TearTime</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>$VER</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>LSHasLocalizedDisplayName</key><true/>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
# 앱 아이콘: assets/icon.png(1024) 하나에서 icns를 만든다
mkdir -p build/AppIcon.iconset
for sz in 16 32 128 256 512; do
  sips -z $sz $sz assets/icon.png --out build/AppIcon.iconset/icon_${sz}x${sz}.png >/dev/null
  sips -z $((sz*2)) $((sz*2)) assets/icon.png --out build/AppIcon.iconset/icon_${sz}x${sz}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns" && rm -rf build/AppIcon.iconset
echo 'CFBundleDisplayName = "인공눈물 타이머";' > "$APP/Contents/Resources/ko.lproj/InfoPlist.strings"
echo 'CFBundleDisplayName = "TearTime";' > "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
codesign -s - --force "$APP"
ditto -c -k --norsrc --noextattr --keepParent "$APP" build/TearTime.zip
echo "built $APP, build/TearTime.zip"
