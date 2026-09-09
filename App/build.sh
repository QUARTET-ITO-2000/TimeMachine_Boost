#!/bin/sh
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ $# -ge 1 ]; then
    OUTPUT_ROOT=$1
else
    OUTPUT_ROOT=$SCRIPT_DIR
fi
APP="$OUTPUT_ROOT/TimeMachineBoost.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/en.lproj"
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj"
mkdir -p "$APP/Contents/Resources/es.lproj"

clang -fobjc-arc -O2 \
    -mmacosx-version-min=13.0 \
    -framework Cocoa \
    -o "$APP/Contents/MacOS/TimeMachineBoost" \
    "$SCRIPT_DIR/main.m"
cp "$SCRIPT_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/en.lproj/Localizable.strings" "$APP/Contents/Resources/en.lproj/Localizable.strings"
cp "$SCRIPT_DIR/Resources/zh-Hans.lproj/Localizable.strings" "$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"
cp "$SCRIPT_DIR/Resources/es.lproj/Localizable.strings" "$APP/Contents/Resources/es.lproj/Localizable.strings"

plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built: $APP"
