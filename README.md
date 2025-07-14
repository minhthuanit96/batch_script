# 🧰 Personal Utility Scripts by THUAN NGUYEN

Chào mừng đến với kho lưu trữ các script tự phát triển nhằm phục vụ mục đích **công việc cá nhân**, **quản trị hệ thống**, và **tự động hoá quy trình** trên các nền tảng **Windows** và **Ubuntu/Linux**.

---

## 🎯 Mục tiêu

- Tự động hoá công việc lặp đi lặp lại hằng ngày
- Tối ưu hoá quy trình vận hành hệ thống
- Tăng tính chủ động trong giám sát và sao lưu dữ liệu
- Ghi chú & chia sẻ lại kinh nghiệm thực chiến khi làm việc trên môi trường đa hệ điều hành

---

## 🧱 Danh sách script nổi bật

| Tên script                  | Mô tả ngắn                                      | Hệ điều hành      |
|----------------------------|-------------------------------------------------|-------------------|
| `proxmox_backup.sh`        | Tự động backup VM Proxmox lên OneDrive qua Rclone, có gửi thông báo qua Discord + Telegram | Ubuntu (Proxmox)  |
| `win-cleanup.ps1`          | Script PowerShell để dọn dẹp file tạm, cache, log trên Windows                       | Windows           |
| `ssl-renew-hook.sh`        | Hook script để tự động gia hạn chứng chỉ Let's Encrypt và reload dịch vụ liên quan | Ubuntu            |
| `vm-monitoring.sh`         | Theo dõi tài nguyên VM, gửi cảnh báo nếu vượt ngưỡng CPU/RAM                        | Ubuntu            |

> 📌 Danh sách sẽ được cập nhật liên tục khi có script mới được hoàn thiện hoặc cải tiến.

---

## 🚀 Môi trường sử dụng

- Windows 10/11 (PowerShell 5.1+)
- Ubuntu Server 20.04 / 22.04 LTS
- Một số script có thể chạy trong WSL2 hoặc môi trường container

---

## 📦 Cài đặt & sử dụng

Mỗi thư mục chứa script sẽ kèm theo:

- File script (`.sh` hoặc `.ps1`)
- `README.md` riêng hướng dẫn cụ thể cách sử dụng
- (Tuỳ chọn) `env.example` hoặc `.conf` mẫu

---

## 🔒 Bảo mật

- Các script có sử dụng token/API key sẽ được cấu hình qua file `.env` hoặc biến môi trường
- Không đẩy dữ liệu nhạy cảm lên Git
- Hướng dẫn rõ ràng để người dùng tự tạo token của riêng mình

---

## 🤝 Giấy phép & đóng góp

- Đây là các script dùng trong nội bộ hoặc mục đích cá nhân, phát hành dưới giấy phép MIT
- Nếu bạn thấy hữu ích hoặc muốn đóng góp, hãy tạo issue hoặc gửi pull request ❤️

---

## 🧑‍💻 Liên hệ

Bạn có thể liên hệ qua:


---

Cảm ơn bạn đã ghé qua kho script cá nhân của mình! 🚀