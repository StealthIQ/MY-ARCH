#!/bin/bash
# LEOS Full System Setup
# Works on fresh OR existing Arch installs
# Usage: sudo ./install.sh
set +e  # Don't exit on errors - handle them gracefully

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
rm -f /var/lib/pacman/db.lck

pacman -Syu --noconfirm --needed --overwrite '*' \
    base-devel git nano sudo networkmanager openssh \
    hyprland hyprlock hypridle waybar kitty mpv wofi \
    sddm ttf-font-awesome noto-fonts \
    pipewire wireplumber xdg-desktop-portal-hyprland polkit-gnome \
    btrfs-progs wayland-protocols meson ninja pkg-config \
    linux-headers dkms \
    iwd wireless-regdb wpa_supplicant \
    linux-firmware networkmanager-openvpn \
    python python-pip nodejs npm deno rustup \
    firefox thunar curl wget unzip \
    ripgrep fd bat eza fzf zoxide starship lazygit btop dust tldr \
    just direnv tmux podman podman-compose \
    swaync grim slurp wl-clipboard brightnessctl pavucontrol \
    imv ttf-jetbrains-mono-nerd \
    cliphist nwg-look fastfetch syncthing bitwarden \
    ccache mold sccache watchexec xh sqlite redis \
    ufw fail2ban timeshift \
    telegram-desktop spotify-launcher \
    duperemove compsize libwebp \
    ananicy-cpp earlyoom profile-sync-daemon \
    pacman-contrib gobject-introspection scdoc

# Nvidia - only on real hardware
lspci 2>/dev/null | grep -qi nvidia && pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings

# === 1b. Yay (AUR helper) ===
if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    cd /tmp && rm -rf yay
    git clone https://aur.archlinux.org/yay-bin.git yay
    chown -R "$USERNAME:$USERNAME" yay
    sudo -u "$USERNAME" bash -c 'cd /tmp/yay && makepkg --noconfirm'
    pacman -U --noconfirm /tmp/yay/*.pkg.tar.zst
fi

# === 1c. AUR packages ===
echo "Installing AUR packages..."
# Build each AUR package: clone, build as user, install as root
for pkg in wlogout auto-cpufreq preload mpvpaper-git; do
    if ! pacman -Qi "${pkg%-git}" &>/dev/null && ! pacman -Qi "$pkg" &>/dev/null; then
        echo "  Building $pkg..."
        cd /tmp && rm -rf "$pkg"
        git clone "https://aur.archlinux.org/$pkg.git" 2>/dev/null || continue
        chown -R "$USERNAME:$USERNAME" "$pkg"
        sudo -u "$USERNAME" bash -c "cd /tmp/$pkg && makepkg --noconfirm --skippgpcheck" || continue
        pacman -U --noconfirm /tmp/$pkg/*.pkg.tar.zst 2>/dev/null || true
    fi
done

# === 2. Dev tools ===
echo ""
echo "[2/8] Installing dev tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || true
npm install -g pnpm 2>/dev/null || true
sudo -u "$USERNAME" rustup default stable 2>/dev/null || true
sudo -u "$USERNAME" cargo install cargo-binstall 2>/dev/null || true
curl -fsSL https://kiro.dev/install.sh | sh 2>/dev/null || true
curl -fsSL https://antigravity.codes/install.sh | sh 2>/dev/null || true

# === 3. User account ===
echo ""
echo "[3/8] Setting up user..."
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USERNAME" | chpasswd
fi
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/leos
chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/leos

# === 3b. Shell config ===
UHOME="/home/$USERNAME"
mkdir -p "$UHOME/.cargo"
cat > "$UHOME/.bashrc" << 'EOF'
# LEOS Shell Config
fastfetch --logo small 2>/dev/null
eval "$(starship init bash)" 2>/dev/null
eval "$(zoxide init bash)" 2>/dev/null
eval "$(direnv hook bash)" 2>/dev/null

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

source /usr/share/fzf/key-bindings.bash 2>/dev/null
source /usr/share/fzf/completion.bash 2>/dev/null

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export CC="ccache gcc"
export CXX="ccache g++"
export RUSTC_WRAPPER="sccache"
export CARGO_TARGET_DIR="/tmp/cargo-build"
EOF

cat > "$UHOME/.cargo/config.toml" << 'EOF'
[alias]
install = ["binstall"]

[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF
chown -R "$USERNAME:$USERNAME" "$UHOME"

# === 4. Memory compression ===
echo ""
echo "[4/8] Configuring memory compression..."
cp "$SCRIPT_DIR/system/sysctl-memory.conf" /etc/sysctl.d/99-leos-memory.conf
sysctl --system 2>/dev/null

if ! swapon --show | grep -q swapfile; then
    btrfs subvolume create /swap 2>/dev/null || mkdir -p /swap
    if [ ! -f /swap/swapfile ]; then
        btrfs filesystem mkswapfile --size 8G /swap/swapfile 2>/dev/null || \
            (dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 && chmod 600 /swap/swapfile && mkswap /swap/swapfile)
    fi
    swapon /swap/swapfile 2>/dev/null
    grep -q "swapfile" /etc/fstab || echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# === 5. Bootloader ===
echo ""
echo "[5/8] Configuring zswap..."
ZSWAP="zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=50 zswap.shrinker_enabled=1"
if [ -f /boot/loader/entries/leos.conf ]; then
    grep -q "zswap.enabled" /boot/loader/entries/leos.conf || sed -i "s|^options.*|& $ZSWAP|" /boot/loader/entries/leos.conf
elif [ -f /etc/default/grub ]; then
    grep -q "zswap.enabled" /etc/default/grub || sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$ZSWAP |" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null
fi

# === 6. Desktop ===
echo ""
echo "[6/8] Desktop config..."
mkdir -p "$UHOME/.config/hypr" "$UHOME/.config/waybar" "$UHOME/Videos" "$UHOME/.local/share/applications"
cp "$SCRIPT_DIR/desktop/hyprland.conf" "$UHOME/.config/hypr/hyprland.conf"
cp "$SCRIPT_DIR/desktop/hyprlock.conf" "$UHOME/.config/hypr/hyprlock.conf"
cp "$SCRIPT_DIR/desktop/waybar-config" "$UHOME/.config/waybar/config"
cat > "$UHOME/.local/share/applications/whatsapp.desktop" << 'EOF'
[Desktop Entry]
Name=WhatsApp
Exec=firefox --new-window https://web.whatsapp.com
Icon=firefox
Type=Application
Categories=Network;Chat;
EOF
chown -R "$USERNAME:$USERNAME" "$UHOME"

# === 7. LEOS tools ===
echo ""
echo "[7/8] Installing LEOS tools..."
cp "$SCRIPT_DIR/scripts/leos-mem" /usr/local/bin/leos-mem
cp "$SCRIPT_DIR/scripts/leos-info" /usr/local/bin/leos-info
cp "$SCRIPT_DIR/scripts/leos-screenshot" /usr/local/bin/leos-screenshot
chmod +x /usr/local/bin/leos-mem /usr/local/bin/leos-info /usr/local/bin/leos-screenshot

# === 8. Services + hardening ===
echo ""
echo "[8/8] Enabling services..."
systemctl enable NetworkManager sshd sddm ufw fail2ban ananicy-cpp earlyoom redis systemd-resolved 2>/dev/null
systemctl enable auto-cpufreq preload 2>/dev/null
systemctl enable paccache.timer 2>/dev/null

# Firewall
ufw default deny incoming 2>/dev/null
ufw default allow outgoing 2>/dev/null
ufw allow ssh 2>/dev/null
ufw --force enable 2>/dev/null

# Paccache timer
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
systemctl enable paccache.timer 2>/dev/null

# Journal cap
mkdir -p /etc/systemd/journald.conf.d
echo -e "[Journal]\nSystemMaxUse=100M" > /etc/systemd/journald.conf.d/size.conf

# tmpfs /tmp
grep -q "tmpfs /tmp" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,size=2G 0 0" >> /etc/fstab

# DNS over TLS
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns-over-tls.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
DNSOverTLS=yes
EOF

# earlyoom
mkdir -p /etc/default
echo 'EARLYOOM_ARGS="-m 5 -s 5 --prefer ollama --avoid sshd"' > /etc/default/earlyoom

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         LEOS Install Complete!           ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Login:     leos / leos                  ║"
echo "║  Desktop:   Hyprland (Super+Enter=term)  ║"
echo "║  Wallpaper: ~/Videos/wallpaper.mp4       ║"
echo "║  Lock:      Super+L                      ║"
echo "║  Monitor:   leos-mem / leos-info         ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Reboot now: sudo reboot"
