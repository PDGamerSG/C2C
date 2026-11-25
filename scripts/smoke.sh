#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
swift build --product C2CSmoke
BIN_DIR=$(swift build --show-bin-path)
"$BIN_DIR/C2CSmoke"
test -s Resources/COPYING
test -s Resources/NOTICE
grep -q 'sabrogden/Ditto' README.md
echo "C2C repository smoke checks passed"
