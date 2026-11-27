#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

if [ "$#" -eq 0 ]; then
  swift build --product C2CLinux
  set -- "$(swift build --show-bin-path)/C2CLinux"
fi
BINARY=$1
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/c2c-linux-smoke.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
export XDG_DATA_HOME="$TMP_ROOT/data" XDG_CONFIG_HOME="$TMP_ROOT/config"
C2C_LINUX_SELF_TEST=1 "$BINARY"

xvfb-run -a env -u WAYLAND_DISPLAY GDK_BACKEND=x11 sh -eu -c '
  "$1" > "$2/app.log" 2>&1 &
  app=$!
  trap "kill $app 2>/dev/null || true; wait $app 2>/dev/null || true" EXIT
  python3 - "$XDG_DATA_HOME/c2c/clipboard.json" <<PY
import base64
import json
import pathlib
import subprocess
import sys
import time

snapshot = pathlib.Path(sys.argv[1])
samples = [
    ("text", "UTF8_STRING", "C2C clipboard smoke — text".encode()),
    ("image", "image/png", pathlib.Path("Resources/C2C-icon.png").read_bytes()),
]
for kind, target, expected in samples:
    subprocess.run(
        ["xclip", "-selection", "clipboard", "-i", "-t", target],
        input=expected, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        check=True, timeout=5,
    )
    for attempt in range(100):
        try:
            clips = json.loads(snapshot.read_bytes())["clips"]
            if any(p["kind"] == kind and base64.b64decode(p["data"]) == expected
                   for clip in clips for p in clip["payloads"]):
                break
        except FileNotFoundError:
            pass
        time.sleep(0.1)
    else:
        sys.exit(f"GTK clipboard capture did not persist {kind}")
PY
  kill -0 "$app"
' c2c-smoke "$BINARY" "$TMP_ROOT" || {
  if [ -f "$TMP_ROOT/app.log" ]; then cat "$TMP_ROOT/app.log" >&2; fi
  exit 1
}
echo "C2C Linux smoke checks passed"
