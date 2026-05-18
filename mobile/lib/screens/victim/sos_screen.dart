import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'tracking_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isSending = false;
  String _phone = '0900000000';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadPhone();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_phone');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _phone = saved);
    }
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final sosText = _textController.text.isNotEmpty
        ? _textController.text
        : 'SOS - Cần cứu hộ khẩn cấp';

    double currentLat = 16.0544;
    double currentLon = 108.2022;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          currentLat = position.latitude;
          currentLon = position.longitude;
        }
      }
    } catch (e) {
      // Ignore and fallback
    }

    final result = await ApiService.sendSos(
      text: sosText,
      lat: currentLat,
      lon: currentLon,
      phone: _phone,
    );

    if (!mounted) return;

    if (result != null && result['error'] != 'ACTIVE_CASE_EXISTS') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(
            caseId: result['caseId'],
            victimLat: currentLat,
            victimLon: currentLon,
          ),
        ),
      );
    } else {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tín hiệu đã được gửi hoặc đang có ca xử lý.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTitle(),
                    _buildGiantSosButton(),
                    _buildInputArea(),
                    _buildLocationCard(),
                  ],
                ),
              ),
            ),
            _buildMockBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.menu, color: AppColors.alertRed),
          Text(
            'Cứu Hộ Miền Trung',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(Icons.map_outlined, color: AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Chào bạn, giữ bình tĩnh',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bạn đang cần trợ giúp?',
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGiantSosButton() {
    return GestureDetector(
      onTap: _isSending ? null : _handleSend,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        ),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.alertRed,
            boxShadow: [
              BoxShadow(
                color: AppColors.alertRed.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSending)
                const CircularProgressIndicator(color: Colors.white)
              else ...[
                Text(
                  'SOS',
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                    fontSize: 72,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NHẤN ĐỂ GỬI',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 2,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Nhập tình trạng hoặc bấm mic để nói...\n(VD: Nước ngập nóc, có trẻ em)',
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.mic, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VỊ TRÍ HIỆN TẠI',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Vị trí GPS đang lấy...',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.alertRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sửa thủ công',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.alertRed,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBottomNav() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: const Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.map_outlined, 'Bản đồ', false),
          _navItem(Icons.list_alt_rounded, 'Yêu cầu', false),
          _navItemSos(),
          _navItem(Icons.assignment_outlined, 'Nhiệm vụ', false),
          _navItem(Icons.person_outline, 'Cá nhân', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: isActive ? AppColors.alertRed : AppColors.textMuted),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? AppColors.alertRed : AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _navItemSos() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.alertRed,
            borderRadius: BorderRadius.circular(8), // Hexagon-like proxy
          ),
          child: const Text(
            'SOS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
