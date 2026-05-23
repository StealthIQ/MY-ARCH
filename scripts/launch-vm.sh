#!/bin/bash
# LEOS QEMU Development VM
# Downloads Arch ISO and launches VM for development
set -euo pipefail

VM_DIR="$(cd "$(dirname "$0")/.." && pwd)/vm"
DISK="$VM_DIR/LEOS.qcow2"
DISK_SIZE="60G"
RAM="4G"
CPUS="4"
ARCH_ISO="$VM_DIR/archlinux.iso"

mkdir -p "$VM_DIR"

# Download latest Arch ISO if not present
if [ ! -f "$ARCH_ISO" ]; then
    echo "Downloading Arch Linux ISO..."
    MIRROR="https://geo.mirror.pkgbuild.com/iso/latest"
    ISO_NAME=$(curl -sL "$MIRROR/" | grep -oP 'archlinux-\d{4}\.\d{2}\.\d{2}-x86_64\.iso' | head -1)
    curl -L -o "$ARCH_ISO" "$MIRROR/$ISO_NAME"
    echo "Downloaded: $ISO_NAME"
fi

# Create disk image if not present
if [ ! -f "$DISK" ]; then
    echo "Creating ${DISK_SIZE} disk image..."
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Launching LEOS Dev VM          ║"
echo "╠══════════════════════════════════════════╣"
echo "║  RAM: $RAM  CPUs: $CPUS  Disk: $DISK_SIZE        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Install tips:"
echo "  1. Boot the ISO, then:"
echo "     mkfs.btrfs -f /dev/vda2"
echo "     mount -o compress=zstd:3 /dev/vda2 /mnt"
echo "  2. Follow normal Arch install (pacstrap, genfstab, etc.)"
echo "  3. After install, remove -cdrom flag and reboot into disk"
echo ""

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -m "$RAM" \
    -smp "$CPUS" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -cdrom "$ARCH_ISO" \
    -boot d \
    -nic user,model=virtio-net-pci \
    -display gtk \
    -vga virtio
