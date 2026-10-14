#!/bin/sh
# 자동화 권한이 터미널이 아니라 NotchPlayer에 붙도록 .app으로 묶는다
set -e

cd "$(dirname "$0")/.."

swift build -c release

APP=.build/NotchPlayer.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NotchPlayer "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

# 서명이 빌드마다 바뀌면 macOS가 다른 앱으로 보고 권한을 다시 묻는다
codesign --force --sign "Apple Development" "$APP"

echo "$APP"
