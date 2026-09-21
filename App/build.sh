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

# Debug builds are opt-in so the default output stays identical to previous releases.
if [ "${TMB_BUILD_MODE:-release}" = "debug" ]; then
    SWIFT_OPTIMIZATION="-Onone -g"
else
    SWIFT_OPTIMIZATION="-O"
fi

# Keep the module cache out of the source tree and independent of the user's global cache.
MODULE_CACHE="${TMB_MODULE_CACHE:-${TMPDIR:-/tmp}/TimeMachineBoost-module-cache}"
mkdir -p "$MODULE_CACHE"

# -print0/-0 keeps the pipeline correct even though the checkout path contains spaces.
find "$SCRIPT_DIR/Sources" -name '*.swift' -print0 \
    | sort -z \
    | xargs -0 xcrun swiftc \
        -swift-version 5 \
        -target "$(uname -m)-apple-macos13.0" \
        -module-cache-path "$MODULE_CACHE" \
        $SWIFT_OPTIMIZATION \
        -o "$APP/Contents/MacOS/TimeMachineBoost"
cp "$SCRIPT_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/en.lproj/Localizable.strings" "$APP/Contents/Resources/en.lproj/Localizable.strings"
cp "$SCRIPT_DIR/Resources/zh-Hans.lproj/Localizable.strings" "$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"
cp "$SCRIPT_DIR/Resources/es.lproj/Localizable.strings" "$APP/Contents/Resources/es.lproj/Localizable.strings"
cp "$SCRIPT_DIR/Resources/TimeMachineBoost.icns" "$APP/Contents/Resources/TimeMachineBoost.icns"

plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built: $APP"
