# batch_script
1. Script này giúp các bạn cài đặt máy in IP một cách nhanh chóng mà không cần phải tốn thời gian ngồi tại máy để cài đặt chỉ cần run script và tận hưởng kết quả.
2. Trên đây mình sử dụng máy in Brother MFC-L2701DW để  làm ví dụ, mình có để sẵn folder chứ driver và các file cần thiết để chạy script ở trên.
3. Các bước chuẩn bị cho bộ script này có thể chạy được:
	- Driver máy in: thường là file có đuôi .inf, ở đây mình copy cả folder có chưa file inf (file này sẽ thấy khi giải nén gói cài đặt driver của máy in).
	- file vbs cần thiết để chạy các chương trình liên quan tới cài đặt máy in, ở đây mình có 3 file Prnmngr.vbs, Prnport.vbs, Prndrvr.vbs. 3 file này mình đã copy vào folder driver máy in.
	- file script để setup máy in.
4. Hiện tại script mình viết ra dùng để copy thư mục chứ file script và driver máy in từ NAS( Network Attached Storage) xuống máy cần cài đặt và chạy file script trên thư mục vừa mới copy.
### Script mình viết còn một số phần chưa hoàn thiện, hiện tại còn phải nhập thủ công một số phần ###