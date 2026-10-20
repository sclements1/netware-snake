#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'The macOS .saver plug-in must be compiled on a Mac with Apple command line tools.' >&2
  exit 1
fi
if ! xcrun --find clang >/dev/null 2>&1; then
  echo 'Install Xcode Command Line Tools: xcode-select --install' >&2
  exit 1
fi
# Do not leave an old or partial bundle that can accidentally be installed.
BUNDLE="$PWD/build/NetWareSnake.saver"
APP="$PWD/build/NetWareSnakePreview.app"
rm -rf "$BUNDLE" "$APP"
mkdir -p "$PWD/build/obj"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
FLAGS=(-O2 -mmacosx-version-min=13.0 -isysroot "$SDK" -I "$PWD/core")
xcrun clang "${FLAGS[@]}" -std=c11 -c core/nw_snake.c -o build/obj/nw_snake.o
xcrun clang "${FLAGS[@]}" -std=c11 -c core/nw_geometry.c -o build/obj/nw_geometry.o
xcrun clang "${FLAGS[@]}" -fobjc-arc -c macos/NWCPUReader.m -o build/obj/NWCPUReader.o
xcrun clang "${FLAGS[@]}" -fobjc-arc -c macos/NetWareSnakeView.m -o build/obj/NetWareSnakeView.o
mkdir -p "$BUNDLE/Contents/MacOS"
xcrun clang -bundle -mmacosx-version-min=13.0 -isysroot "$SDK" \
    build/obj/nw_snake.o build/obj/nw_geometry.o build/obj/NWCPUReader.o build/obj/NetWareSnakeView.o -o "$BUNDLE/Contents/MacOS/NetWareSnake" \
    -framework Cocoa -framework ScreenSaver -framework QuartzCore -lm
cp macos/Info.plist "$BUNDLE/Contents/Info.plist"
# Ad-hoc code signing suffices for local development; not notarized distribution.
codesign --force --sign - "$BUNDLE"
# A regular native AppKit app loading exactly the same view, for debugging
# without relying on the macOS 26 screensaver preview/lifecycle behavior.
mkdir -p "$APP/Contents/MacOS"
xcrun clang "${FLAGS[@]}" -fobjc-arc -c macos/NWPreviewMain.m -o build/obj/NWPreviewMain.o
xcrun clang -mmacosx-version-min=13.0 -isysroot "$SDK" \
    build/obj/nw_snake.o build/obj/nw_geometry.o build/obj/NWCPUReader.o build/obj/NetWareSnakeView.o build/obj/NWPreviewMain.o -o "$APP/Contents/MacOS/NetWareSnakePreview" \
    -framework Cocoa -framework ScreenSaver -framework QuartzCore -lm
cp macos/Info.preview.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
# Fail the build unless both bundles contain their expected binaries and metadata.
[[ -s "$BUNDLE/Contents/MacOS/NetWareSnake" ]]
[[ -s "$APP/Contents/MacOS/NetWareSnakePreview" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUNDLE/Contents/Info.plist")" == "0.3.0" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUNDLE/Contents/Info.plist")" == "12" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "0.3.0" ]]
echo
printf 'Built: %s\n' "$BUNDLE"
printf 'To install safely after quitting System Settings: ./install-macos.sh\n'
printf 'Preview app: open "%s"\n' "$APP"
