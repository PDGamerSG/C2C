#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
VERSION=${C2C_VERSION:-1.0.1}
./scripts/build-app.sh
mkdir -p dist
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/c2c-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
cp -R build/C2C.app "$STAGE/C2C.app"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/dist/C2C-$VERSION.dmg"
hdiutil create -volname "C2C $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
printf 'Built and verified %s\n' "$DMG"
