#!/bin/bash
# LEOS Full System Setup
# Run on a fresh Arch Linux install with btrfs root
# Usage: sudo ./install.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
USERNAME="leos"

echo "╔══════════════════════════════════════════╗"
echo "║         LEOS System Installer            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# === 1. System packages ===
echo "[1/8] Installing packages..."
pacman -Syu --noconfirm --needed \
    base-devel git nano sudo networkmanager openssh \
    hyprland hyprlock hypridle waybar kitty mpv wofi \
    sddm ttf-font-awesome noto-fonts \
    pipewire wireplumber xdg-desktop-portal-hyprland polkit-gnome \
    btrfs-progs \
    wayland-protocols meson ninja pkg-config \
    nvidia nvidia-utils nvidia-settings \
    linux-headers dkms \
    iwd wireless-regdb wpa_supplicant \
    linux-firmware networkmanager-openvpn \
    python python-pip nodejs npm deno rustup \
    firefox thunar curl wget unzip \
    zed \
    ripgrep fd bat eza fzf zoxide starship lazygit btop dust tldr \
    just direnv tmux podman podman-compose \
    swaync grim slurp wl-clipboard brightnessctl pavucontrol \
    imv ttf-jetbrains-mono-nerd \
    cliphist wlogout swayosd-git nwg-look fastfetch syncthing bitwarden \
    ccache mold sccache watchexec xh sqlite redis turbo \
    ufw fail2ban timeshift \
    telegram-desktop \
    spotify-launcher \
    duperemove compsize libwebp \
    auto-cpufreq ananicy-cpp preload earlyoom profile-sync-daemon \
    pacman-contrib

# === 2. Build mpvpaper ===
echo ""
echo "[2/8] Building mpvpaper (video wallpaper)..."
if ! command -v mpvpaper &>/dev/null; then
    cd /tmp && rm -rf mpvpaper
    git clone https://github.com/GhostNaN/mpvpaper.git
    cd mpvpaper && meson build && ninja -C build && ninja -C build install
    cd /
fi

# === 2b. Install uv and pnpm ===
echo ""
echo "[2b/8] Installing uv and pnpm..."
curl -LsSf https://astral.sh/uv/install.sh | sh
npm install -g pnpm
rustup default stable
cargo install cargo-binstall

# Kiro CLI (AI coding assistant)
curl -fsSL https://kiro.dev/install.sh | sh

# Antigravity CLI (Google's agentic coding tool)
curl -fsSL https://antigravity.codes/install.sh | sh
mkdir -p /home/$USERNAME/.cargo
cat > /home/$USERNAME/.cargo/config.toml << 'EOF'
[alias]
install = ["binstall"]
EOF
chown -R $USERNAME:$USERNAME /home/$USERNAME/.cargo

# === 3. Create user ===
echo ""
echo "[3/8] Setting up user account..."
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USERNAME" | chpasswd
fi
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

# === 3b. Shell config (aliases + tools) ===
UHOME="/home/$USERNAME"
cat > "$UHOME/.bashrc" << 'EOF'
# LEOS Shell Config
fastfetch --logo small
eval "$(starship init bash)"
eval "$(zoxide init bash)"
eval "$(direnv hook bash)"

# Aliases
alias ls='eza --icons'
alias ll='eza -la --icons'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias cd='z'
alias top='btop'
alias du='dust'
alias lg='lazygit'
alias docker='podman'
alias docker-compose='podman-compose'
alias curl='xh'

# FZF
source /usr/share/fzf/key-bindings.bash
source /usr/share/fzf/completion.bash

# Path
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# Build speed: use ccache and mold linker
export CC="ccache gcc"
export CXX="ccache g++"
export RUSTC_WRAPPER="sccache"
export CARGO_TARGET_DIR="/tmp/cargo-build"
EOF
chown "$USERNAME:$USERNAME" "$UHOME/.bashrc"

# Mold as default linker for Rust
mkdir -p "$UHOME/.cargo"
cat >> "$UHOME/.cargo/config.toml" << 'EOF'
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF
chown -R "$USERNAME:$USERNAME" "$UHOME/.cargo"

# === 4. Memory compression (zswap + sysctl) ===
echo ""
echo "[4/8] Configuring memory compression..."
cp "$SCRIPT_DIR/system/sysctl-memory.conf" /etc/sysctl.d/99-leos-memory.conf
sysctl --system 2>/dev/null

# Create swap if not exists
if ! swapon --show | grep -q swapfile; then
    if [ ! -d /swap ]; then
        btrfs subvolume create /swap 2>/dev/null || mkdir -p /swap
    fi
    if [ ! -f /swap/swapfile ]; then
        btrfs filesystem mkswapfile --size 8G /swap/swapfile 2>/dev/null || \
            (dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 && chmod 600 /swap/swapfile && mkswap /swap/swapfile)
    fi
    swapon /swap/swapfile 2>/dev/null || true
    grep -q "swapfile" /etc/fstab || echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# === 5. Bootloader zswap params ===
echo ""
echo "[5/8] Configuring zswap boot parameters..."
ZSWAP_PARAMS="zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=50 zswap.shrinker_enabled=1"
if [ -f /boot/loader/entries/leos.conf ]; then
    grep -q "zswap.enabled" /boot/loader/entries/leos.conf || \
        sed -i "s|^options.*|& $ZSWAP_PARAMS|" /boot/loader/entries/leos.conf
elif [ -f /etc/default/grub ]; then
    grep -q "zswap.enabled" /etc/default/grub || \
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$ZSWAP_PARAMS |" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# === 6. Desktop configs ===
echo ""
echo "[6/8] Installing desktop configuration..."
UHOME="/home/$USERNAME"
mkdir -p "$UHOME/.config/hypr" "$UHOME/.config/waybar" "$UHOME/Videos"
cp "$SCRIPT_DIR/desktop/hyprland.conf" "$UHOME/.config/hypr/hyprland.conf"
cp "$SCRIPT_DIR/desktop/hyprlock.conf" "$UHOME/.config/hypr/hyprlock.conf"
cp "$SCRIPT_DIR/desktop/waybar-config" "$UHOME/.config/waybar/config"

# WhatsApp PWA
mkdir -p "$UHOME/.local/share/applications"
cat > "$UHOME/.local/share/applications/whatsapp.desktop" << 'EOF'
[Desktop Entry]
Name=WhatsApp
Exec=firefox --new-window https://web.whatsapp.com
Icon=firefox
Type=Application
Categories=Network;Chat;
EOF

chown -R "$USERNAME:$USERNAME" "$UHOME"

# === 7. Install leos-mem tool ===
echo ""
echo "[7/8] Installing leos-mem monitoring tool..."
cp "$SCRIPT_DIR/scripts/leos-mem" /usr/local/bin/leos-mem
cp "$SCRIPT_DIR/scripts/leos-info" /usr/local/bin/leos-info
cp "$SCRIPT_DIR/scripts/leos-screenshot" /usr/local/bin/leos-screenshot
chmod +x /usr/local/bin/leos-mem /usr/local/bin/leos-info /usr/local/bin/leos-screenshot

# === 8. Enable services ===
echo ""
echo "[8/8] Enabling services..."
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable sshd 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true
systemctl enable ufw 2>/dev/null || true
systemctl enable fail2ban 2>/dev/null || true
systemctl enable auto-cpufreq 2>/dev/null || true
systemctl enable ananicy-cpp 2>/dev/null || true
systemctl enable preload 2>/dev/null || true
systemctl enable earlyoom 2>/dev/null || true
systemctl enable redis 2>/dev/null || true
systemctl --user -M "$USERNAME@" enable psd 2>/dev/null || true
systemctl --user -M "$USERNAME@" enable syncthing 2>/dev/null || true
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow ssh 2>/dev/null || true
ufw enable 2>/dev/null || true

# === Storage efficiency ===
# Auto-clean package cache weekly (keep last 2 versions)
cat > /etc/systemd/system/paccache.service << 'EOF'
[Unit]
Description=Clean pacman cache
[Service]
Type=oneshot
ExecStart=/usr/bin/paccache -rk2
EOF
cat > /etc/systemd/system/paccache.timer << 'EOF'
[Unit]
Description=Clean pacman cache weekly
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl enable paccache.timer

# Cap journal logs at 100MB
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf << 'EOF'
[Journal]
SystemMaxUse=100M
EOF

# /tmp on tmpfs (lives in RAM, auto-cleared on reboot)
grep -q "tmpfs /tmp" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,size=2G 0 0" >> /etc/fstab

# === Security hardening ===
# DNS over HTTPS via systemd-resolved
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns-over-tls.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
DNSOverTLS=yes
EOF
systemctl enable systemd-resolved 2>/dev/null || true

# earlyoom config (kill at 5% free RAM instead of 0%)
mkdir -p /etc/default
echo 'EARLYOOM_ARGS="-m 5 -s 5 --prefer ollama --avoid sshd"' > /etc/default/earlyoom

# === Done ===
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         LEOS Install Complete!           ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Login:     leos / leos                  ║"
echo "║  Desktop:   Hyprland (Super+Enter=term)  ║"
echo "║  Wallpaper: ~/Videos/wallpaper.mp4       ║"
echo "║  Lock:      Super+L                      ║"
echo "║  Monitor:   leos-mem                     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Reboot now: sudo reboot"
