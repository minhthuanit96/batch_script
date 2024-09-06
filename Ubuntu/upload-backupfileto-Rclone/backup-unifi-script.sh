#!/bin/bash
# Load environment variables from .env file
if [ -f .env ]; thenexport $(cat .env | xargs)
elseecho ".env file not found!"
exit 1
fi
# Function to send Telegram message
send_telegram_message() {local message=$1
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="${message}" -d message_thread_id="${MESSAGE_THREAD_ID}"
}
# Function to copy files and send status
copy_files() {echo "Starting backup at $(date)" &gt;&gt; "$LOG_FILE"
rclone copy "$BACKUP_DIR" "$REMOTE_DIR" &gt;&gt; "$LOG_FILE" 2&gt;&amp;1
result=$?
if [ $result -eq 0 ]; then
    message="Backup configuration unifi controller completed successfully at $(date)"
    echo "$message" &gt;&gt; "$LOG_FILE"
else
    message="Backup configuration unifi controller failed at $(date)"
    echo "$message" &gt;&gt; "$LOG_FILE"
fi
send_telegram_message "$message"
}
# Run the file copying function
copy_files
