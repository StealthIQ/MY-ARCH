#!/bin/bash
# LEOS per-directory compression policies
# Run after initial system setup
set -euo pipefail

echo "=== Applying LEOS Compression Policies ==="

# High compression for documents, code, configs (rarely written, often read)
for dir in /home/*/Documents /home/*/Projects /home/*/.config /var/log; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression zstd:9
        echo "  zstd:9 → $dir"
    fi
done

# Default compression for general home directories
for dir in /home/*; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression zstd:3
        echo "  zstd:3 → $dir"
    fi
done

# No compression for AI model files (already quantized/compressed)
for dir in /opt/models /home/*/models /home/*/.ollama; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression no
        echo "  none   → $dir"
    fi
done

# No compression for media (incompressible)
for dir in /home/*/Videos /home/*/Music /home/*/Pictures; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression no
        echo "  none   → $dir"
    fi
done

echo ""
echo "Done. New files in these directories will use the assigned compression."
echo "Existing files unchanged — run 'btrfs filesystem defrag -czstd:3 <path>' to recompress."
