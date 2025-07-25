#!/bin/bash

# ============================
# 📂 Load configuration from .env
# ============================
ENV_FILE="/root/script-bk/backup-config.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Config file not found: $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

# ============================
# check quantity logfile and remove older logfile
# ============================

ls -1t "$LOG_DIR/$LOG_BASENAME-"*.log 2>/dev/null | tail -n +$((LOG_RETAIN + 1)) | xargs -r rm --

# ============================
# 📦 Run vzdump to multiple storages
# ============================

STORAGE_LIST=($STORAGES)
OVERALL_RESULT=0

for TARGET_STORAGE in "${STORAGE_LIST[@]}"; do
  echo "▶️ Starting backup to $TARGET_STORAGE ..." >> "$LOG_FILE"

  vzdump $VM_LIST --quiet 1 \
      --mode $BACKUP_MODE \
      --compress $COMPRESSION \
      --storage $TARGET_STORAGE \
      --maxfiles $MAXFILES \
      --notes "Nightly backup of {{guestname}} (VMID: {{vmid}}) on {{node}} – $TIMESTAMP" \
      >> "$LOG_FILE" 2>&1

  RESULT=$?
  if [ $RESULT -eq 0 ]; then
      echo "✅ Backup to $TARGET_STORAGE succeeded." >> "$LOG_FILE"
  else
      echo "❌ Backup to $TARGET_STORAGE failed." >> "$LOG_FILE"
      OVERALL_RESULT=1
  fi
done

# ============================
# 📩 Notification Message
# ============================
if [ $OVERALL_RESULT -eq 0 ]; then
    STATUS="✅ Backup completed successfully to all storages"
else
    STATUS="❌ Backup FAILED on one or more storages"
fi

TELEGRAM_MESSAGE="🔔 *Proxmox Backup Report*
🕒 Time: $TIMESTAMP
📦 VMs: $VM_LIST
💾 Storages: $STORAGES
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
Storages: $STORAGES\\n\
Mode: $BACKUP_MODE\\n\
Status: $STATUS"

curl -s -H "Content-Type: application/json" -X POST \
    -d "{\"content\": \"$DISCORD_MESSAGE\"}" "$DISCORD_WEBHOOK"
