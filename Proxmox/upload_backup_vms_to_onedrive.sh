#!/bin/bash

# ========================
# 🔧 Cấu hình đường dẫn log
# ========================
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="/var/log/proxmox_backup_$TIMESTAMP.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ========================
# 🧪 Load biến từ file .env
# ========================
load_env() {
    local env_file="$1"
    if [[ ! -f "$env_file" ]]; then
        echo "❌ Không tìm thấy file cấu hình: $env_file"
        exit 1
    fi
    export $(grep -v '^#' "$env_file" | xargs)
}

# ========================
# 📨 Gửi Discord
# ========================
send_discord() {
    local message="$1"
    [[ -z "$DISCORD_WEBHOOK" ]] && return
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "$(jq -n --arg content "$message" '{content: $content}')" \
         "$DISCORD_WEBHOOK" > /dev/null 2>&1
}

# ========================
# 📨 Gửi Telegram
# ========================
send_telegram() {
    local message="$1"
    [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]] && return
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    if [[ -n "$TELEGRAM_THREAD_ID" ]]; then
        curl -s -X POST "$url" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "message_thread_id=$TELEGRAM_THREAD_ID" \
            -d "text=$message" \
            -d "parse_mode=Markdown" > /dev/null
    else
        curl -s -X POST "$url" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=$message" \
            -d "parse_mode=Markdown" > /dev/null
    fi
}

# ========================
# 😀 Chuyển emoji cho Telegram
# ========================
translate_emojis() {
    local input="$1"
    echo "$input" | sed -e 's/:rocket:/🚀/g' \
                        -e 's/:x:/❌/g' \
                        -e 's/:white_check_mark:/✅/g' \
                        -e 's/:tada:/🎉/g' \
                        -e 's/:wastebasket:/🗑️/g' \
                        -e 's/:warning:/⚠️/g' \
                        -e 's/:arrow_up:/⬆️/g' \
                        -e 's/:mag:/🔍/g' \
                        -e 's/:open_file_folder:/📂/g' \
                        -e 's/:page_facing_up:/📄/g'
}

# ========================
# 📢 Gửi cả Discord & Telegram
# ========================
notify_all() {
    local message="$1"
    send_discord "$message"
    send_telegram "$(translate_emojis "$message")"
}

# ========================
# 📎 Gửi file log lên Discord và thông báo Telegram
# ========================
send_log_file() {
    [[ -z "$DISCORD_WEBHOOK" ]] && return
    curl -F "file1=@$LOG_FILE" \
         -F "payload_json={\"content\": \":page_facing_up: Log backup Proxmox tại thời điểm $TIMESTAMP\"}" \
         "$DISCORD_WEBHOOK" > /dev/null 2>&1
    send_telegram "📄 Log backup Proxmox tại thời điểm $TIMESTAMP đã được gửi lên Discord."
}

# ========================
# 🔐 Kiểm tra biến bắt buộc
# ========================
check_required_vars() {
    local required_vars=(BACKUP_DIR REMOTE_NAME REMOTE_FOLDER)
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "❌ Thiếu biến môi trường: $var"
            exit 1
        fi
    done
}

# ========================
# 🔍 Kiểm tra file có trên remote
# ========================
file_exists_on_remote() {
    local filename="$1"
    local folder="$2"
    rclone ls "$REMOTE_NAME:$folder" | awk '{print $2}' | grep -Fxq "$filename"
    return $?
}

# ========================
# 📁 Tạo thư mục remote nếu chưa tồn tại
# ========================
ensure_remote_folder_exists() {
    local remote_subfolder="$1"
    if ! rclone lsd "$REMOTE_NAME:$remote_subfolder" > /dev/null 2>&1; then
        rclone mkdir "$REMOTE_NAME:$remote_subfolder"
        if [[ $? -eq 0 ]]; then
            notify_all ":open_file_folder: Đã tạo thư mục $remote_subfolder trên remote $REMOTE_NAME."
        else
            notify_all ":x: Lỗi khi tạo thư mục $remote_subfolder trên remote."
            exit 1
        fi
    fi
}

# ========================
# 🚀 Bắt đầu
# ========================
ENV_FILE="upload.env"
load_env "$ENV_FILE"
check_required_vars

if [[ ! -d "$BACKUP_DIR" ]]; then
    notify_all ":x: Không tìm thấy thư mục backup: $BACKUP_DIR"
    exit 1
fi

notify_all ":rocket: Bắt đầu kiểm tra và sao lưu backup Proxmox lên $REMOTE_NAME..."

# 🔁 Duyệt từng VM
for vmid in $(ls "$BACKUP_DIR" | grep -oP '^vzdump-qemu-\K[0-9]+' | sort -u); do
    notify_all ":mag: Kiểm tra backup cho VM $vmid..."
    backups=($(ls -t "$BACKUP_DIR"/vzdump-qemu-"$vmid"-*.vma.zst 2>/dev/null))
    backup_count=${#backups[@]}
    if [[ $backup_count -eq 0 ]]; then
        notify_all ":x: Không tìm thấy backup cho VM $vmid."
        continue
    fi

    remote_vm_folder="$REMOTE_FOLDER/VM$vmid"
    ensure_remote_folder_exists "$remote_vm_folder"

    # 🗑️ Xoá bản cũ (nếu có > 2)
    if (( backup_count > 2 )); then
        for ((i=2; i<backup_count; i++)); do
            file="${backups[$i]}"
            filename="${file##*/}"
            if file_exists_on_remote "$filename" "$remote_vm_folder"; then
                rm -f "$file"
                notify_all ":wastebasket: Đã xoá $filename"
            fi
        done
    fi

    # ⬆️ Upload 2 bản mới nhất
    for ((i=0; i<2 && i<backup_count; i++)); do
        file="${backups[$i]}"
        filename="${file##*/}"

        notify_all ":arrow_up: Chuẩn bị upload $filename..."

        # ✅ Kiểm tra dung lượng > 95GB
        MAX_SIZE_BYTES=$((95 * 1024 * 1024 * 1024))
        if [[ $(stat -c%s "$file") -gt $MAX_SIZE_BYTES ]]; then
            notify_all ":warning: File $filename lớn hơn 95GB. Đang chia nhỏ bằng split..."
            split -b 95G "$file" "${file}.part_"
            if [[ $? -ne 0 ]]; then
                notify_all ":x: Lỗi khi chia nhỏ $filename."
                continue
            fi

            for part in "${file}.part_"*; do
                partname="${part##*/}"
                if file_exists_on_remote "$partname" "$remote_vm_folder"; then
                    notify_all ":warning: $partname đã tồn tại. Bỏ qua upload."
                else
                    rclone copy "$part" "$REMOTE_NAME:$remote_vm_folder"
                    if [[ $? -eq 0 ]]; then
                        notify_all ":white_check_mark: Đã upload thành công phần $partname."
                    else
                        notify_all ":x: Lỗi khi upload phần $partname."
                    fi
                fi
            done
            continue
        fi

        # ✅ Nếu file nhỏ hơn 95GB thì upload bình thường
        if file_exists_on_remote "$filename" "$remote_vm_folder"; then
            notify_all ":warning: $filename đã tồn tại. Bỏ qua upload."
        else
            rclone copy "$file" "$REMOTE_NAME:$remote_vm_folder"
            if [[ $? -eq 0 ]]; then
                notify_all ":white_check_mark: Đã sao lưu $filename thành công."
            else
                notify_all ":x: Lỗi khi sao lưu $filename."
            fi
        fi
    done
done

# ✅ Kết thúc
notify_all ":tada: Hoàn tất quá trình backup Proxmox!"
send_log_file
