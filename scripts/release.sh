#!/bin/sh
# GitHub Releases에 올릴 zip을 만든다. 공증하지 않으므로 받는 쪽에서 처음 열 때 Gatekeeper가 막는다(README 설치 참고)
set -e

cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
STAGE=.build/release-app

rm -rf "$STAGE"
mkdir -p "$STAGE" dist

# 내 개발용 인증서 대신 ad-hoc 서명. 다른 맥에서는 어느 쪽이든 막히는 건 같다
APP="$STAGE/NotchPlayer.app" SIGN_ID=- scripts/build-app.sh

ZIP="dist/NotchPlayer-v$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGE/NotchPlayer.app" "$ZIP"

# dmg를 열면 앱을 응용 프로그램 폴더로 끌어다 놓을 수 있게 바로가기를 같이 넣는다
DMG="dist/NotchPlayer-v$VERSION.dmg"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname NotchPlayer -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "$ZIP"
echo "$DMG"
