#!/bin/bash
# LEOS kernel build helper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="$SCRIPT_DIR/kernel"

echo "=== LEOS Kernel Build ==="
echo "Directory: $KERNEL_DIR"

cd "$KERNEL_DIR"

# Check dependencies
echo "Checking build dependencies..."
if ! pacman -Qi base-devel &>/dev/null; then
    echo "Installing base-devel..."
    sudo pacman -S --needed base-devel bc cpio gettext libelf pahole perl python tar xz
fi

# Build
echo ""
echo "Starting kernel build (this will take 30-90 minutes)..."
echo "Using $(nproc) cores"
time makepkg -sf --skipchecksums

echo ""
echo "Build complete! Install with:"
echo "  sudo pacman -U linux-LEOS-*.pkg.tar.zst"
