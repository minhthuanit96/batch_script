# 📦 Proxmox Backup to Cloud with Notifications (Discord + Telegram)

Một script tự động sao lưu các bản backup `.vma.zst` của Proxmox VM lên remote cloud (ví dụ OneDrive qua `rclone`), **kèm theo thông báo chi tiết** được gửi đến **Discord và Telegram**, đồng thời **tránh upload đè file nếu đã tồn tại**.

---

## 🛠️ Yêu cầu cài đặt

### 1. Proxmox Backup
- Proxmox VE phải có cơ chế tạo file backup VM (`.vma.zst`) tại thư mục thường là:
  ```
  /var/lib/vz/dump
  ```

### 2. Rclone
- Dùng để đồng bộ dữ liệu từ máy chủ lên các dịch vụ cloud (OneDrive, Google Drive, S3,...)
- Cài đặt:
  ```bash
  apt update && apt install -y rclone
  ```

### 3. jq
- Dùng để tạo JSON body khi gửi webhook đến Discord
  ```bash
  apt install jq -y
  ```

### 4. curl
- Dùng để gửi HTTP request đến Telegram và Discord

---

## 📁 Cấu trúc file cần thiết

```
.
├── proxmox_backup.sh       # Script chính
├── backup.env              # File cấu hình biến môi trường
└── README.md               # Hướng dẫn sử dụng (file này)
```

---

## ⚙️ Cấu hình `backup.env`

Tạo file `.env` (đặt tên `backup.env`) chứa các biến môi trường cần thiết:

```env
# Đường dẫn chứa các file backup của Proxmox (.vma.zst)
BACKUP_DIR=/var/lib/vz/dump

# Cấu hình remote rclone
REMOTE_NAME=onedrive
REMOTE_FOLDER=ProxmoxBackups

# Discord webhook URL
DISCORD_WEBHOOK=https://discord.com/api/webhooks/...

# Telegram bot
TELEGRAM_BOT_TOKEN=123456789:ABCdefGhiJKlmnoPQRstuVWxyz
TELEGRAM_CHAT_ID=-1001234567890              # ID của channel hoặc group
TELEGRAM_THREAD_ID=456                       # ID của message thread (nếu dùng topic)
```

> **Lưu ý:** Nếu không dùng Telegram hoặc Discord, bạn có thể để trống biến tương ứng.

---

## 🚀 Cách sử dụng

1. **Tạo file `backup.env`** theo hướng dẫn trên.
2. **Cấp quyền thực thi cho script:**
   ```bash
   chmod +x proxmox_backup.sh
   ```
3. **Chạy script thủ công:**
   ```bash
   ./proxmox_backup.sh
   ```
4. (Tuỳ chọn) **Thêm vào crontab để tự động chạy hàng ngày:**
   ```bash
   crontab -e
   ```
   Thêm dòng:
   ```
   0 2 * * * /path/to/proxmox_backup.sh
   ```

---

## ✅ Tính năng nổi bật

- 🔁 Tự động duyệt các bản backup theo VMID.
- 📁 Tạo thư mục theo từng VM (`/ProxmoxBackups/VM101`, `VM102`, ...)
- ⚠️ Nếu file backup **đã tồn tại trên remote**, **không upload lại**.
- 🗑️ Tự động **xoá bản backup cũ** nếu đã upload được bản mới.
- 🔔 Thông báo đầy đủ qua **Discord + Telegram**:
  - Bắt đầu
  - Thông tin từng VM
  - Upload thành công / lỗi
  - Bỏ qua nếu trùng file
  - Hoàn tất
- 📄 Gửi log `.log` chi tiết lên Discord kèm thời gian.

---

## 💬 Ví dụ log Discord/Telegram

```
🚀 Bắt đầu kiểm tra và sao lưu backup Proxmox lên onedrive...
🔍 Kiểm tra backup cho VM 101...
⬆️ Chuẩn bị upload vzdump-qemu-101-2025_07_10-02_00_01.vma.zst
✅ Đã sao lưu vzdump-qemu-101-2025_07_10-02_00_01.vma.zst thành công.
🎉 Hoàn tất quá trình backup Proxmox!
📄 Log backup Proxmox tại thời điểm 2025-07-10_02-00-01 đã được gửi lên Discord.
```

---

## 🔒 Lưu ý bảo mật

- KHÔNG đẩy file `backup.env` chứa token lên GitHub.
- Bạn có thể tạo thêm file `.env.example` để chia sẻ cấu trúc mẫu.

---

## 🧪 Kiểm tra kết nối rclone

Trước khi chạy script, nên test upload thủ công:
```bash
rclone copy /var/lib/vz/dump/testfile.zst onedrive:ProxmoxBackups/Test
```

---

## 💡 Gợi ý mở rộng

- Tích hợp thêm gửi log qua email
- Chạy script dạng systemd service
- Bổ sung cấu hình rotation trên remote (giữ N bản mới nhất)

---

## 🧑‍💻 Đóng góp

Mọi đóng góp đều hoan nghênh. Hãy tạo pull request hoặc issue nếu bạn muốn cải thiện script.