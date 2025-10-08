#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo ".env file not found!"
    exit 1
fi

# --- Logging ---
# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# --- Prerequisite Checks ---
# Function to check for required tools
check_tools() {
    local required_tools=("curl" "rclone" "rsync")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log "Error: Required tool '$tool' is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Function to check for required environment variables
check_vars() {
    local required_vars=("TELEGRAM_BOT_TOKEN" "CHAT_ID" "BACKUP_DIR" "UPLOAD_FOLDER" "REMOTE_DIR" "LOG_FILE")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "Error: Environment variable '$var' is not set. Please define it in the .env file."
            exit 1
        fi
    done
}

# --- Core Functions ---
# Function to send Telegram message
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d message_thread_id="${MESSAGE_THREAD_ID}" > /dev/null
}

# Function to clean up old local backups, keeping the 2 newest
cleanup_local_dir() {
    local dir=$1
    log "Cleaning up old backups in $dir..."
    ls -1t "$dir"/*.unf | tail -n +3 | while read -r file; do
        rm -f "$file"
        log "Deleted old local backup: $file"
    done
}

# Function to clean up old remote backups, keeping the 2 newest
cleanup_remote_dir() {
    local remote_dir=$1
    log "Cleaning up old backups in $remote_dir..."
    files_to_delete=$(rclone lsf --files-only --include "*.unf" --format "tp" "$remote_dir" --separator "," | sort -r | tail -n +3 | cut -d',' -f2-)

    for file in $files_to_delete; do
        rclone deletefile "$remote_dir/$file"
        log "Deleted old remote backup: $remote_dir/$file"
    done
}

# --- Main Backup Logic ---
run_backup() {
    log "Starting backup process..."

    # Step 1: Check for new files in BACKUP_DIR
    log "Checking for new files in $BACKUP_DIR..."
    mkdir -p "$UPLOAD_FOLDER"
    changes=$(rsync -an --include='*.unf' --exclude='*' --out-format="%n" "$BACKUP_DIR"/ "$UPLOAD_FOLDER"/)

    if [ -z "$changes" ]; then
        log "No new backups found in BACKUP_DIR. Skipping."
        # send_telegram_message "ℹ️ No new backups to upload today."
        return
    fi

    # Step 2: Sync files from BACKUP_DIR to UPLOAD_FOLDER
    log "New backups found. Syncing from $BACKUP_DIR to $UPLOAD_FOLDER..."
    rsync -a --include '*.unf' --exclude '*' "$BACKUP_DIR"/ "$UPLOAD_FOLDER"/

    # Step 3: Upload to remote
    log "Uploading from $UPLOAD_FOLDER to $REMOTE_DIR via rclone..."
    rclone copy --include "*.unf" "$UPLOAD_FOLDER" "$REMOTE_DIR"

    # Step 4: Cleanup old backups
    cleanup_local_dir "$UPLOAD_FOLDER"
    cleanup_remote_dir "$REMOTE_DIR"

    log "Backup process completed successfully."
}

# --- Main Execution ---
main() {
    check_vars
    check_tools

    # Trap errors and send a notification
    trap 'send_telegram_message "❌ Backup configuration UniFi Controller failed at $(date). Check log file for details."; exit 1' ERR

    run_backup

    # If we reach here, it means success
    send_telegram_message "✅ Backup configuration UniFi Controller completed successfully at $(date)"
}

main
