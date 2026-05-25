import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Filter parameters returned to parent
class FilterParams {
  final List<int> urgencyLevels;
  final double maxDistance;
  final String sortByDistance; // 'distance_asc' | 'distance_desc'
  final String sortByTime;    // 'newest' | 'oldest'
  final List<String> tags;

  const FilterParams({
    this.urgencyLevels = const [],
    this.maxDistance = 10.0,
    this.sortByDistance = 'distance_asc',
    this.sortByTime = 'newest',
    this.tags = const [],
  });
}

class FilterBottomSheet extends StatefulWidget {
  final FilterParams? initialParams;
  final void Function(FilterParams params)? onApply;

  const FilterBottomSheet({super.key, this.initialParams, this.onApply});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<int> _selectedUrgencies;
  late bool _sortNearest;
  late double _maxDistance;
  late bool _sortNewest;
  late Set<String> _selectedTags;

  final List<String> _allTags = [
    'tre_em',
    'nguoi_gia',
    'y_te',
    'ngap_noc',
    'phuong_tien',
  ];

  final Map<String, String> _tagLabels = {
    'tre_em': 'Trẻ em',
    'nguoi_gia': 'Người già',
    'y_te': 'Y tế',
    'ngap_noc': 'Ngập nóc',
    'phuong_tien': 'Cần thuyền',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.initialParams;
    _selectedUrgencies = p != null ? Set.from(p.urgencyLevels) : {4, 5};
    _sortNearest = p == null || p.sortByDistance == 'distance_asc';
    _maxDistance = p?.maxDistance ?? 10.0;
    _sortNewest = p == null || p.sortByTime == 'newest';
    _selectedTags = p != null ? Set.from(p.tags) : {};
  }

  void _reset() {
    setState(() {
      _selectedUrgencies.clear();
      _sortNearest = true;
      _maxDistance = 10.0;
      _sortNewest = true;
      _selectedTags.clear();
    });
  }

  void _apply() {
    final params = FilterParams(
      urgencyLevels: _selectedUrgencies.toList()..sort(),
      maxDistance: _maxDistance,
      sortByDistance: _sortNearest ? 'distance_asc' : 'distance_desc',
      sortByTime: _sortNewest ? 'newest' : 'oldest',
      tags: _selectedTags.toList(),
    );
    widget.onApply?.call(params);
    Navigator.pop(context);
  }

  Color _getUrgencyColor(int level) {
    switch (level) {
      case 5:
        return AppColors.urgency5;
      case 4:
        return AppColors.urgency4;
      case 3:
        return AppColors.urgency3;
      case 2:
        return AppColors.urgency2;
      default:
        return AppColors.urgency1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = _selectedUrgencies.length + _selectedTags.length +
        (_maxDistance < 10 ? 1 : 0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lọc & Sắp xếp',
                  style: AppTypography.headingMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Đặt lại',
                    style: TextStyle(
                      color: AppColors.alertRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. MỨC ĐỘ KHẨN CẤP
                _buildSectionHeader('MỨC ĐỘ KHẨN CẤP', trailing: 'Chọn nhiều'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final level = 5 - index;
                    final color = _getUrgencyColor(level);
                    final isSelected = _selectedUrgencies.contains(level);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUrgencies.remove(level);
                          } else {
                            _selectedUrgencies.add(level);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.15) : Colors.white,
                          border: Border.all(
                            color: isSelected ? color : color.withOpacity(0.8),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Mức $level',
                          style: TextStyle(
                            color: isSelected ? color : color.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),

                // 2. KHOẢNG CÁCH
                _buildSectionHeader('KHOẢNG CÁCH', trailing: 'Sắp xếp & giới hạn'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSortButton(true, _sortNearest, 'Gần ➔ xa', Icons.sort)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSortButton(false, !_sortNearest, 'Xa ➔ gần', Icons.sort)),
                  ],
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bán kính', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      _maxDistance == -1 ? 'Toàn quốc' : '${_maxDistance.toInt()} km', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [5.0, 10.0, 20.0, 50.0, -1.0].map((dist) {
                    final isSelected = _maxDistance == dist;
                    final label = dist == -1.0 ? 'Toàn quốc' : '${dist.toInt()} km';
                    return GestureDetector(
                      onTap: () => setState(() => _maxDistance = dist),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.alertRed.withOpacity(0.1) : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.alertRed : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? AppColors.alertRed : Colors.grey.shade800,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),

                // 3. THỜI GIAN GỬI SOS
                _buildSectionHeader('THỜI GIAN GỬI SOS', trailing: 'Sắp xếp'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeSortButton(true, _sortNewest, 'Mới nhất', 'Vừa gửi lên đầu', Icons.schedule),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeSortButton(false, !_sortNewest, 'Chờ lâu nhất', 'Đợi lâu lên đầu', Icons.history),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),

                // 4. TAGS ĐẶC BIỆT
                _buildSectionHeader('TAGS ĐẶC BIỆT', trailing: 'Chọn nhiều'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: _allTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    final label = _tagLabels[tag] ?? tag;
                    Color color = isSelected ? AppColors.alertRed : Colors.grey;
                    if (isSelected && (tag == 'tre_em' || tag == 'nguoi_gia')) color = AppColors.alertRed;
                    else if (isSelected && tag == 'y_te') color = AppColors.primary;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) _selectedTags.remove(tag);
                          else _selectedTags.add(tag);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.1) : Colors.white,
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? color : Colors.grey.shade800,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Bottom Action
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.alertRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      activeFilterCount > 0
                          ? 'Áp dụng ($activeFilterCount bộ lọc)'
                          : 'Áp dụng',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  Widget _buildSortButton(bool isNearest, bool isSelected, String label, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _sortNearest = isNearest),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.alertRed.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.alertRed : Colors.grey.shade400,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.alertRed : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.alertRed : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSortButton(bool isNewest, bool isSelected, String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _sortNewest = isNewest),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.alertRed.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.alertRed : Colors.grey.shade400,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.alertRed : Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.alertRed : Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? AppColors.alertRed.withOpacity(0.7) : Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
