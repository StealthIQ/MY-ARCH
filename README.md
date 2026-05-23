# LEOS — AI-Optimized Arch Linux with Aggressive Memory & Storage Compression

A custom Arch Linux distribution optimized for running AI workloads on memory-constrained hardware through aggressive, multi-tier compression.

## Goals

| Resource | Physical | Effective Target | Method |
|----------|----------|-----------------|--------|
| RAM | 32 GB | 45+ GB | zswap (zstd) + kernel VM tuning |
| Storage | 400 GB | 700 GB | Btrfs transparent compression (zstd) |

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    User Space                             │
│  ┌────────────────┐  ┌─────────────────────────────────┐ │
│  │ AI Runtime     │  │ Desktop / Apps                   │ │
│  │ (Ollama/llama) │  │ (browser, IDE, etc.)            │ │
│  │ Q4 quantized   │  │ → compressed via zswap          │ │
│  │ raw RAM pinned │  │ → cold pages tier to SSD        │ │
│  └────────────────┘  └─────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│                Custom Kernel (linux-LEOS)           │
│                                                          │
│  Memory Subsystem (mm/)                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ zswap: compressed RAM cache in front of disk swap   │ │
│  │ • Compressor: zstd (best ratio, fast decompress)    │ │
│  │ • Pool: zsmalloc (best space efficiency)            │ │
│  │ • max_pool_percent: 50%                             │ │
│  │ • Auto-tiers cold pages to NVMe swap                │ │
│  │ • Per-cgroup writeback control for AI isolation     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  Filesystem (fs/btrfs/)                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Btrfs with transparent zstd compression             │ │
│  │ • Level 3 default (near real-time)                  │ │
│  │ • Per-directory policies (high/low/none)            │ │
│  │ • Auto-detects incompressible data (media, GGUF)   │ │
│  └─────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│                    Hardware                               │
│  CPU (compression/decompression) + RAM + NVMe SSD        │
└──────────────────────────────────────────────────────────┘
```

## Why zswap over zram (2026 consensus)

Based on kernel MM maintainer recommendations (Chris Down/Meta, Johannes Weiner):

- **zswap** integrates with kernel memory management — automatic LRU tiering
- **zram** is a dumb block device — fills with cold data, causes LRU inversion
- zswap gracefully degrades under pressure; zram hard-OOMs
- zswap is cgroup-aware; zram breaks container isolation
- Upstream kernel is moving toward zswap-only (virtual swap spaces RFC)

## Compression Algorithm Choice

| Layer | Algorithm | Why |
|-------|-----------|-----|
| RAM (zswap) | zstd | Best ratio (3-5:1), decompression speed independent of level |
| Storage (btrfs) | zstd:3 | Near real-time, good ratio, kernel-native |
| AI models | Q4_K_M quantization | Already compressed — btrfs auto-skips |
| KV cache | TurboQuant (3-bit) | 6x reduction, inference engine level |

## VM Tuning Rationale

- `vm.swappiness = 100` — balanced reclaim (anonymous vs file pages equal weight)
- `vm.page-cluster = 0` — no readahead for compressed swap (random access is fine)
- `vm.watermark_boost_factor = 0` — don't wake kswapd early
- `vm.watermark_scale_factor = 125` — fine-grained reclaim thresholds

## Project Structure

```
LEOS/
├── kernel/
│   ├── PKGBUILD              # Arch kernel build recipe
│   ├── config                # Custom kernel .config
│   └── patches/              # Custom kernel patches
├── system/
│   ├── zswap.conf            # Kernel boot params for zswap
│   ├── sysctl-memory.conf    # VM tuning parameters
│   ├── swap-setup.sh         # Create and enable swap partition
│   └── ai-cgroup.conf        # cgroup config for AI workloads
├── filesystem/
│   ├── btrfs-mount.conf      # fstab mount options
│   ├── compression-policies.sh  # Per-directory compression setup
│   └── subvolume-layout.sh   # Btrfs subvolume creation
├── scripts/
│   ├── install.sh            # Full system setup
│   ├── build-kernel.sh       # Kernel compilation helper
│   └── benchmark.sh          # Measure compression ratios
└── README.md
```

## Quick Start

1. Install Arch Linux in QEMU/VMware with btrfs root
2. Clone this repo
3. Build custom kernel: `cd kernel && makepkg -s`
4. Install: `sudo pacman -U linux-LEOS-*.pkg.tar.zst`
5. Apply configs: `sudo ./scripts/install.sh`
6. Reboot and verify: `cat /sys/module/zswap/parameters/enabled`

## Hardware Requirements

- CPU: Modern x86_64 with AES-NI (compression acceleration)
- RAM: 16-64 GB (designed for 32 GB sweet spot)
- Storage: NVMe SSD (for swap tier performance)
- GPU: Optional, for AI model offloading

## References

- [Kernel zswap docs](https://docs.kernel.org/admin-guide/mm/zswap.html)
- [Btrfs compression](https://btrfs.readthedocs.io/en/stable/Compression.html)
- [Chris Down: zswap vs zram (2026)](https://chrisdown.name/2026/03/24/zswap-vs-zram-when-to-use-what.html)
- [Arch Kernel Build System](https://wiki.archlinux.org/title/Kernels/Arch_Build_System)
- [Google TurboQuant (ICLR 2026)](https://github.com/hackimov/turboquant-kv)
