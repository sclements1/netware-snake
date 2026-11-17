#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'This diagnostics script runs on macOS.' >&2
  exit 1
fi
REPORT="${1:-$PWD/NetWareSnake-diagnostics-$(date +%Y%m%d-%H%M%S).txt}"
{
  echo 'NetWare Snake diagnostics'
  echo "Collected: $(date)"
  echo "macOS: $(sw_vers -productVersion)"
  BUNDLE="$HOME/Library/Screen Savers/NetWareSnake.saver/Contents/Info.plist"
  if [[ -f "$BUNDLE" ]]; then
    printf 'Installed saver version: '
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUNDLE" || true
    printf 'Installed saver build: '
    /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUNDLE" || true
  else
    echo 'Installed saver: not found'
  fi
  echo
  echo 'Recent NetWare Snake unified-log events (last 15 minutes):'
  /usr/bin/log show --last 15m --style compact --info \
    --predicate 'subsystem == "org.netwaresnake.mac.saver"' || true
} > "$REPORT"
echo "Saved: $REPORT"
echo 'Review the report before sharing it.'
