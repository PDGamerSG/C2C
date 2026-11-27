#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
VERSION=${C2C_VERSION:-1.0.2}

command -v swift >/dev/null 2>&1 || { echo "swift is required" >&2; exit 1; }
command -v pkg-config >/dev/null 2>&1 || { echo "pkg-config is required" >&2; exit 1; }
pkg-config --exists gtk4 || {
  echo "GTK4 development files are required. Install libgtk-4-dev and try again." >&2
  exit 1
}

case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "Unsupported Linux architecture: $(uname -m)" >&2; exit 1 ;;
esac

swift build -c release --static-swift-stdlib --product C2CLinux
BIN_DIR=$(swift build -c release --show-bin-path)
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/c2c-linux.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/c2c-linux-$VERSION/bin" \
  "$STAGE/c2c-linux-$VERSION/share/applications" \
  "$STAGE/c2c-linux-$VERSION/share/icons/hicolor/scalable/apps"
cp "$BIN_DIR/C2CLinux" "$STAGE/c2c-linux-$VERSION/bin/c2c"
cp Resources/c2c-mark.svg "$STAGE/c2c-linux-$VERSION/share/icons/hicolor/scalable/apps/c2c.svg"
cp Resources/COPYING Resources/NOTICE "$STAGE/c2c-linux-$VERSION/"
cat > "$STAGE/c2c-linux-$VERSION/share/applications/c2c.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=C2C Clipboard Manager
Comment=Local-first clipboard history
Exec=c2c
Icon=c2c
Terminal=false
Categories=Utility;
StartupWMClass=com.c2c.clipboard
DESKTOP

mkdir -p dist
TARBALL="$ROOT/dist/C2C-linux-$VERSION-$ARCH.tar.gz"
tar -C "$STAGE" -czf "$TARBALL" "c2c-linux-$VERSION"
tar -tzf "$TARBALL" | grep -q "/bin/c2c$"
tar -tzf "$TARBALL" | grep -q "/share/applications/c2c.desktop$"
printf 'Built and verified %s\n' "$TARBALL"
