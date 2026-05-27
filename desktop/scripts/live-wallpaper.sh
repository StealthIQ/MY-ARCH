#!/bin/bash
# Live Wallpaper Desktop Script — uses mpvpaper for video wallpapers

VIDEO_DIR="$HOME/.config/hypr/wallpapers/live-wallpapers"
PIDFILE="/tmp/mpvpaper-desktop.pid"

find_video() {
    find "$VIDEO_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \) 2>/dev/null | head -n1
}

if ! command -v mpvpaper &>/dev/null; then
    echo "mpvpaper not installed! Install with: yay -S mpvpaper"
    hyprpaper &
    exit 0
fi

case "$1" in
    start)
        [ -f "$PIDFILE" ] && kill $(cat "$PIDFILE") 2>/dev/null
        pkill -x mpvpaper 2>/dev/null
        rm -f "$PIDFILE"

        VIDEO=$(find_video)
        if [ -z "$VIDEO" ]; then
            echo "No video found in $VIDEO_DIR"
            hyprpaper &
            exit 0
        fi

        MONITORS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
        [ -z "$MONITORS" ] && MONITORS="HDMI-A-1"

        for MON in $MONITORS; do
            mpvpaper --mpv-options "--loop --no-audio --no-osc" "$MON" "$VIDEO" &
        done
        echo $! > "$PIDFILE"
        ;;
    stop)
        [ -f "$PIDFILE" ] && kill $(cat "$PIDFILE") 2>/dev/null
        pkill -x mpvpaper 2>/dev/null
        rm -f "$PIDFILE"
        hyprpaper &
        ;;
    restart)
        $0 stop; sleep 1; $0 start
        ;;
    status)
        pgrep -x mpvpaper >/dev/null && echo "RUNNING" || echo "STOPPED"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        ;;
esac
