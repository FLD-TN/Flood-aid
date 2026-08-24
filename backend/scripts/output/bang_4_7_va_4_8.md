

*Bảng 4.7 – Độ trễ phân loại và tỉ lệ sử dụng của hai nhánh (N = 40 tin nhắn)*

| Chỉ số | Nhánh dò từ khóa | Nhánh mô hình ngôn ngữ lớn |
|---|---|---|
| Độ trễ trung bình | 0.032 ms | 1230 ms |
| Độ trễ phân vị 95 (P95) | 0.040 ms | 1923 ms |
| Độ trễ lớn nhất | 0.057 ms | 2345 ms |
| Tỉ lệ trả về kết quả thành công (mạng ổn định) | 100% | 95.0% |
| Tỉ lệ trả về kết quả thành công (mất kết nối dịch vụ) | 100% | 0% |
| Tỉ lệ được chọn làm kết quả cuối, ngưỡng 3 s (`ai_source`) | 5.0% | 95.0% |

*Bảng 4.8 – Phân tích độ nhạy của ngưỡng thời gian chờ (N = 40 tin nhắn)*

| Ngưỡng chờ | Tỉ lệ ca dùng được kết quả mô hình ngôn ngữ | Tỉ lệ ca phải dùng nhánh dò từ khóa | Thời gian chờ tối đa mà nạn nhân phải chịu |
|---|---|---|---|
| 1 000 ms | 15.0 % | 85.0 % | 1.0 s |
| 1 500 ms | 85.0 % | 15.0 % | 1.5 s |
| 2 000 ms | 92.5 % | 7.5 % | 2.0 s |
| **3 000 ms (đang dùng)** | 95.0 % | 5.0 % | 3.0 s |
| 5 000 ms | 95.0 % | 5.0 % | 5.0 s |
| 7 000 ms | 95.0 % | 5.0 % | 7.0 s |

**Kịch bản mất kết nối dịch vụ:** 40/40 tin nhắn vẫn được phân loại bằng nhánh dò từ khóa (100% — luồng tạo ca không bị nghẽn).

**Kiểm chứng sàn an toàn:** với câu "Bác tôi bị đuối nước nhưng đã vớt lên rồi, giờ cần người đưa đi viện" — nhánh dò từ khóa gán mức **5**, kết quả cuối cùng sau hợp nhất là mức **5** (nguồn: gemini). Quy tắc Math.max hoạt động đúng: hệ thống không hạ mức xuống dưới ngưỡng mà từ khóa đã cảnh báo.
