#!/bin/bash
# LEOS Post-Install System Setup
# Integrates: system tuning + mydots cyberpunk desktop
# Usage: sudo ./install.sh
set +e

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
USERNAME="leos"

echo "╔══════════════════════════════════════════╗"
echo "║     LEOS System Setup + Cyberpunk Rice   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# === 1. System packages ===
echo "[1/10] Installing packages..."
rm -f /var/lib/pacman/db.lck

# Enable multilib
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/s/#\[multilib\]/[multilib]/' /etc/pacman.conf
    sed -i '/^\[multilib\]$/,/^#Include/s/^#Include/Include/' /etc/pacman.conf
fi

pacman -Syu --noconfirm --needed --overwrite '*' \
    base-devel git nano sudo networkmanager openssh \
    hyprland hyprpaper hyprlock hypridle waybar kitty mpv wofi \
    sddm ttf-font-awesome noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd \
    pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber \
    xdg-desktop-portal-hyprland polkit-kde-agent \
    qt5-wayland qt6-wayland qt6-declarative qt6-multimedia-ffmpeg \
    btrfs-progs wayland-protocols meson ninja pkg-config \
    linux-headers dkms linux-firmware \
    iwd wireless-regdb wpa_supplicant \
    networkmanager-openvpn \
    python python-pip python-virtualenv python-aiohttp \
    nodejs npm deno rustup \
    firefox thunar gvfs gvfs-mtp file-roller curl wget unzip jq \
    ripgrep fd bat eza fzf zoxide starship lazygit btop dust tldr \
    just direnv tmux podman podman-compose \
    mako grim slurp wl-clipboard brightnessctl pavucontrol playerctl \
    imv cliphist nwg-look fastfetch \
    ccache mold sccache \
    ufw fail2ban timeshift \
    duperemove compsize \
    ananicy-cpp earlyoom \
    pacman-contrib \
    bluez bluez-utils blueman \
    mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader

# === 2. GPU Detection ===
echo ""
echo "[2/10] Detecting GPU..."

HAS_NVIDIA=false; HAS_AMD=false; HAS_INTEL=false; IS_VM=false

if lspci -nn | grep -i 'vga\|3d\|display' | grep -qi vmware; then
    IS_VM=true
    echo "  VMware detected — software rendering"
elif lspci -nn | grep -i 'vga\|3d\|display' | grep -qi virtualbox; then
    IS_VM=true
    echo "  VirtualBox detected — software rendering"
fi

if lspci -nn | grep -i 'vga\|3d\|display' | grep -qi nvidia; then
    HAS_NVIDIA=true
    echo "  NVIDIA GPU detected — installing proprietary drivers"
    pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings
fi

if lspci -nn | grep -i 'vga\|3d\|display' | grep -qi intel; then
    HAS_INTEL=true
    echo "  Intel GPU detected"
    pacman -S --noconfirm --needed vulkan-intel
fi

if lspci -nn | grep -i 'vga\|3d\|display' | grep -qiE 'amd|advanced'; then
    HAS_AMD=true
    echo "  AMD GPU detected"
    pacman -S --noconfirm --needed vulkan-radeon
fi

# === 3. User account ===
echo ""
echo "[3/10] Setting up user..."
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USERNAME" | chpasswd
fi
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/leos
chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/leos

# === 4. LEOS system configs ===
echo ""
echo "[4/10] Deploying system configs..."

cp "$SCRIPT_DIR/system/mkinitcpio.conf" /etc/mkinitcpio.conf
mkinitcpio -P

cp "$SCRIPT_DIR/system/sysctl-memory.conf" /etc/sysctl.d/99-leos-memory.conf
sysctl --system 2>/dev/null

# Bootloader entry
if [ -d /boot/loader/entries ]; then
    ROOT_UUID=$(findmnt -no UUID /)
    sed "s/ROOT_UUID/$ROOT_UUID/" "$SCRIPT_DIR/system/leos.conf" > /boot/loader/entries/leos.conf
fi

# === 5. Swap ===
echo ""
echo "[5/10] Configuring swap..."
if ! swapon --show | grep -q swap; then
    if findmnt -no FSTYPE / | grep -q btrfs; then
        [ -f /swap/swapfile ] || {
            mkdir -p /swap
            btrfs filesystem mkswapfile --size 8G /swap/swapfile 2>/dev/null || \
                (dd if=/dev/zero of=/swap/swapfile bs=1M count=8192 && chmod 600 /swap/swapfile && mkswap /swap/swapfile)
        }
        swapon /swap/swapfile 2>/dev/null
        grep -q "swapfile" /etc/fstab || echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    fi
fi

# === 6. Desktop configs ===
echo ""
echo "[6/10] Desktop config (Cyberpunk Rose Pine)..."
UHOME="/home/$USERNAME"
mkdir -p "$UHOME/.config/hypr/scripts" "$UHOME/.config/hypr/wallpapers/live-wallpapers" \
         "$UHOME/.config/waybar" "$UHOME/.config/kitty" "$UHOME/.config/mako" \
         "$UHOME/Pictures" "$UHOME/Videos"

# Hyprland configs
cp "$SCRIPT_DIR/desktop/hyprland.conf" "$UHOME/.config/hypr/hyprland.conf"
cp "$SCRIPT_DIR/desktop/hyprlock.conf" "$UHOME/.config/hypr/hyprlock.conf"
cp "$SCRIPT_DIR/desktop/hyprlock-video.conf" "$UHOME/.config/hypr/hyprlock-video.conf"
cp "$SCRIPT_DIR/desktop/hypridle.conf" "$UHOME/.config/hypr/hypridle.conf"
cp "$SCRIPT_DIR/desktop/environment.conf" "$UHOME/.config/hypr/environment.conf"

# Waybar
cp "$SCRIPT_DIR/desktop/waybar/config" "$UHOME/.config/waybar/config"
cp "$SCRIPT_DIR/desktop/waybar/style.css" "$UHOME/.config/waybar/style.css"

# Kitty + Mako
cp "$SCRIPT_DIR/desktop/kitty.conf" "$UHOME/.config/kitty/kitty.conf"
cp "$SCRIPT_DIR/desktop/mako/config" "$UHOME/.config/mako/config"

# Scripts
cp "$SCRIPT_DIR/desktop/scripts/"*.sh "$UHOME/.config/hypr/scripts/" 2>/dev/null
cp "$SCRIPT_DIR/desktop/scripts/"*.py "$UHOME/.config/hypr/scripts/" 2>/dev/null
chmod +x "$UHOME/.config/hypr/scripts/"*.sh 2>/dev/null

# VM-specific: disable blur/shadows for performance
if [ "$IS_VM" = true ]; then
    sed -i 's/enabled = true/enabled = false/' "$UHOME/.config/hypr/hyprland.conf"
    cat >> "$UHOME/.config/hypr/environment.conf" << 'EOF'
env = WLR_RENDERER_ALLOW_SOFTWARE,1
env = WLR_NO_HARDWARE_CURSORS,1
env = LIBGL_ALWAYS_SOFTWARE,1
EOF
fi

# NVIDIA env vars
if [ "$HAS_NVIDIA" = true ]; then
    cat >> "$UHOME/.config/hypr/environment.conf" << 'EOF'
env = WLR_NO_HARDWARE_CURSORS,1
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
fi

# === 7. SDDM Theming ===
echo ""
echo "[7/10] SDDM setup..."

systemctl enable sddm.service 2>/dev/null

# Create hyprland.desktop session
mkdir -p /usr/share/wayland-sessions
if [ -f "/usr/bin/start-hyprland" ]; then
    HYPR_EXEC="/usr/bin/start-hyprland"
else
    HYPR_EXEC="/usr/bin/Hyprland"
fi

cat > /usr/share/wayland-sessions/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor
Exec=$HYPR_EXEC
Type=Application
DesktopNames=Hyprland
EOF

# SDDM config
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/99-hyprland.conf << 'EOF'
[General]
DisplayServer=x11
GreeterEnvironment=QT_QPA_PLATFORM=xcb
DefaultSession=hyprland.desktop

[Theme]
Current=sddm-astronaut-theme
EOF

# NetworkManager wifi backend
mkdir -p /etc/NetworkManager/NetworkManager.conf.d
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/NetworkManager.conf.d/wifi-backend.conf

# === 8. Dev tools + AUR ===
echo ""
echo "[8/10] Dev tools..."

sudo -u "$USERNAME" rustup default stable 2>/dev/null || true
curl -LsSf https://astral.sh/uv/install.sh | sudo -u "$USERNAME" sh 2>/dev/null || true
npm install -g pnpm 2>/dev/null || true

# Yay
if ! command -v yay &>/dev/null; then
    cd /tmp && rm -rf yay
    git clone https://aur.archlinux.org/yay-bin.git yay
    chown -R "$USERNAME:$USERNAME" yay
    sudo -u "$USERNAME" bash -c 'cd /tmp/yay && makepkg --noconfirm'
    pacman -U --noconfirm /tmp/yay/*.pkg.tar.zst
fi

# AUR packages (SDDM theme, mpvpaper)
for pkg in sddm-astronaut-theme mpvpaper-git; do
    if ! pacman -Qi "${pkg%-git}" &>/dev/null && ! pacman -Qi "$pkg" &>/dev/null; then
        cd /tmp && rm -rf "$pkg"
        git clone "https://aur.archlinux.org/$pkg.git" 2>/dev/null || continue
        chown -R "$USERNAME:$USERNAME" "$pkg"
        sudo -u "$USERNAME" bash -c "cd /tmp/$pkg && makepkg --noconfirm --skippgpcheck" || continue
        pacman -U --noconfirm /tmp/$pkg/*.pkg.tar.zst 2>/dev/null || true
    fi
done

# === 9. Shell + LEOS tools ===
echo ""
echo "[9/10] Shell config + LEOS tools..."

cat > "$UHOME/.bashrc" << 'EOF'
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

source /usr/share/fzf/key-bindings.bash 2>/dev/null
source /usr/share/fzf/completion.bash 2>/dev/null
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
EOF

chown -R "$USERNAME:$USERNAME" "$UHOME"

# LEOS tools
cp "$SCRIPT_DIR/scripts/leos-mem" /usr/local/bin/leos-mem 2>/dev/null
cp "$SCRIPT_DIR/scripts/leos-info" /usr/local/bin/leos-info 2>/dev/null
cp "$SCRIPT_DIR/scripts/leos-screenshot" /usr/local/bin/leos-screenshot 2>/dev/null
chmod +x /usr/local/bin/leos-* 2>/dev/null

# === 10. Services + hardening ===
echo ""
echo "[10/10] Services..."

systemctl enable NetworkManager sshd sddm ananicy-cpp earlyoom 2>/dev/null
systemctl enable ufw fail2ban bluetooth 2>/dev/null
systemctl enable systemd-resolved 2>/dev/null

# Firewall
ufw default deny incoming 2>/dev/null
ufw default allow outgoing 2>/dev/null
ufw allow ssh 2>/dev/null
ufw --force enable 2>/dev/null

# Journal cap
mkdir -p /etc/systemd/journald.conf.d
echo -e "[Journal]\nSystemMaxUse=100M" > /etc/systemd/journald.conf.d/size.conf

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

# Hypr-bot (system error monitor)
if [ -f "$SCRIPT_DIR/desktop/hypr-bot/install-bot.sh" ]; then
    echo "  Installing hypr-bot system service..."
    chmod +x "$SCRIPT_DIR/desktop/hypr-bot/install-bot.sh"
    "$SCRIPT_DIR/desktop/hypr-bot/install-bot.sh" 2>/dev/null || true
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         LEOS Setup Complete!             ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Login:     leos / leos                  ║"
echo "║  Desktop:   Hyprland (Super+Enter=term)  ║"
echo "║  Theme:     Cyberpunk Rose Pine          ║"
echo "║  Wallpaper: Super+F10 (live video)       ║"
echo "║  Lock:      Super+L / Super+Shift+L      ║"
echo "║  Next:      Build linux-leos kernel      ║"
echo "╚══════════════════════════════════════════╝"
