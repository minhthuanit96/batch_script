#!/bin/bash

# ============================
# 📂 Load configuration from .env
# ============================
ENV_FILE="/root/script-bk/backup-config.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Config file not found: $ENV_FILE"
  exit 1
fi

#export $(grep -v '^#' "$ENV_FILE" | xargs)
set -a
source "$ENV_FILE"
set +a
# ============================
# 📦 Run vzdump with retention
# ============================
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/proxmox-backup-$(date +%Y%m%d%H%M%S).log"

vzdump $VM_LIST --quiet 1 \
    --mode $BACKUP_MODE \
    --compress zstd \
    --storage $STORAGE \
    --maxfiles $MAXFILES > "$LOG_FILE" 2>&1
RESULT=$?

# ============================
# 📩 Notification Message
# ============================
if [ $RESULT -eq 0 ]; then
    STATUS="✅ Backup completed successfully"
else
    STATUS="❌ Backup FAILED"
fi

TELEGRAM_MESSAGE="🔔 *Proxmox Backup Report*
🕒 Time: $TIMESTAMP
📦 VMs: $VM_LIST
💾 Storage: $STORAGE
⚙️ Mode: $BACKUP_MODE
📄 Status: $STATUS"

# ============================
# 📤 Send to Telegram
# ============================
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d message_thread_id="$TELEGRAM_THREAD_ID" \
    -d parse_mode="Markdown" \
    -d text="$TELEGRAM_MESSAGE"

# ============================
# 📤 Send to Discord
# ============================
DISCORD_MESSAGE="**Proxmox Backup Report**\\n\
Time: $TIMESTAMP\\n\
VMs: $VM_LIST\\n\
Storage: $STORAGE\\n\
Mode: $BACKUP_MODE\\n\
Status: $STATUS"

curl -s -H "Content-Type: application/json" -X POST \
    -d "{\"content\": \"$DISCORD_MESSAGE\"}" "$DISCORD_WEBHOOK"
