import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/phone_auth_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top illustration - hiện full màn hình phía trên (bỏ qua SafeArea)
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.35, // Chiếm 35% màn hình
            child: Image.asset(
              'assets/images/hero_illustration.png',
              fit: BoxFit.cover, // Cắt cúp để lấp đầy khung hình
              errorBuilder: (context, error, stackTrace) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Phần chữ và nút bọc trong Padding và SafeArea để không dính viền dưới
          Expanded(
            child: SafeArea(
              top: false, // Top đã bị ảnh lấp nên không cần SafeArea
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'Chọn vai trò',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtitle
                    Text(
                      'Chọn Cứu hộ nếu bạn cần được giúp đỡ\nhoặc Tình nguyện viên nếu bạn muốn giúp',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernCard(
                            role: 'Cứu hộ',
                            imagePath: 'assets/images/victim_modern.png',
                            backgroundColor: const Color(0xFFD3EBEB), // Light teal
                            borderColor: const Color(0xFF008989), // Dark teal border
                            isSelected: selectedRole == 'victim',
                            onTap: () => setState(() => selectedRole = 'victim'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernCard(
                            role: 'Tình nguyện viên',
                            imagePath: 'assets/images/volunteer_modern.png',
                            backgroundColor: const Color(0xFFFFE6D5), // Light orange
                            borderColor: const Color(0xFFF19D60), // Dark orange border
                            isSelected: selectedRole == 'volunteer',
                            onTap: () => setState(() => selectedRole = 'volunteer'),
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Nút Tiếp tục (Đen nguyên khối)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: selectedRole == null ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhoneAuthScreen(role: selectedRole!),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Tiếp tục',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedRole == null ? Colors.grey[500] : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required String role,
    required String imagePath,
    required Color backgroundColor,
    required Color borderColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? borderColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Avatar Image
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2), // Fallback
              ),
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              role,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
