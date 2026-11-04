# HƯỚNG DẪN DEMO DỰ ÁN APPAIR

## 1. Khởi động nhanh toàn bộ hệ thống
Dự án có thể khởi động theo 2 cách:

### Cách 1: Chạy file start.bat ở thư mục gốc
Nhấp đúp chuột vào file `start.bat` tại thư mục `d:\AppAir`. File này sẽ tự động mở 3 cửa sổ:
- Backend Node.js cổng 3000
- AI Service FastAPI cổng 8000
- Data Pipeline cron tự động thu thập mỗi giờ

Sau đó mở terminal tại thư mục `mobile` và chạy:
```powershell
flutter run -d chrome --web-port 8080
```
Truy cập: `http://localhost:8080`

### Cách 2: Chạy trực tiếp từ Visual Studio Code
Mở thư mục `d:\AppAir` trong VS Code. Chọn thẻ Run and Debug (hoặc bấm F5) và chọn:
- `AppAir Web (Chrome)`
Hệ thống sẽ tự động khởi chạy ngầm 3 dịch vụ phụ trợ trước khi mở Chrome.

---

## 2. Tài khoản thử nghiệm
- Tài khoản quản trị viên: `admin@appair.vn` / `admin123`
- Tài khoản người dùng mẫu: `demo@appair.vn` / `123456`

---

## 3. Thứ tự các bước Demo trên ứng dụng Web

### Bước 1: Màn hình Đăng nhập
- Đăng nhập bằng tài khoản người dùng hoặc bấm Trải nghiệm ngay.
- Hệ thống hỗ trợ đăng ký tài khoản mới và chọn ngay 1 trong 4 nhóm sức khỏe.

### Bước 2: Trang chủ
- Hiển thị AQI thời gian thực và nồng độ bụi mịn PM2.5.
- 6 thẻ thông số chi tiết: PM2.5, PM10, CO, NO2, SO2, O3.
- Nền bầu trời đổi màu theo thời gian thực (Sáng, Chiều, Tối).

### Bước 3: Dự báo 24 giờ
- Biểu đồ trực quan so sánh dữ liệu thực tế 24 giờ qua và dự báo 24 giờ tới từ mô hình học sâu 1D-CNN + LSTM.
- Bảng chi tiết từng giờ kèm thanh đo màu sắc theo quy chuẩn QCVN 05:2023/BTNMT.
- Hiển thị trực tiếp các chỉ số đánh giá mô hình: RMSE = 16.25 µg/m³, MAE = 10.39 µg/m³.

### Bước 4: Bản tin chất lượng không khí
- Danh sách bản tin do ban quản trị đăng tải.
- Tích hợp công cụ hỗ trợ gợi ý và soạn thảo nội dung tự động dựa trên số liệu thực tế từ Database.

### Bước 5: Bản đồ không khí
- Bản đồ nền Esri ArcGIS hiển thị 10 trạm thuộc các phường trọng điểm TP. Thủ Dầu Một.
- Vòng tròn ranh giới khoanh vùng dữ liệu trong bán kính 20km quanh Thủ Dầu Một.
- Thử nghiệm chạm chọn điểm bất kỳ trong bán kính 20km để nội suy 6 chỉ số từ mạng lưới Database AppAir.
- Thử nghiệm chạm chọn điểm ngoài bán kính 20km: ứng dụng từ chối hiển thị chỉ số ảo và cung cấp nút Về tâm Thủ Dầu Một.
- Ô tìm kiếm thông minh: Gõ "Huỳnh Văn Lũy" hoặc "Phú Lợi" để tự động gợi ý và chuyển nhanh góc nhìn.

### Bước 6: Chat AI
- Trò chuyện với trợ lý không khí sử dụng mô hình Gemini kèm dữ liệu thực tế tại TP. Thủ Dầu Một.
- Cơ chế xoay vòng 4 API Key đảm bảo không bị gián đoạn hạn mức.

### Bước 7: Thông báo và Cài đặt
- Thẻ thông báo thời tiết thiết kế hiện đại hiển thị biên độ PM2.5 trong ngày và lời khuyên phù hợp với từng nhóm sức khỏe.
- Nút Xem thử để kiểm tra hiển thị popup và âm thanh chuông báo dịu nhẹ.
- Trang Cài đặt cho phép chọn quy chuẩn (QCVN / WHO), ngưỡng cảnh báo, và nhóm sức khỏe cá nhân.

### Bước 8: Trang Quản trị (Dành cho Admin)
- Đăng nhập bằng tài khoản `admin@appair.vn`.
- Quản lý 6 phân hệ: Danh sách tài khoản người dùng, Quản lý bản tin, Đánh giá từ người dùng, Lịch sử tra cứu bản đồ, Cấu hình gửi thông báo, và Trạng thái hệ thống.

---

## 4. Các thông số kỹ thuật cốt lõi
- Khu vực giám sát: Thành phố Thủ Dầu Một, Bình Dương (Tọa độ: 10.9807, 106.6753).
- Dữ liệu thu thập: Hơn 11.600 bản ghi theo giờ từ Open-Meteo Air Quality API.
- Cấu trúc mô hình AI: 1D-CNN + LSTM (45.432 tham số), đầu vào 24 giờ của 6 biến, đầu ra 24 giờ dự báo PM2.5.
- Tiêu chuẩn phân cấp: QCVN 05:2023/BTNMT (Tốt: 0-15 µg/m³, Trung bình: 15.1-25 µg/m³, Kém: 25.1-50 µg/m³, Xấu: >50 µg/m³).
- Cơ sở dữ liệu: Hệ thống lưu trữ đồng thời trên PostgreSQL Local và Supabase Cloud.
