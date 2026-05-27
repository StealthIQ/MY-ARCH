#!/bin/bash
# Lock screen with video wallpaper — mpvpaper plays behind transparent hyprlock

VIDEO_DIR="$HOME/.config/hypr/wallpapers/live-wallpapers"
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock-video.conf"

find_video() {
    find "$VIDEO_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) 2>/dev/null | head -n1
}

if ! command -v mpvpaper &>/dev/null; then
    hyprlock
    exit 0
fi

VIDEO=$(find_video)
if [ -z "$VIDEO" ]; then
    hyprlock
    exit 0
fi

MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null)
[ -z "$MONITOR" ] && MONITOR="HDMI-A-1"

pkill -x mpvpaper 2>/dev/null

mpvpaper --layer overlay --mpv-options "--loop --no-audio --no-osc --no-osd-bar" "$MONITOR" "$VIDEO" &
MPVPAPER_PID=$!
sleep 0.3

if [ -f "$HYPRLOCK_CONFIG" ]; then
    hyprlock --config "$HYPRLOCK_CONFIG"
else
    hyprlock
fi

kill $MPVPAPER_PID 2>/dev/null
wait $MPVPAPER_PID 2>/dev/null
hyprpaper &
