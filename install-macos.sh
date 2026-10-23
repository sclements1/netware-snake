#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SOURCE="$PWD/build/NetWareSnake.saver"
TARGET_DIR="$HOME/Library/Screen Savers"
TARGET="$TARGET_DIR/NetWareSnake.saver"
STAGING="$TARGET_DIR/.NetWareSnake-v040-install-$$.saver"
BACKUP="$TARGET_DIR/NetWareSnake.previous.saver"
if [[ ! -s "$SOURCE/Contents/MacOS/NetWareSnake" || ! -f "$SOURCE/Contents/Info.plist" ]]; then
  echo 'ERROR: Built screensaver missing. Run ./build-macos.sh successfully first. No changes made.' >&2
  exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE/Contents/Info.plist")
if [[ "$VERSION" != '0.4.0' || "$BUILD" != '13' ]]; then
  echo "ERROR: Expected v0.4.0 (13), got $VERSION ($BUILD). No changes made." >&2
  exit 1
fi
if pgrep -x 'System Settings' >/dev/null; then
  echo 'Please quit System Settings (Command-Q), then rerun this script. No changes made.' >&2
  exit 1
fi
mkdir -p "$TARGET_DIR"
trap 'rm -rf "$STAGING"' EXIT
ditto "$SOURCE" "$STAGING"
[[ -s "$STAGING/Contents/MacOS/NetWareSnake" ]] || { echo 'Staging failed; existing saver unchanged.' >&2; exit 1; }
# Back up the previously installed bundle only after copying the new one.
rm -rf "$BACKUP"
if [[ -e "$TARGET" ]]; then mv "$TARGET" "$BACKUP"; fi
if ! mv "$STAGING" "$TARGET"; then
  [[ ! -e "$TARGET" && -e "$BACKUP" ]] && mv "$BACKUP" "$TARGET"
  echo 'Install failed; attempted to restore previous saver.' >&2
  exit 1
fi
trap - EXIT
printf 'Installed version: '
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TARGET/Contents/Info.plist"
echo "Previous version backed up (if present): $BACKUP"
