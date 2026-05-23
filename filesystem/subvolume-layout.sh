#!/bin/bash
# LEOS btrfs subvolume layout
# Run during installation on the btrfs partition
set -euo pipefail

BTRFS_DEV="${1:?Usage: $0 /dev/nvmeXnYpZ}"
MNT="/mnt"

echo "=== Creating LEOS Btrfs Subvolume Layout ==="
echo "Device: $BTRFS_DEV"

mount "$BTRFS_DEV" "$MNT"

# Create subvolumes
btrfs subvolume create "$MNT/@"          # Root
btrfs subvolume create "$MNT/@home"      # Home directories
btrfs subvolume create "$MNT/@models"    # AI models (no compression)
btrfs subvolume create "$MNT/@swap"      # Swap subvolume (nocow)
btrfs subvolume create "$MNT/@snapshots" # Snapshot storage

# Disable COW on swap subvolume
chattr +C "$MNT/@swap"

umount "$MNT"

echo ""
echo "Subvolumes created. Mount with:"
echo "  mount -o compress=zstd:3,subvol=@ $BTRFS_DEV /mnt"
echo "  mount -o compress=zstd:3,subvol=@home $BTRFS_DEV /mnt/home"
echo "  mount -o compress=zstd:1,subvol=@models $BTRFS_DEV /mnt/opt/models"
echo "  mount -o nodatacow,subvol=@swap $BTRFS_DEV /mnt/swap"
