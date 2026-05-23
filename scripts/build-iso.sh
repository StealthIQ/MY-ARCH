#!/bin/bash
# LEOS ISO Builder
# Run on any Arch Linux system with internet access
# Usage: sudo ./build-iso.sh
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./build-iso.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="/tmp/leos-iso-work"
OUT_DIR="$SCRIPT_DIR/iso-out"
PROFILE="/tmp/leos-profile"

echo "╔══════════════════════════════════════════╗"
echo "║         LEOS ISO Builder                 ║"
echo "╚══════════════════════════════════════════╝"

# Install archiso
pacman -S --noconfirm --needed archiso

# Copy releng profile as base
rm -rf "$PROFILE"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# Add LEOS packages
cat >> "$PROFILE/packages.x86_64" << 'EOF'
hyprland
hyprlock
hypridle
waybar
kitty
mpv
wofi
sddm
ttf-font-awesome
noto-fonts
pipewire
wireplumber
xdg-desktop-portal-hyprland
polkit-gnome
btrfs-progs
linux-headers
dkms
iwd
wireless-regdb
wpa_supplicant
linux-firmware
networkmanager
networkmanager-openvpn
python
python-pip
nodejs
npm
deno
rustup
firefox
thunar
curl
wget
unzip
ripgrep
fd
bat
eza
fzf
zoxide
starship
lazygit
btop
dust
tldr
just
direnv
tmux
podman
podman-compose
swaync
grim
slurp
wl-clipboard
brightnessctl
pavucontrol
imv
ttf-jetbrains-mono-nerd
cliphist
nwg-look
fastfetch
syncthing
bitwarden
ccache
mold
sccache
watchexec
xh
sqlite
redis
ufw
fail2ban
timeshift
telegram-desktop
spotify-launcher
duperemove
compsize
libwebp
ananicy-cpp
earlyoom
profile-sync-daemon
pacman-contrib
nano
sudo
openssh
git
nvidia-open-dkms
nvidia-utils
nvidia-settings
gobject-introspection
scdoc
EOF

# Add LEOS files to the ISO
mkdir -p "$PROFILE/airootfs/root/LEOS"
cp -r "$SCRIPT_DIR/scripts" "$PROFILE/airootfs/root/LEOS/"
cp -r "$SCRIPT_DIR/desktop" "$PROFILE/airootfs/root/LEOS/"
cp -r "$SCRIPT_DIR/system" "$PROFILE/airootfs/root/LEOS/"
cp -r "$SCRIPT_DIR/filesystem" "$PROFILE/airootfs/root/LEOS/"
cp -r "$SCRIPT_DIR/kernel" "$PROFILE/airootfs/root/LEOS/"
cp "$SCRIPT_DIR/README.md" "$PROFILE/airootfs/root/LEOS/"

# Customize ISO metadata
sed -i 's/iso_name=.*/iso_name="leos"/' "$PROFILE/profiledef.sh"
sed -i 's/iso_label=.*/iso_label="LEOS"/' "$PROFILE/profiledef.sh"
sed -i 's/iso_publisher=.*/iso_publisher="LEOS"/' "$PROFILE/profiledef.sh"

# Build
rm -rf "$WORK_DIR" "$OUT_DIR"
mkdir -p "$OUT_DIR"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ISO built successfully!                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""
ls -lh "$OUT_DIR"/*.iso
echo ""
echo "Flash to USB: sudo dd if=$OUT_DIR/leos-*.iso of=/dev/sdX bs=4M status=progress"
