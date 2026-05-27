#!/usr/bin/env python3
"""System-Wide Error Monitor Bot with Telegram Control — by iceyxsm"""

import os, sys, time, json, hashlib, subprocess, asyncio, logging
from datetime import datetime, timedelta
from pathlib import Path
from collections import deque

LOG_DIR = Path('/var/log/hypr-bot')
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler(LOG_DIR / 'bot.log'), logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger('system-bot')

class SystemMonitorBot:
    def __init__(self):
        self.bot_token = None
        self.chat_id = None
        self.hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        self.ignored_file = Path('/var/lib/hypr-bot/ignored_errors.json')
        self.ignored_errors = set()
        self.recent_errors = deque(maxlen=500)
        self.startup_time = datetime.now()
        self.last_journal_check = time.time()
        self.load_config()
        self.load_ignored()

    def load_config(self):
        for path in [Path('/etc/hypr-bot/.env')]:
            if path.exists():
                for line in path.read_text().splitlines():
                    if '=' in line and not line.startswith('#'):
                        k, v = line.split('=', 1)
                        os.environ[k.strip()] = v.strip()
        self.bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
        self.chat_id = os.environ.get('TELEGRAM_CHAT_ID')

    def load_ignored(self):
        if self.ignored_file.exists():
            try: self.ignored_errors = set(json.loads(self.ignored_file.read_text()))
            except: pass

    def save_ignored(self):
        self.ignored_file.parent.mkdir(parents=True, exist_ok=True)
        self.ignored_file.write_text(json.dumps(list(self.ignored_errors)))

    def error_id(self, text):
        return '#' + hashlib.md5(text[:100].encode()).hexdigest()[:8].upper()

    async def send(self, message, reply_markup=None):
        if not self.bot_token or not self.chat_id: return
        try:
            import aiohttp
            payload = {'chat_id': self.chat_id, 'text': message, 'parse_mode': 'HTML'}
            if reply_markup: payload['reply_markup'] = json.dumps(reply_markup)
            async with aiohttp.ClientSession() as s:
                await s.post(f"https://api.telegram.org/bot{self.bot_token}/sendMessage", json=payload)
        except Exception as e:
            logger.error(f"Send failed: {e}")

    async def startup(self):
        await self.send(
            f"🖥️ <b>System Started</b>\n<code>{self.hostname}</code>\n{datetime.now():%Y-%m-%d %H:%M}\n✅ Monitoring errors",
            {"inline_keyboard": [[{"text": "💓 Alive", "callback_data": "/alive"}, {"text": "❓ Help", "callback_data": "/help"}]]}
        )

    def get_journal_errors(self):
        errors = []
        try:
            since = datetime.fromtimestamp(self.last_journal_check).strftime('%Y-%m-%d %H:%M:%S')
            self.last_journal_check = time.time()
            result = subprocess.run(
                ['journalctl', '--since', since, '--priority=err', '--no-pager', '-o', 'short'],
                capture_output=True, text=True, timeout=10
            )
            for line in result.stdout.split('\n'):
                if line and not line.startswith('--'):
                    errors.append(line.strip())
        except: pass
        return errors[-20:]

    async def process_errors(self, errors):
        for err in errors:
            eid = self.error_id(err)
            if eid in self.ignored_errors: continue
            if eid in self.recent_errors: continue
            self.recent_errors.append(eid)
            await self.send(f"🚨 <b>{eid}</b>\n<code>{err[:300]}</code>")

    async def handle_commands(self):
        if not self.bot_token: return
        try:
            import aiohttp
            offset = 0
            while True:
                try:
                    async with aiohttp.ClientSession() as s:
                        async with s.get(f"https://api.telegram.org/bot{self.bot_token}/getUpdates",
                                         params={'offset': offset, 'limit': 10}) as r:
                            if r.status == 200:
                                data = await r.json()
                                for u in data.get('result', []):
                                    offset = max(offset, u['update_id'] + 1)
                                    msg = u.get('message', {}).get('text', '')
                                    if msg == '/alive':
                                        up = str(timedelta(seconds=int((datetime.now() - self.startup_time).total_seconds())))
                                        await self.send(f"💓 <b>Alive</b>\nUptime: {up}\nIgnored: {len(self.ignored_errors)}")
                                    elif msg.startswith('/ignore '):
                                        eid = msg[8:].strip().upper()
                                        if not eid.startswith('#'): eid = '#' + eid
                                        self.ignored_errors.add(eid)
                                        self.save_ignored()
                                        await self.send(f"🚫 Ignoring {eid}")
                                    elif msg == '/help':
                                        await self.send("/alive — status\n/ignore #ID — ignore error\n/ignoring — list ignored")
                                    elif msg == '/ignoring':
                                        await self.send("🚫 " + ', '.join(sorted(self.ignored_errors)) if self.ignored_errors else "None ignored")
                except: pass
                await asyncio.sleep(3)
        except ImportError: pass

    async def run(self):
        logger.info("System Monitor Bot starting...")
        await self.startup()
        asyncio.create_task(self.handle_commands())
        while True:
            try:
                errors = self.get_journal_errors()
                if errors: await self.process_errors(errors)
                await asyncio.sleep(10)
            except Exception as e:
                logger.error(f"Loop: {e}")
                await asyncio.sleep(30)

if __name__ == '__main__':
    bot = SystemMonitorBot()
    try: asyncio.run(bot.run())
    except KeyboardInterrupt: pass
