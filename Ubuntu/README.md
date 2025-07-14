# 🐧 Ubuntu/Linux Utility Scripts by THUAN NGUYEN

Đây là tập hợp các script mình tự phát triển nhằm phục vụ cho việc **quản trị hệ thống**, **sao lưu**, và **giám sát máy chủ** trên nền tảng **Ubuntu/Linux**.

---

## 🎯 Mục tiêu sử dụng

- Tự động hoá công việc quản lý VM và dịch vụ hệ thống
- Hỗ trợ sao lưu và đồng bộ dữ liệu với các nền tảng cloud
- Giám sát tài nguyên và gửi cảnh báo đến admin
- Tái sử dụng nhanh chóng trong các dự án cá nhân hoặc nội bộ

---

## 🧱 Danh sách script Ubuntu

| Tên script              | Mô tả chức năng                                                         |
|------------------------|--------------------------------------------------------------------------|
| `proxmox_backup.sh`    | Backup VM Proxmox lên OneDrive bằng rclone, thông báo qua Discord/Telegram |
| `ssl-renew-hook.sh`    | Tự động gia hạn Let's Encrypt và reload nginx/apache                     |
| `vm-monitoring.sh`     | Giám sát tài nguyên CPU/RAM, gửi cảnh báo khi vượt ngưỡng                 |
| `log-cleaner.sh`       | Dọn dẹp log hệ thống cũ sau X ngày, giải phóng ổ đĩa                      |

---

## 🛠️ Yêu cầu hệ thống

- Ubuntu 20.04 / 22.04 LTS
- Quyền `sudo`
- Gói cần thiết: `rclone`, `curl`, `jq`, `cron`, `mailutils` (tuỳ script)

---

## 📦 Cài đặt & chạy

1. Cấp quyền thực thi:
   ```bash
   chmod +x script_name.sh
   ```

2. Cấu hình `.env` nếu có:
   ```bash
   cp env.example .env
   nano .env
   ```

3. Chạy thủ công hoặc qua `cron`:
   ```bash
   ./script_name.sh
   ```

---

## 🔐 Bảo mật

- Không commit file `.env` chứa token API
- Dùng `.env.example` để chia sẻ cấu trúc mẫu

---

## 🧑‍💻 Đóng góp

Nếu bạn có ý tưởng hoặc cải tiến, hãy mở issue hoặc gửi pull request nhé!

---