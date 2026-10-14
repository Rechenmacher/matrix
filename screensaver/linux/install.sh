#!/usr/bin/env bash
# install.sh — Install the Matrix screensaver on Linux
#
# Usage:
#   ./install.sh              # user install (~/.local/)
#   sudo ./install.sh system  # system-wide install (/usr/)
#
# Prerequisites:
#   - cmake, gcc/g++, pkg-config
#   - libwebkitgtk-6.0-dev (or libwebkit2gtk-4.1-dev on Ubuntu 22.04)
#   - libgtk-4-dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

MODE="${1:-user}"

if [ "$MODE" = "system" ]; then
    PREFIX="/usr"
    DATA_DIR="/usr/share/matrix-screensaver"
else
    PREFIX="$HOME/.local"
    DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/matrix-screensaver"
fi

echo "=== Building matrix-screensaver ==="

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" ..
make -j"$(nproc)"

echo "=== Installing binary to $PREFIX/bin/ ==="
install -Dm755 matrix-screensaver "$PREFIX/bin/matrix-screensaver"

echo "=== Installing web assets to $DATA_DIR/ ==="
mkdir -p "$DATA_DIR"

# Copy essential web files from repo root
for item in index.html js lib shaders assets; do
    src="$REPO_ROOT/$item"
    if [ -e "$src" ]; then
        cp -r "$src" "$DATA_DIR/"
    fi
done

echo "=== Installing desktop file ==="
install -Dm644 "$SCRIPT_DIR/matrix-screensaver.desktop" \
    "$PREFIX/share/applications/matrix-screensaver.desktop"

echo ""
echo "=== Install complete ==="
echo "  Binary:     $PREFIX/bin/matrix-screensaver"
echo "  Web assets: $DATA_DIR/"
echo ""
echo "To run: matrix-screensaver"
echo "To use with XScreenSaver, add to ~/.xscreensaver:"
echo '  programs: ... "Matrix WebGL" matrix-screensaver \n\'
