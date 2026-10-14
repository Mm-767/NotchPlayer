#!/bin/sh
# scripts/icon.swift로 그린 1024px 원본을 크기별로 줄여 AppIcon.icns를 만든다
set -e

cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"

swift scripts/icon.swift "$WORK/icon-1024.png"

for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$WORK"

echo AppIcon.icns
