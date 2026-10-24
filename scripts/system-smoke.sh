#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
APP="$ROOT/build/C2C.app"
[ -x "$APP/Contents/MacOS/C2C" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "com.c2c.clipboard" ]
codesign --verify --deep --strict "$APP"
open -n "$APP"
sleep 2
if ! pgrep -f "$APP/Contents/MacOS/C2C" >/dev/null; then
  echo "C2C did not remain running after launch" >&2
  exit 1
fi
printf 'System smoke passed: C2C is running from %s\n' "$APP"
