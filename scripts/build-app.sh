#!/bin/sh
# 자동화 권한이 터미널이 아니라 NotchPlayer에 붙도록 .app으로 묶는다
set -e

cd "$(dirname "$0")/.."

# 측정용 빌드: scripts/build-app.sh -Xswiftc -DBENCH
swift build -c release "$@"

# 배포용 빌드는 scripts/release.sh가 APP과 SIGN_ID를 바꿔서 부른다
APP=${APP:-/Applications/NotchPlayer.app}
SIGN_ID=${SIGN_ID:-Apple Development}

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NotchPlayer "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"

# 서명이 빌드마다 바뀌면 macOS가 다른 앱으로 보고 권한을 다시 묻는다
codesign --force --sign "$SIGN_ID" "$APP"

echo "$APP"
