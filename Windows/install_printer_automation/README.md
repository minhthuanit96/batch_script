# batch_script
1. Script này giúp các bạn cài đặt máy in IP một cách nhanh chóng mà không cần phải tốn thời gian ngồi tại máy để cài đặt chỉ cần run script và tận hưởng kết quả.
2. Trên đây là các máy in được mình sử dụng tại nơi làm việc, các bạn có thể tuỳ chỉnh các file driver máy in theo ý của mình
3. Các bước chuẩn bị cho bộ script này có thể chạy được:
	- Driver máy in: thường là file có đuôi .inf, ở đây mình copy cả folder có chưa file inf (file này sẽ thấy khi giải nén gói cài đặt driver của máy in).
	- file vbs cần thiết để chạy các chương trình liên quan tới cài đặt máy in, ở đây mình có 3 file Prnmngr.vbs, Prnport.vbs, Prndrvr.vbs. 3 file này mình đã copy vào folder driver máy in, các file này cũng có thể tìm tại đường dẫn C:\Windows\System32\Printing_Admin_Scripts\en-US các bạn có thể sử dụng các file này tại vị trí này không cần thiết phải đặt 3 file trên vào cùng file driver của máy in
	- file script để setup máy in ở phiên bản này mình đã thêm tính năng chạy script bằng quyền Administrator, việc này giúp để cài các driver không bị lỗi.
4. Hiện tại script mình viết ra dùng để copy thư mục chứ file script và driver máy in từ NAS( Network Attached Storage) xuống máy cần cài đặt và chạy file script trên thư mục vừa mới copy.
5. Ở bản mới cập nhật này mình đã thực hiện thêm 1 số máy in cần thiệt tại nơi làm việc của mình và sau khi cài xong sẽ quay lại menu ban đầu để thực hiện tiếp việc cài máy khác. Ở phiên bản này mình chưa thực hiện việc cài hàng loạt.