import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/toast_service.dart';
import '../../services/local_notification_service.dart';
import 'tracking_screen.dart';
import 'location_picker_screen.dart';
import '../role_selection_screen.dart';
import '../../services/auth_service.dart';
import '../../services/dialect_normalizer.dart';
import 'sos_history_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
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
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('victim_phone');
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

  void _showSosForm() {
    if (_hasActiveCase) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _SosFormSheet(
            onSubmit: (location, text) {
              Navigator.pop(context); // close modal
              _handleSendActual(location, text);
            },
          ),
        );
      },
    );
  }

  Future<void> _handleSendActual(
      LatLng location, String text) async {
    HapticFeedback.heavyImpact(); // Rung mạnh khi gửi SOS
    if (_isSending) return;
    setState(() => _isSending = true);

    final sosText = text.isNotEmpty ? text : 'SOS - Cần cứu hộ khẩn cấp';
    final fcmToken = await FirebaseMessaging.instance.getToken();

    final result = await ApiService.sendSos(
      text: sosText,
      lat: location.latitude,
      lon: location.longitude,
      phone: _phone,
      fcmToken: fcmToken,
    );

    if (!mounted) return;

    if (result != null && result['error'] != 'ACTIVE_CASE_EXISTS') {
      // Hiển thị System Notification thật (giống Messenger/MBBank)
      LocalNotificationService.showSosSuccess(
        caseId: result['caseId']?.toString() ?? '',
        summary: result['summary'] as String?,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(
            caseId: result['caseId'],
            victimLat: location.latitude,
            victimLon: location.longitude,
          ),
        ),
      ).then((_) => _checkActiveCase());

      setState(() {
        _isSending = false;
      });
    } else {
      setState(() => _isSending = false);
      _checkActiveCase();
      ToastService.show(
        context: context,
        type: ToastType.warning,
        message: 'Tín hiệu đã được gửi hoặc bạn đang có ca đang xử lý.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Cho phép body kéo dài xuống dưới BottomAppBar để notch hiển thị background gradient
      backgroundColor: const Color(0xFFF7F9FC), // Fallback
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFE8ECEF), // Màu xám nhạt tạo độ sâu
            ],
            stops: [0.3, 1.0], // Để nửa trên trắng, nửa dưới bắt đầu chuyển xám
          ),
        ),
        child: SafeArea(
          bottom: false, // Để tránh chừa viền trắng dưới cùng trên iOS/Android
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTitle(),
                          SizedBox(height: 64.h),
                          _buildGiantSosButton(),
                          SizedBox(height: 100.h), // Khoảng trống cho BottomBar
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_hasActiveCase)
                Positioned(
                  left: 16.w,
                  bottom: 80.h, // Đẩy lên để tránh bị che bởi BottomBar
                  child: _buildActiveCaseBanner(),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: const _LowerDockedFabLocation(),
      floatingActionButton: _buildSosFab(),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.alertRed),
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
    // A slightly lighter red for the main button
    final lighterRed = const Color(0xFFEF5350); 
    // Outer halo ring color
    final outerRingColor = lighterRed.withValues(alpha: 0.25);
    
    final innerColor = _hasActiveCase ? Colors.grey : lighterRed;
    final ringColor = _hasActiveCase ? Colors.grey.shade300 : outerRingColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.vibrate(); // Rung khi nhấn mở form
        if (!_isSending) _showSosForm();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vòng ngoài: Có animation toả ra
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Transform.scale(
              scale: _hasActiveCase ? 1.0 : _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor, // Vòng halo ngoài cùng
                boxShadow: [
                  if (!_hasActiveCase)
                    BoxShadow(
                      color: lighterRed.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                ],
              ),
            ),
          ),
          
          // Vòng trong: Tĩnh, không thay đổi kích thước
          Container(
            width: 220.w,
            height: 220.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: innerColor, // Nút chính bên trong
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
                      fontSize: 64.sp, // Giảm một chút cho cân đối với nút
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _hasActiveCase ? 'ĐÃ GỬI' : 'NHẤN ĐỂ TẠO SOS',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCaseBanner() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.textPrimary, // Dark, sleek contrast
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red recording/live dot
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.alertRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Đang theo dõi ca SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosFab() {
    return Container(
      width: 68.w, // To hơn một xíu để nhìn rõ hiệu ứng lõm
      height: 68.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.alertRed, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.alertRed.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          HapticFeedback.vibrate();
          if (!_hasActiveCase && !_isSending) _showSosForm();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: const Text(
          'SOS',
          style: TextStyle(
            color: AppColors.alertRed,
            fontWeight: FontWeight.w900, // Đậm hơn
            fontSize: 19,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 14.0, // Tăng notch để phần lõm to hơn
      color: Colors.white,
      surfaceTintColor: Colors.white, // Loại bỏ ám màu Material 3
      elevation: 8, // Giảm elevation để tránh lỗi vạch đen trên một số máy Android
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            // Trái
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(
                    icon: Icons.map_outlined,
                    label: 'Bản đồ',
                    isActive: true,
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
                        ToastService.show(
                          context: context,
                          type: ToastType.warning,
                          message: 'Bạn chưa có ca SOS nào.',
                        );
                      }
                    },
                  ),
                  _buildBottomNavItem(
                    icon: LucideIcons.history,
                    label: 'Lịch sử',
                    isActive: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SosHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Khoảng trống cho nút SOS ở giữa
            SizedBox(width: 64.w), 
            // Phải
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(
                    icon: Icons.notifications_none,
                    label: 'Thông báo',
                    isActive: false,
                    onTap: () {
                      ToastService.show(
                        context: context,
                        type: ToastType.info,
                        message: 'Tính năng Thông báo đang phát triển',
                      );
                    },
                  ),
                  _buildBottomNavItem(
                    icon: Icons.person_outline,
                    label: 'Cá nhân',
                    isActive: false,
                    onTap: _showVictimProfile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.alertRed : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.alertRed : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVictimProfile() async {
    // Luôn dùng _phone (đã load từ victim_phone) thay vì AuthService.currentUser
    // vì Firebase Auth chỉ có 1 session và có thể bị ghi đè bởi TNV login
    String phoneDisplay = _phone.isNotEmpty ? _phone : 'Chưa xác thực';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.alertRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.alertRed.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.alertRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Thông tin cá nhân',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: 24),

            // Phone info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số điện thoại đã xác thực',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phoneDisplay,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx); // Đóng bottom sheet
                  await AuthService.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('victim_phone');
                  if (!mounted) return;
                  // Quay về màn hình nhập SĐT để xác thực OTP lại
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(
                  'Đăng xuất',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SosFormSheet extends StatefulWidget {
  final Function(LatLng location, String text) onSubmit;

  const _SosFormSheet({required this.onSubmit});

  @override
  State<_SosFormSheet> createState() => _SosFormSheetState();
}

class _SosFormSheetState extends State<_SosFormSheet> {
  LatLng? _currentLocation;
  bool _isFetchingLocation = false;
  final _textController = TextEditingController();

  // Speech to text
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _initSpeech();
    DialectNormalizer.load(); // Load từ điển phương ngữ miền Trung (chỉ chạy 1 lần)
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        print('[SpeechError] Lỗi nhận diện giọng nói: ${error.errorMsg}');
        if (mounted) {
          setState(() => _isListening = false);
          ToastService.show(
            context: context,
            type: ToastType.error,
            message: 'Chi tiết lỗi: ${error.errorMsg}',
          );
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_speechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                // Chuẩn hóa phương ngữ miền Trung → tiếng Việt phổ thông (real-time)
                _textController.text = DialectNormalizer.normalize(result.recognizedWords);
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              });
            }
          },
          localeId: 'vi_VN',
          listenMode: ListenMode.dictation,
        );
      } else {
        ToastService.show(
          context: context,
          type: ToastType.error,
          message: 'Không thể khởi tạo nhận dạng giọng nói.',
        );
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Thử lấy vị trí cached trước (nhanh, không timeout)
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          });
        }

        // Sau đó lấy vị trí chính xác hơn (có thể chậm hơn)  
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
          }
        } catch (e) {
          // Nếu getCurrentPosition timeout, vẫn có lastKnown
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thông tin khẩn cấp',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: 24),
            Text('Vị trí *', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isFetchingLocation
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text('Đang lấy vị trí...', style: AppTypography.bodyMedium),
                            ],
                          )
                        : _currentLocation != null
                            ? Text(
                                '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text('Chưa có vị trí',
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.danger)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final LatLng? picked = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerScreen(
                            initialLat: _currentLocation?.latitude,
                            initialLon: _currentLocation?.longitude,
                          ),
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _currentLocation = picked;
                        });
                      }
                    },
                    child: const Text('Chọn thủ công'),
                  )
                ],
              ),
            ),
            if (_currentLocation != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Map nhỏ chỉ xem, muốn đổi thì bấm "Chọn thủ công"
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.alertRed,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Ghi chú', style: AppTypography.labelMedium),
            const SizedBox(height: 8),
            // Quick-select Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickTag('Có người bị thương'),
                _buildQuickTag('Có trẻ em'),
                _buildQuickTag('Có người già'),
                _buildQuickTag('Nước ngập nóc'),
                _buildQuickTag('Cần xuồng cứu hộ'),
                _buildQuickTag('Nguy cơ điện giật'),
                _buildQuickTag('Thiếu lương thực'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Mô tả tình trạng của bạn...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? AppColors.alertRed : AppColors.primary,
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.alertRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Đang nghe...', style: AppTypography.bodySmall.copyWith(color: AppColors.alertRed)),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.alertRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  if (_currentLocation == null) {
                    ToastService.show(
                      context: context,
                      type: ToastType.error,
                      message: 'Vui lòng cung cấp vị trí của bạn.',
                    );
                    return;
                  }
                  widget.onSubmit(
                    _currentLocation!,
                    _textController.text,
                  );
                },
                child: Text('GỬI YÊU CẦU CỨU TRỢ',
                    style: AppTypography.labelLarge.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTag(String text) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final current = _textController.text;
        if (current.contains(text)) return; // Tránh trùng
        setState(() {
          if (current.isEmpty) {
            _textController.text = text;
          } else {
            _textController.text = '$current, $text';
          }
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Custom location để đẩy nút SOS chìm sâu hơn vào trong BottomAppBar
class _LowerDockedFabLocation extends FloatingActionButtonLocation {
  const _LowerDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Lấy X chuẩn ở chính giữa
    final double fabX = (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
    
    // Lấy Y chuẩn của centerDocked
    final double fabY = scaffoldGeometry.contentBottom - (scaffoldGeometry.floatingActionButtonSize.height / 2.0);
    
    // Đẩy Y xuống thêm 15 pixels để nút chìm sâu xuống lõm
    return Offset(fabX, fabY + 15.0);
  }
}
