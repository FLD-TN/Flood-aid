import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Điều khoản & Chính sách',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Giới thiệu chung'),
            _buildParagraph(
                '• Ứng dụng FloodAid là nền tảng công nghệ số hỗ trợ cứu hộ khẩn cấp trong mùa bão lũ, kết nối trực tiếp giữa Nạn nhân cần ứng cứu và Mạng lưới Tình nguyện viên/Lực lượng cứu hộ.\n'
                '• FloodAid được phát triển nhằm mục đích cung cấp thông tin vị trí chính xác, tình trạng khẩn cấp và nhu cầu thiết yếu của người dân vùng lũ đến các đội cứu trợ một cách nhanh nhất, hướng đến việc tối ưu hóa và phân bổ nguồn lực cứu hộ hiệu quả.\n'
                '• Ứng dụng phục vụ hoàn toàn cho mục đích cộng đồng, nhân đạo và không mang tính thương mại.'),
            
            _buildSectionTitle('2. Thu thập thông tin cá nhân'),
            _buildSubTitle('2.1. Các loại thông tin thu thập'),
            _buildParagraph(
                '• Thông tin định danh cơ bản: Số điện thoại của bạn (dùng để xác thực tài khoản và làm kênh liên lạc khẩn cấp).\n'
                '• Thông tin vị trí (GPS): Tọa độ chính xác của bạn để phục vụ việc định vị ca SOS và điều hướng cứu hộ.\n'
                '• Thông tin dữ liệu sự cố: Hình ảnh, bản ghi âm, phân loại mức độ khẩn cấp (y tế, lương thực, sơ tán...) do bạn cung cấp khi tạo ca SOS.\n'
                '• Thông tin từ thiết bị: Kiểu máy, hệ điều hành nhằm tối ưu hóa trải nghiệm ứng dụng.'),
            _buildSubTitle('2.2. Mục đích thu thập dữ liệu'),
            _buildParagraph(
                '• Định vị và điều phối: Để lực lượng cứu hộ và tình nguyện viên có thể tìm thấy bạn hoặc vị trí cần hỗ trợ trong thời gian ngắn nhất.\n'
                '• Xác thực người dùng: Ngăn chặn các hành vi tạo ca SOS giả mạo, spam hệ thống làm phân tán nguồn lực cứu hộ.\n'
                '• Liên lạc khẩn cấp: Giúp tình nguyện viên có thể gọi điện trực tiếp cho nạn nhân để nắm bắt tình hình trước khi tiếp cận.\n'
                '• Thống kê và báo cáo: Tạo bản đồ nhiệt vùng ngập lụt, thống kê nhu yếu phẩm (dữ liệu sẽ được ẩn danh) để hỗ trợ công tác dự báo và điều phối quy mô lớn.'),

            _buildSectionTitle('3. Bảo vệ quyền riêng tư và dữ liệu'),
            _buildParagraph(
                '• Dữ liệu vị trí và số điện thoại của bạn chỉ được chia sẻ cho các Tình nguyện viên/Lực lượng cứu hộ ĐÃ ĐƯỢC XÁC THỰC trên hệ thống khi bạn chủ động gửi yêu cầu SOS.\n'
                '• FloodAid cam kết không sử dụng dữ liệu người dùng cho mục đích quảng cáo, thương mại, và không chia sẻ cho bên thứ ba không liên quan đến công tác cứu hộ.\n'
                '• Bạn có quyền yêu cầu xóa tài khoản và dữ liệu cá nhân khỏi hệ thống sau khi công tác cứu hộ hoàn tất.'),

            _buildSectionTitle('4. Quyền truy cập thiết bị'),
            _buildParagraph(
                'Khi sử dụng FloodAid, người dùng đồng ý cấp các quyền sau:\n'
                '(1) Truy cập Vị trí (GPS): Bắt buộc để xác định tọa độ SOS và điều hướng tình nguyện viên.\n'
                '(2) Truy cập Internet: Để đồng bộ dữ liệu thời gian thực.\n'
                '(3) Truy cập Camera/Micro: Hỗ trợ chụp ảnh hiện trường và ghi âm mô tả tình trạng khẩn cấp.\n'
                '(4) Quyền nhận Thông báo (Push Notification): Để cập nhật trạng thái cứu hộ, cảnh báo thời tiết khẩn cấp.'),

            _buildSectionTitle('5. Quyền và trách nhiệm của người dùng'),
            _buildParagraph(
                '• Đối với Nạn nhân: Đảm bảo cung cấp thông tin tình trạng, vị trí chính xác. Tuyệt đối không tạo tín hiệu SOS giả mạo, hành vi này có thể làm gián đoạn việc cứu mạng người khác và sẽ bị cấm sử dụng hệ thống.\n'
                '• Đối với Tình nguyện viên: Tuân thủ quy định an toàn khi tham gia cứu trợ, bảo mật thông tin cá nhân của nạn nhân, không sử dụng dữ liệu thu thập được ngoài mục đích cứu hộ.\n'
                '• Hợp tác với đội ngũ phát triển: Báo cáo lỗi kỹ thuật (nếu có) để chúng tôi hoàn thiện ứng dụng phục vụ cộng đồng tốt hơn.'),
            
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 24.h, bottom: 12.h),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildSubTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          color: Colors.grey[800],
          height: 1.6,
        ),
      ),
    );
  }
}
