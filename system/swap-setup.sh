#!/bin/bash
# LEOS swap setup — creates NVMe swap partition for zswap backend
set -euo pipefail

SWAP_SIZE="${1:-16G}"
SWAP_FILE="/swapfile"

echo "=== LEOS Swap Setup ==="

# Check if swap already exists
if swapon --show | grep -q "$SWAP_FILE"; then
    echo "Swap already active at $SWAP_FILE"
    exit 0
fi

# Create swap file on btrfs (requires nocow)
if [ ! -f "$SWAP_FILE" ]; then
    echo "Creating ${SWAP_SIZE} swap file..."
    btrfs filesystem mkswapfile --size "$SWAP_SIZE" "$SWAP_FILE"
fi

# Enable swap
chmod 600 "$SWAP_FILE"
mkswap "$SWAP_FILE"
swapon "$SWAP_FILE"

echo "Swap enabled:"
swapon --show

# Verify zswap is active
echo ""
echo "=== zswap status ==="
echo "enabled: $(cat /sys/module/zswap/parameters/enabled)"
echo "compressor: $(cat /sys/module/zswap/parameters/compressor)"
echo "zpool: $(cat /sys/module/zswap/parameters/zpool)"
echo "max_pool_percent: $(cat /sys/module/zswap/parameters/max_pool_percent)"
