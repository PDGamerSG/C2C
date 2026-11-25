#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

swift build --product C2CLinux
BIN_DIR=$(swift build --show-bin-path)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/c2c-linux-smoke.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
XDG_DATA_HOME="$TMP_ROOT/data" XDG_CONFIG_HOME="$TMP_ROOT/config" C2C_LINUX_SELF_TEST=1 "$BIN_DIR/C2CLinux"

if command -v xvfb-run >/dev/null 2>&1 && pkg-config --exists gtk4; then
  status=0
  timeout 5s xvfb-run -a env XDG_DATA_HOME="$TMP_ROOT/data" XDG_CONFIG_HOME="$TMP_ROOT/config" "$BIN_DIR/C2CLinux" >/dev/null 2>&1 || status=$?
  if [ "$status" -ne 124 ]; then
    echo "GTK headless launch failed with status $status" >&2
    exit 1
  fi
else
  echo "GTK headless launch skipped: xvfb-run or GTK4 is unavailable"
fi
echo "C2C Linux smoke checks passed"
