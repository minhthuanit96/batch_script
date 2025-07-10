#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Function to send Telegram message 
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d message_thread_id="${MESSAGE_THREAD_ID}"
}

# Function to copy files and send status
copy_files() {
    echo "Starting backup at $(date)" >> "$LOG_FILE"

    # Step 1: Copy from BACKUP_DIR to UPLOAD_FOLDER
    echo "Copying files from $BACKUP_DIR to $UPLOAD_FOLDER..." >> "$LOG_FILE"
    mkdir -p "$UPLOAD_FOLDER"
    cp -r "$BACKUP_DIR"/* "$UPLOAD_FOLDER"/ >> "$LOG_FILE" 2>&1

    # Step 2: Use rclone to copy from UPLOAD_FOLDER to remote
    echo "Uploading from $UPLOAD_FOLDER to $REMOTE_DIR via rclone..." >> "$LOG_FILE"
    rclone copy "$UPLOAD_FOLDER" "$REMOTE_DIR" >> "$LOG_FILE" 2>&1

    result=$?
    if [ $result -eq 0 ]; then
        message="✅ Backup configuration UniFi Controller completed successfully at $(date)"
    else
        message="❌ Backup configuration UniFi Controller failed at $(date)"
    fi

    echo "$message" >> "$LOG_FILE"
    send_telegram_message "$message"
}

# Run the file copying function
copy_files
