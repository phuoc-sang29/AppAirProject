# KỊCH BẢN THUYẾT TRÌNH APPAIR (LỜI NÓI ĐỌC THEO)

Thời lượng: khoảng 10 phút. Mỗi phần gồm ba ý: **làm gì**, **vì sao thiết kế như vậy**, **kết quả đạt được**. Đọc nguyên văn phần trong dấu ngoặc kép.

---

## 1. MỞ ĐẦU (30 giây)

"Em xin chào thầy cô. Đề tài của em là AppAir, ứng dụng giám sát và dự báo bụi mịn PM2.5 tại Thành phố Thủ Dầu Một bằng mô hình học sâu.

Vấn đề em muốn giải quyết là người dân thường chỉ biết không khí hôm nay ra sao, mà không biết vài giờ tới sẽ thế nào, và mức ô nhiễm đó nguy hiểm với riêng mình hay không. AppAir trả lời hai câu hỏi đó: dự báo 24 giờ tới và cảnh báo theo từng nhóm sức khỏe."

---

## 2. KIẾN TRÚC TỔNG QUAN (1 phút)

"Hệ thống em chia thành 4 tầng, dữ liệu đi theo một chiều.

Tầng một là Data Pipeline bằng Python, tự động lấy dữ liệu từ Open-Meteo mỗi giờ. Tầng hai là cơ sở dữ liệu PostgreSQL. Tầng ba gồm AI Service bằng FastAPI và Backend bằng Node.js. Tầng bốn là ứng dụng Flutter.

Em tách thành nhiều tầng vì mỗi phần dùng ngôn ngữ phù hợp nhất với việc của nó: Python mạnh về dữ liệu và AI, Node.js nhẹ cho API, Flutter cho phép một mã nguồn chạy được cả web và Android. Tách riêng cũng giúp lỗi ở một tầng không làm sập cả hệ thống.

Kết quả là cả ba dịch vụ khởi động bằng một lệnh, và ứng dụng chạy được trên cả trình duyệt lẫn điện thoại."

---

## 3. THU THẬP DỮ LIỆU (1 phút) - thư mục `data_pipeline/`

"File `cron.py` chạy liên tục, cứ 60 phút gọi `collect.py` một lần. File này gọi Open-Meteo cho tọa độ trung tâm Thủ Dầu Một, lấy 6 chỉ số là PM10, PM2.5, CO, NO2, SO2 và O3 theo từng giờ. File `db.py` sau đó ghi vào database.

Em chọn Open-Meteo vì miễn phí, không cần khóa, và có dữ liệu chất lượng không khí theo giờ. Em ghi bằng lệnh UPSERT, nghĩa là nếu giờ đó đã có thì cập nhật, chưa có thì thêm, nên chạy lại bao nhiêu lần cũng không bị trùng.

Kết quả là hiện database có 11.616 bản ghi theo giờ, đủ để huấn luyện mô hình, và dữ liệu luôn được cập nhật mà không cần thao tác tay."

---

## 4. CƠ SỞ DỮ LIỆU (1 phút)

"Em dùng hai database cùng cấu trúc: PostgreSQL trên máy và Supabase trên đám mây. Mỗi lần thu thập, dữ liệu được ghi vào cả hai.

Em thiết kế như vậy vì PostgreSQL local rất nhanh và vẫn chạy khi mất mạng, còn Supabase giúp sao lưu và truy cập từ xa. Hàm đồng bộ trong AI Service giữ cho hai bên khớp nhau.

Database có 6 bảng: `air_quality` lưu số liệu không khí, `users` lưu tài khoản và nhóm sức khỏe, `notifications` lưu thông báo, `news_articles` lưu bản tin, `ratings` lưu đánh giá, và `map_searches` lưu lịch sử tìm trên bản đồ.

Kết quả là dữ liệu an toàn ở hai nơi, hai database luôn có cùng số bản ghi, và quản trị viên xem được cả hành vi người dùng."

---

## 5. MÔ HÌNH DỰ BÁO (2 phút) - thư mục `ai_service/`

"Đây là phần cốt lõi. Mô hình nhận vào 24 giờ gần nhất của 6 chỉ số và trả ra 24 giá trị PM2.5 cho 24 giờ tiếp theo.

Em chọn kết hợp CNN một chiều với LSTM vì chuỗi bụi mịn có hai kiểu quy luật. Quy luật ngắn hạn, ví dụ bụi tăng liên tục vài giờ, thì CNN bắt tốt. Quy luật dài hơn, như chu kỳ ngày và đêm, thì LSTM nhớ tốt. Kết hợp hai lớp này bổ trợ cho nhau.

Cấu trúc gồm hai lớp Conv1D, hai lớp LSTM, hai lớp Dropout 0.2 để chống học vẹt, và một lớp Dense 24 đầu ra. Em dự báo một lần cả 24 giờ thay vì lặp từng bước, để sai số không cộng dồn qua từng lần dự đoán. Dữ liệu được chuẩn hóa về khoảng 0 đến 1, chia 80% để huấn luyện và 20% để kiểm tra.

Kết quả trên tập kiểm tra, sai số RMSE là 16,25 và MAE là 10,39 microgram trên mét khối. Mô hình đủ để nhận ra xu hướng tăng giảm và mức cảnh báo, và các chỉ số này hiển thị trực tiếp trên màn hình Dự báo."

---

## 6. PHÂN MỨC VÀ CẢNH BÁO SỨC KHỎE (1 phút)

"Em phân mức theo quy chuẩn Việt Nam QCVN 05:2023: Tốt đến 15, Trung bình đến 25, Kém đến 50, và Xấu trên 50.

Em dùng quy chuẩn trong nước vì ứng dụng phục vụ người dân Việt Nam. Ngoài ra em chia người dùng thành 4 nhóm: người bình thường, người bệnh hô hấp và hen suyễn, trẻ em và người cao tuổi, và người vận động ngoài trời. Em gộp nhóm hen suyễn vào nhóm hô hấp vì hai nhóm này gần như trùng nhau.

Cùng một mức PM2.5 nhưng lời khuyên khác nhau. Ví dụ người chạy bộ được khuyên đổi sang tập trong nhà, còn người bệnh hô hấp được nhắc mang thuốc dự phòng. Kết quả là cảnh báo sát với từng người, thay vì một thông báo chung cho tất cả."

---

## 7. THÔNG BÁO (1 phút)

"Thông báo được gửi theo ba buổi: sáng lúc 7 giờ, chiều lúc 17 giờ và tối lúc 21 giờ, cộng thêm cảnh báo khi PM2.5 vượt ngưỡng người dùng đặt.

Em chọn ba buổi vì đó là ba thời điểm người dân ra quyết định: trước khi đi làm, lúc tan tầm, và trước khi nghỉ. Em giới hạn số thông báo mỗi ngày để không làm phiền, và người dùng tự chỉnh ngưỡng trong phần Cài đặt.

Thẻ thông báo hiển thị biên độ PM2.5 của ngày, mức không khí và lời khuyên, bấm vào để xem chi tiết. Kết quả là người dùng nắm tình hình chỉ trong một cái nhìn mà không bị ngập trong thông báo."

---

## 8. BẢN ĐỒ (1,5 phút)

"Bản đồ cho xem chất lượng không khí theo từng phường của Thủ Dầu Một, với 10 trạm.

Một điểm em muốn nói thật là em không có trạm đo riêng ở từng phường. Dữ liệu gốc của em là một điểm trung tâm. Vì vậy em lấy giá trị đó, nhân với hệ số về giao thông, công nghiệp và cây xanh của từng phường, rồi dùng phép nội suy theo nghịch đảo khoảng cách để tính cho một điểm bất kỳ người dùng chạm vào. Ứng dụng ghi rõ đây là giá trị nội suy.

Em chỉ tính trong bán kính 20 km quanh Thủ Dầu Một, vì ngoài vùng đó database không có dữ liệu. Nếu người dùng chạm ra ngoài, ứng dụng từ chối thay vì đưa ra con số sai.

Em dùng bản đồ nền của Esri vì miễn phí và truy cập ổn định. Em tự xây từ điển phường và đường của Thủ Dầu Một để tìm kiếm tức thì, và dùng thêm dịch vụ tìm địa chỉ miễn phí của Esri cho các địa chỉ khác. Kết quả là gõ tên đường như Huỳnh Văn Lũy là ra ngay vị trí cùng 6 chỉ số."

---

## 9. CÁC CHỨC NĂNG CÒN LẠI (1 phút)

"Trang chủ hiển thị PM2.5, mức AQI và 6 chất ô nhiễm, nền bầu trời đổi theo buổi trong ngày. Trang Dự báo có biểu đồ 24 giờ. Trang Bản tin có bài viết do quản trị viên soạn, có AI gợi ý nội dung dựa trên số liệu thật. Chat AI dùng Gemini để trả lời câu hỏi về không khí và sức khỏe, em dùng 4 khóa xoay vòng để không bị hết hạn mức.

Trang Quản trị có 6 mục: tài khoản, bản tin, đánh giá, hành vi, thông báo và hệ thống. Em làm phần này để người vận hành quản lý được toàn bộ hệ thống ngay trong ứng dụng."

---

## 10. TIẾN ĐỘ VÀ KẾT LUẬN (1 phút)

"Tóm lại, AppAir đã đáp ứng ba mục tiêu em đặt ra. Một là dữ liệu thật, tự cập nhật mỗi giờ. Hai là dự báo 24 giờ bằng mô hình học sâu với sai số được đo rõ ràng. Ba là cảnh báo cá nhân hóa theo nhóm sức khỏe, có bản đồ trực quan.

Những phần đã chạy được gồm thu thập dữ liệu, mô hình, backend, ứng dụng web và Android, thông báo và hai database đồng bộ. Phần còn lại là triển khai lên máy chủ để hệ thống chạy liên tục khi em tắt máy, và đo thêm bằng dữ liệu từ trạm quan trắc thật để cải thiện bản đồ.

Em xin hết phần trình bày, mong thầy cô góp ý."

---

## CÂU HỎI THƯỜNG GẶP

**Dữ liệu có thật không?**
"Dạ có. Lấy từ Open-Meteo mỗi giờ, hiện có 11.616 bản ghi cho tọa độ trung tâm Thủ Dầu Một."

**Vì sao chọn 1D-CNN kết hợp LSTM?**
"Dạ CNN bắt mẫu ngắn hạn, LSTM nhớ xu hướng dài hạn, dùng chung cho kết quả tốt hơn dùng riêng từng loại."

**RMSE 16 có tốt không?**
"Dạ em dự báo 24 giờ liên tiếp nên sai số lớn dần ở các giờ xa. Mô hình đủ để nhận biết xu hướng và mức cảnh báo, và em hiển thị số liệu này công khai trên ứng dụng."

**Vì sao dùng hai database?**
"Dạ local nhanh và chạy được khi mất mạng, Supabase để sao lưu và dùng trên đám mây."

**Điểm trên bản đồ có phải đo thật không?**
"Dạ không. Đó là giá trị nội suy từ dữ liệu khu vực và hệ số đặc trưng từng phường, ứng dụng có ghi rõ. Hướng phát triển là bổ sung trạm đo thật."

**Vì sao chạm ngoài 20 km không hiện số?**
"Dạ dữ liệu của em chỉ có cho Thủ Dầu Một, nên em từ chối để không đưa số liệu sai."

**Bảo mật thế nào?**
"Dạ mật khẩu được mã hóa, đăng nhập bằng token có thời hạn, và tệp cấu hình chứa khóa không được đưa lên GitHub."

**Tắt máy thì hệ thống có chạy không?**
"Dạ hiện chạy trên máy cá nhân nên sẽ dừng. Em dự kiến triển khai lên máy chủ đám mây để chạy liên tục."
