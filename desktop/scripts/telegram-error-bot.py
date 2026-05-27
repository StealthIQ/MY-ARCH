#!/usr/bin/env python3
"""Hyprland Error Monitor — sends critical errors to Telegram"""

import os, sys, time, json, subprocess, asyncio, logging
from datetime import datetime
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(Path.home() / '.config/hypr/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('hypr-bot')

class HyprlandMonitorBot:
    def __init__(self):
        self.bot_token = None
        self.chat_id = None
        self.load_config()
        self.error_patterns = ['error', 'Error', 'ERROR', 'crash', 'failed', 'Failed',
                               'fatal', 'segfault', 'core dumped', 'permission denied']

    def load_config(self):
        for path in [Path.home() / '.config/hypr/scripts/.env',
                     Path('/etc/hypr-bot/.env')]:
            if path.exists():
                for line in path.read_text().splitlines():
                    if '=' in line and not line.startswith('#'):
                        k, v = line.split('=', 1)
                        os.environ[k.strip()] = v.strip()
        self.bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
        self.chat_id = os.environ.get('TELEGRAM_CHAT_ID')

    async def send(self, message):
        if not self.bot_token or not self.chat_id:
            return
        try:
            import aiohttp
            async with aiohttp.ClientSession() as s:
                await s.post(f"https://api.telegram.org/bot{self.bot_token}/sendMessage",
                             json={'chat_id': self.chat_id, 'text': message, 'parse_mode': 'HTML'})
        except Exception as e:
            logger.error(f"Send failed: {e}")

    def check_critical_apps(self):
        errors = []
        for app in ['waybar', 'hyprpaper', 'mako', 'hypridle']:
            if subprocess.run(['pgrep', '-x', app], capture_output=True).returncode != 0:
                errors.append(f"❌ {app} not running")
        return errors

    async def run(self):
        hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        await self.send(f"🖥️ <b>Hyprland Monitor Started</b>\n<code>{hostname}</code> — {datetime.now():%H:%M}")

        last_errors = set()
        while True:
            try:
                errors = self.check_critical_apps()
                new = set(errors) - last_errors
                if new:
                    await self.send("🚨 <b>Alert</b>\n" + '\n'.join(new))
                last_errors = set(errors)
                await asyncio.sleep(30)
            except Exception as e:
                logger.error(f"Loop error: {e}")
                await asyncio.sleep(60)

if __name__ == '__main__':
    bot = HyprlandMonitorBot()
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        pass
