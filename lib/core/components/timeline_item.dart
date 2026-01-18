import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum TimelineStatus { pending, completed, overdue }

class TimelineItem extends StatelessWidget {
  final String time;
  final TimelineStatus status;
  final Widget child;
  final bool isLast;
  final Color? lineColor;

  const TimelineItem({
    Key? key,
    required this.time,
    required this.status,
    required this.child,
    this.isLast = false,
    this.lineColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                time,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              _buildStatusDot(),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    color:
                        lineColor ??
                        (isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                ),
            ],
          ),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    switch (status) {
      case TimelineStatus.completed:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.taken,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 12),
        );
      case TimelineStatus.overdue:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.overdue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning, color: Colors.white, size: 12),
        );
      case TimelineStatus.pending:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pending, width: 2),
          ),
        );
    }
  }
}
