#!/bin/bash
# LEOS compression benchmark
# Measures actual compression ratios for RAM and storage
set -euo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║    LEOS Compression Benchmark      ║"
echo "╚══════════════════════════════════════════╝"

# === RAM Compression (zswap) ===
echo ""
echo "=== RAM Compression (zswap) ==="
if [ -d /sys/kernel/debug/zswap ]; then
    STORED=$(cat /sys/kernel/debug/zswap/stored_pages 2>/dev/null || echo 0)
    POOL_SIZE=$(cat /sys/kernel/debug/zswap/pool_total_size 2>/dev/null || echo 0)

    if [ "$STORED" -gt 0 ] && [ "$POOL_SIZE" -gt 0 ]; then
        ORIG_SIZE=$((STORED * 4096))
        RATIO=$(echo "scale=2; $ORIG_SIZE / $POOL_SIZE" | bc)
        echo "  Original data:   $(numfmt --to=iec $ORIG_SIZE)"
        echo "  Compressed size: $(numfmt --to=iec $POOL_SIZE)"
        echo "  Compression ratio: ${RATIO}:1"
        echo "  Effective RAM gain: $(numfmt --to=iec $((ORIG_SIZE - POOL_SIZE)))"
    else
        echo "  No data in zswap yet. Run some workloads first."
    fi

    echo ""
    echo "  zswap parameters:"
    echo "    enabled:    $(cat /sys/module/zswap/parameters/enabled)"
    echo "    compressor: $(cat /sys/module/zswap/parameters/compressor)"
    echo "    zpool:      $(cat /sys/module/zswap/parameters/zpool)"
    echo "    max_pool:   $(cat /sys/module/zswap/parameters/max_pool_percent)%"
else
    echo "  zswap debug info not available (mount debugfs or check kernel config)"
fi

# === Storage Compression (btrfs) ===
echo ""
echo "=== Storage Compression (btrfs) ==="
for mount_point in / /home; do
    if findmnt -n -o FSTYPE "$mount_point" 2>/dev/null | grep -q btrfs; then
        echo "  Mount: $mount_point"
        COMP_INFO=$(btrfs filesystem usage "$mount_point" 2>/dev/null | head -5)
        echo "$COMP_INFO" | sed 's/^/    /'

        # Get compression ratio via compsize if available
        if command -v compsize &>/dev/null; then
            echo "    Compression stats (compsize):"
            compsize "$mount_point" 2>/dev/null | head -5 | sed 's/^/      /'
        else
            echo "    Install 'compsize' for detailed compression stats"
        fi
        echo ""
    fi
done

# === System Memory Overview ===
echo "=== System Memory ==="
echo "  Physical RAM: $(free -h | awk '/Mem:/{print $2}')"
echo "  Used:         $(free -h | awk '/Mem:/{print $3}')"
echo "  Available:    $(free -h | awk '/Mem:/{print $7}')"
echo "  Swap total:   $(free -h | awk '/Swap:/{print $2}')"
echo "  Swap used:    $(free -h | awk '/Swap:/{print $3}')"

# Effective RAM calculation
PHYS_RAM=$(free -b | awk '/Mem:/{print $2}')
SWAP_USED=$(free -b | awk '/Swap:/{print $3}')
if [ "$POOL_SIZE" -gt 0 ] 2>/dev/null; then
    EFFECTIVE=$((PHYS_RAM + ORIG_SIZE - POOL_SIZE))
    echo ""
    echo "  ★ Effective RAM: $(numfmt --to=iec $EFFECTIVE) (physical + zswap gain)"
fi

echo ""
echo "=== Target vs Actual ==="
echo "  RAM target:     32GB → 45GB effective"
echo "  Storage target: 400GB → 700GB effective"
echo "  (Run workloads and re-check to see actual ratios)"
