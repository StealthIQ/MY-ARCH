#!/bin/bash
# LEOS per-directory compression policies + deduplication
set -euo pipefail

echo "=== Applying LEOS Compression Policies ==="

# Install duperemove for deduplication if not present
if ! command -v duperemove &>/dev/null; then
    pacman -S --noconfirm duperemove
fi

# High compression for code, docs, configs
for dir in /home/*/Documents /home/*/Projects /home/*/.config /var/log; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression zstd:9
        echo "  zstd:9  → $dir"
    fi
done

# Default compression for general home
for dir in /home/*; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression zstd:4
        echo "  zstd:4  → $dir"
    fi
done

# No compression for AI models
for dir in /opt/models /home/*/models /home/*/.ollama; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression no
        echo "  none    → $dir"
    fi
done

# No compression for media
for dir in /home/*/Videos /home/*/Music /home/*/Pictures /home/*/Media; do
    if [ -d "$dir" ]; then
        btrfs property set "$dir" compression no
        echo "  none    → $dir"
    fi
done

echo ""
echo "=== Running Deduplication ==="
echo "Finds identical blocks and stores them once (saves 20-40% on dev projects)"
nohup duperemove -rdh /home/ > /var/log/duperemove.log 2>&1 &
echo "  Running in background (PID: $!)"
echo ""
echo "Done."
