#!/bin/bash
# Install hypr-bot as system service
set -e

[ "$EUID" -eq 0 ] || { echo "Run as root"; exit 1; }

BOT_DIR="/opt/hypr-bot"
CONFIG_DIR="/etc/hypr-bot"

mkdir -p "$BOT_DIR" "$CONFIG_DIR" /var/log/hypr-bot /var/lib/hypr-bot

# Copy bot
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/hypr-bot.py" "$BOT_DIR/"

# Create venv
if [ ! -d "$BOT_DIR/venv" ]; then
    python3 -m venv "$BOT_DIR/venv"
    "$BOT_DIR/venv/bin/pip" install --upgrade pip aiohttp
fi

# Config
if [ ! -f "$CONFIG_DIR/.env" ]; then
    cat > "$CONFIG_DIR/.env" << 'EOF'
# Get token from @BotFather, chat ID from @userinfobot
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
EOF
    chmod 600 "$CONFIG_DIR/.env"
    echo "Edit $CONFIG_DIR/.env with your Telegram credentials"
fi

# Service
cp "$SCRIPT_DIR/hypr-bot.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable hypr-bot.service
systemctl restart hypr-bot.service

sleep 2
systemctl is-active --quiet hypr-bot && echo "✓ Bot running" || echo "! Check: journalctl -u hypr-bot"
