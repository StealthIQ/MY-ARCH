#!/bin/bash
# Start Hyprland Error Monitor Bot in background

BOT_DIR="$HOME/.config/hypr/monitor-bot"
VENV_DIR="$BOT_DIR/venv"
BOT_SCRIPT="$HOME/.config/hypr/scripts/telegram-error-bot.py"
LOG_FILE="$HOME/.config/hypr/logs/bot.log"

mkdir -p "$HOME/.config/hypr/logs"

[ -f "$BOT_SCRIPT" ] || exit 0

# Setup venv if missing
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR" 2>/dev/null || exit 0
    "$VENV_DIR/bin/pip" install aiohttp 2>/dev/null || true
fi

# Check config exists
[ -f "$HOME/.config/hypr/scripts/.env" ] || [ -f "$HOME/.config/hypr/telegram-bot.conf" ] || exit 0

source "$VENV_DIR/bin/activate"
nohup python3 "$BOT_SCRIPT" >> "$LOG_FILE" 2>&1 &
echo $! > "$BOT_DIR/bot.pid"
