import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosLegendWidget extends StatefulWidget {
  const SosLegendWidget({super.key});

  @override
  State<SosLegendWidget> createState() => _SosLegendWidgetState();
}

class _SosLegendWidgetState extends State<SosLegendWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mức 1',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.urgency1,
                          AppColors.urgency2,
                          AppColors.urgency3,
                          AppColors.urgency4,
                          AppColors.urgency5,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Text(
                    'Mức 5',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              
              // Expanded content
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                _buildLegendItem(AppColors.urgency5, 'Mức 5 - Rất cao'),
                _buildLegendItem(AppColors.urgency4, 'Mức 4 - Cao'),
                _buildLegendItem(AppColors.urgency3, 'Mức 3 - Trung bình'),
                _buildLegendItem(AppColors.urgency2, 'Mức 2 - Thấp'),
                _buildLegendItem(AppColors.urgency1, 'Mức 1 - Rất thấp'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
