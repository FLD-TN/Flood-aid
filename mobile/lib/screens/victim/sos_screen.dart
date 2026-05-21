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

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isSending = false;
  String _phone = '0900000000';

  // _hasActiveCase để kiểm tra xem nạn nhân có ca đang chờ/xử lý không
  bool _hasActiveCase = false;
  String? _activeCaseId;
  double? _activeLat;
  double? _activeLon;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _loadPhone().then((_) => _checkActiveCase());
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Lắc từ -10 đến 10 pixels
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_phone');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _phone = saved);
    }
  }

  Future<void> _checkActiveCase() async {
    if (_phone.isEmpty) return;
    
    final result = await ApiService.checkActiveCaseByPhone(_phone);
    if (result != null && result['hasActive'] == true) {
      setState(() {
        _hasActiveCase = true;
        _activeCaseId = result['caseId']?.toString();
        _activeLat = (result['lat'] as num?)?.toDouble();
        _activeLon = (result['lon'] as num?)?.toDouble();
      });
      _pulseCtrl.stop(); // Ngừng đập nếu có ca
    } else {
      setState(() {
        _hasActiveCase = false;
        _activeCaseId = null;
      });
      _pulseCtrl.repeat(reverse: true);
    }
  }

  Future<void> _handleSend() async {
    if (_hasActiveCase) {
      _shakeCtrl.forward(from: 0);
      return;
    }

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
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(
            caseId: result['caseId'],
            victimLat: currentLat,
            victimLon: currentLon,
          ),
        ),
      ).then((_) => _checkActiveCase());

      setState(() {
        _isSending = false;
        _textController.clear();
      });
    } else {
      setState(() => _isSending = false);
      _checkActiveCase();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tín hiệu đã được gửi hoặc đang có ca xử lý.'),
        ),
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.menu, color: AppColors.alertRed),
          ),
          Text(
            'Cứu Hộ Miền Trung',
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.alertRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(
            Icons.map_outlined,
            color: Colors.transparent,
          ), // Placeholder for balance
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
    final bgColor = _hasActiveCase ? Colors.grey : AppColors.alertRed;

    return GestureDetector(
      onTap: _isSending ? null : _handleSend,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: _hasActiveCase ? 1.0 : _pulseAnim.value,
          child: child,
        ),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: [
              if (!_hasActiveCase)
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
                  _hasActiveCase ? 'ĐÃ GỬI' : 'NHẤN ĐỂ GỬI',
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
              enabled: !_hasActiveCase,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText:
                    'Nhập tình trạng hoặc bấm mic để nói...\n(VD: Nước ngập nóc, có trẻ em)',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
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
              color: _hasActiveCase ? Colors.grey : AppColors.primary,
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
      height: 80, // Tăng nhẹ để chứa thông báo
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: const Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  if (_activeCaseId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackingScreen(
                          caseId: _activeCaseId!,
                          victimLat: _activeLat,
                          victimLon: _activeLon,
                        ),
                      ),
                    ).then((_) => _checkActiveCase());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bạn chưa có ca SOS nào.')),
                    );
                  }
                },
                child: _navItem(Icons.map_outlined, 'Bản đồ', false),
              ),
              _navItemSos(),
              _navItem(Icons.person_outline, 'Cá nhân', false),
            ],
          ),

          if (_hasActiveCase)
            Positioned(
              left: 10,
              top: -30,
              child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.alertRed.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Bạn đang có 1 ca SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Container(
      width: 60,
      color: Colors.transparent, // expand touch area
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.alertRed : AppColors.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isActive ? AppColors.alertRed : AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
