import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

// --- STATUS ENUM ---
enum SosStatus { pending, responding, completed, cancelled }

SosStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return SosStatus.pending;
    case 'responding':
    case 'on_scene':
      return SosStatus.responding;
    case 'resolved':
      return SosStatus.completed;
    default:
      return SosStatus.pending;
  }
}

// --- DATA MODEL ---
class SosHistoryItem {
  final String id;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String description;
  final String summary;
  final List<String> tags;
  final int urgencyLevel;
  final SosStatus status;
  final String? volunteerName;
  final double? lat;
  final double? lon;

  SosHistoryItem({
    required this.id,
    required this.createdAt,
    this.resolvedAt,
    required this.description,
    required this.summary,
    required this.tags,
    required this.urgencyLevel,
    required this.status,
    this.volunteerName,
    this.lat,
    this.lon,
  });

  factory SosHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return SosHistoryItem(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
      description: json['description'] ?? json['text_raw'] ?? '',
      summary: json['summary'] ?? json['summary_1line'] ?? '',
      tags: parsedTags,
      urgencyLevel: json['urgency_level'] ?? 3,
      status: _parseStatus(json['status']),
      volunteerName: json['volunteer_name'],
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

// Tag display mapping
const Map<String, String> _tagLabels = {
  'y_te': 'Y tế',
  'tre_em': 'Trẻ em',
  'nguoi_gia': 'Người già',
  'ngap_noc': 'Ngập nóc',
  'phuong_tien': 'Cần thuyền',
};

// --- SCREEN ---
class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  String _selectedFilter = 'Tất cả';
  final List<String> _filters = ['Tất cả', 'Đang chờ', 'Hoàn thành', 'Đã huỷ'];

  bool _isLoading = true;
  List<SosHistoryItem> _allItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getSosHistory();
      _allItems = data.map((json) => SosHistoryItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[SosHistoryScreen] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<SosHistoryItem> get _filteredData {
    if (_selectedFilter == 'Tất cả') return _allItems;
    if (_selectedFilter == 'Đang chờ') return _allItems.where((e) => e.status == SosStatus.pending).toList();
    if (_selectedFilter == 'Hoàn thành') return _allItems.where((e) => e.status == SosStatus.completed).toList();
    if (_selectedFilter == 'Đã huỷ') return _allItems.where((e) => e.status == SosStatus.cancelled).toList();
    return _allItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    child: _filteredData.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _filteredData.length,
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(_filteredData[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF7F9FC),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Lịch sử cứu trợ',
        style: AppTypography.headingLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      centerTitle: false,
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = filter),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.textPrimary : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.textPrimary : AppColors.surfaceBorder,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryCard(SosHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID & Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.hash, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      item.id.length > 8 ? item.id.substring(0, 8).toUpperCase() : item.id,
                      style: AppTypography.mono.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildUrgencyBadge(item.urgencyLevel),
                  ],
                ),
                _buildStatusBadge(item.status),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          
          // Body: Summary, Time, Tags
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                if (item.summary.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.fileText, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.summary,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                // Timestamp
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.clock, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(item.createdAt),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                // Tags
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.tags.map((tag) {
                      final label = _tagLabels[tag] ?? tag;
                      Color bgColor = Colors.grey.shade100;
                      Color textColor = Colors.grey.shade700;
                      if (label.toLowerCase().contains('trẻ em') || label.toLowerCase().contains('người già')) {
                        bgColor = AppColors.alertRed.withOpacity(0.1);
                        textColor = AppColors.alertRed;
                      } else if (label.toLowerCase().contains('y tế')) {
                        bgColor = Colors.blue.withOpacity(0.1);
                        textColor = Colors.blue;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10), // Giống giao diện TNV
                        ),
                        child: Text(
                          label,
                          style: AppTypography.bodySmall.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // Footer: Volunteer Info
          if (item.volunteerName != null && item.volunteerName!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.surfaceBorder,
                    child: const Icon(LucideIcons.user, size: 14, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Được hỗ trợ bởi: ',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      item.volunteerName!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(SosStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case SosStatus.pending:
        bgColor = const Color(0xFFFEF9C3); // Vàng nhạt theo yêu cầu
        textColor = const Color(0xFFCA8A04);
        label = 'Đang chờ';
        icon = LucideIcons.loader;
        break;
      case SosStatus.responding:
        bgColor = const Color(0xFFDBEAFE); // Đổi sang xanh dương nhạt để tránh trùng màu vàng của Đang chờ
        textColor = const Color(0xFF2563EB);
        label = 'Đang xử lý';
        icon = LucideIcons.ship;
        break;
      case SosStatus.completed:
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        label = 'Đã xong';
        icon = LucideIcons.checkCircle2;
        break;
      case SosStatus.cancelled:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFEF4444);
        label = 'Đã huỷ';
        icon = LucideIcons.xCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(int level) {
    Color color;
    String label;
    switch (level) {
      case 5:
        color = AppColors.urgency5;
        label = 'MỨC 5';
        break;
      case 4:
        color = AppColors.urgency4;
        label = 'MỨC 4';
        break;
      case 3:
        color = AppColors.urgency3;
        label = 'MỨC 3';
        break;
      case 2:
        color = AppColors.urgency2;
        label = 'MỨC 2';
        break;
      default:
        color = AppColors.urgency1;
        label = 'MỨC 1';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // Dùng ListView thay vì Column để RefreshIndicator hoạt động
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: const Icon(LucideIcons.history, size: 48, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              Text(
                'Không có lịch sử',
                style: AppTypography.headingMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có yêu cầu cứu trợ nào trong danh mục này.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    
    return '$hour:$minute - $day/$month/$year';
  }
}
