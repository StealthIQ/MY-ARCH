#!/bin/bash
# Build and install the linux-leos kernel
# Run from ~/LEOS/kernel/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="$SCRIPT_DIR/kernel"

echo "=== Building linux-leos kernel ==="
echo "Base: Full Arch Linux kernel config"
echo "Overrides: LEOS compression/memory optimizations"
echo ""

cd "$KERNEL_DIR"

# If no Arch config available online, use running kernel's config
if [ -f /proc/config.gz ]; then
    echo "Extracting running kernel config as fallback base..."
    zcat /proc/config.gz > config.arch
fi

# Build
echo "Starting makepkg (this takes 30-90 minutes)..."
makepkg -sf

# Install
echo ""
echo "Installing kernel packages..."
sudo pacman -U --noconfirm linux-leos-*.pkg.tar.zst

# Update boot entry to use linux-leos
if [ -f /boot/loader/entries/leos.conf ]; then
    sudo sed -i 's|/vmlinuz-linux$|/vmlinuz-linux-leos|' /boot/loader/entries/leos.conf
    sudo sed -i 's|/initramfs-linux.img$|/initramfs-linux-leos.img|' /boot/loader/entries/leos.conf
    echo "Updated bootloader entry to use linux-leos"
fi

# Rebuild initramfs
sudo mkinitcpio -P

echo ""
echo "=== Done! Reboot to use linux-leos kernel ==="
echo "  sudo reboot"
