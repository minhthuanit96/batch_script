# 📋 Cấu Hình Chia Sẻ File SMB An Toàn (SMB Secure Share)

## 🎯 Mục đích
Script này hỗ trợ cấu hình và tạo thư mục chia sẻ file qua SMB một cách an toàn trên Windows. Thay vì sử dụng thông tin cứng trong code, script sử dụng file cấu hình `.env` để bảo mật mật khẩu và tên đăng nhập. 

Các tính năng chính:
1. Tạo một Group và User đặc biệt (`SMBUser`) với mật khẩu mạnh.
2. Vô hiệu hóa SMBv1 (kém an toàn) và đảm bảo SMBv2/SMBv3 đang hoạt động.
3. Kiểm tra các chính sách ký điện tử (SMB Signing) từ Registry.
4. Tạo thư mục chia sẻ (mặc định là `scan`) và phân quyền NTFS chỉ cho User đặc biệt.
5. Tạo Shortcut truy cập ra màn hình Desktop.
6. Cấm User chia sẻ file này đăng nhập trực tiếp vào hệ thống (Local & RDP) thông qua Local Security Policy (Secedit).

## 📋 Yêu cầu
- Windows 10/11 hoặc Windows Server 2016+
- PowerShell 5.1+
- Quyền Administrator: ✅ **BẮT BUỘC**

## 🚀 Cách sử dụng

### Bước 1: Cấu hình tài khoản
1. Mở thư mục `SMB_project`.
2. Sẽ có file mẫu là `configure.env.example`. Hãy **Copy** file này và đổi tên bản copy thành **`configure.env`**.
3. Mở file `configure.env` bằng Notepad và thay đổi thông số mật khẩu, user, và tên thư mục theo ý của bạn:
   ```env
   SMB_GROUP_NAME=SMBUsers
   SMB_USER_NAME=SMBUser
   SMB_PASSWORD=MatKhauBaoMatCuaBan123!
   SMB_SHARE_NAME=scan
   ```

### Bước 2: Chạy Script
Bạn có thể chạy script bằng một trong hai cách:

**Cách 1 (Dễ nhất): Chạy qua file `.bat`**
- Chỉ cần click đúp vào file `Run-SetupSMBSecureShare.bat`.
- File này sẽ tự động xin quyền Administrator và chạy script PowerShell một cách an toàn (bypass Execution Policy).

**Cách 2: Chạy trực tiếp trên PowerShell**
1. Mở PowerShell với quyền Administrator.
2. Di chuyển đến thư mục chứa script:
   ```powershell
   cd "Đường\dẫn\đến\SMB_project"
   ```
3. Chạy script:
   ```powershell
   .\Setup-SMBSecureShare.ps1
   ```

## ⚙️ Cấu hình (File `configure.env`)
- `SMB_GROUP_NAME`: Tên nhóm người dùng SMB (Mặc định: SMBUsers)
- `SMB_USER_NAME`: Tên tài khoản chia sẻ SMB (Mặc định: SMBUser)
- `SMB_PASSWORD`: Mật khẩu cho tài khoản (Bắt buộc phải là mật khẩu mạnh - có chữ hoa, thường, số và ký tự đặc biệt).
- `SMB_SHARE_NAME`: Tên thư mục chia sẻ (Mặc định: scan).
- `SMB_SHARE_PATH`: (Tùy chọn) Đường dẫn cụ thể của thư mục chia sẻ. Nếu để trống sẽ tạo ở thư mục mặc định `C:\Users\<Tên_User>\scan`.

## 📝 Lưu ý
- **Không bao giờ** đẩy file `configure.env` lên GitHub để tránh rò rỉ mật khẩu máy tính của bạn. Kho chứa này đã được cấu hình `.gitignore` để tự động bỏ qua các file `*.env`.
- Mật khẩu `SMB_PASSWORD` bắt buộc phải vượt qua bài kiểm tra độ phức tạp của Windows (có độ dài đủ, chữ in hoa, thường, số). Nếu không, quá trình tạo User sẽ báo lỗi.
