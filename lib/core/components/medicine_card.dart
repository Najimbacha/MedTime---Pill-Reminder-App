import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum MedicineStatus { pending, completed, overdue, skipped }

class MedicineCard extends StatelessWidget {
  final String name;
  final String? dosage;
  final Color color;
  final IconData icon;
  final MedicineStatus status;
  final bool showGlassEffect;
  final double? customElevation;
  final Border? customBorder;
  final Gradient? customGradient;
  final VoidCallback? onTake;
  final VoidCallback? onSkip;

  const MedicineCard({
    Key? key,
    required this.name,
    this.dosage,
    required this.color,
    required this.icon,
    this.status = MedicineStatus.pending,
    this.showGlassEffect = false,
    this.customElevation,
    this.customBorder,
    this.customGradient,
    this.onTake,
    this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCompleted = status == MedicineStatus.completed;
    final bool isPending = status == MedicineStatus.pending;
    final Color baseColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color completedColor = isDark
        ? AppColors.surface1Dark
        : AppColors.surface1Light;
    final EdgeInsets padding = EdgeInsets.all(
      isCompleted ? AppSpacing.md : AppSpacing.lg,
    );
    final double opacity = isCompleted ? 0.65 : 1;
    final List<BoxShadow> boxShadows = customElevation != null
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
              offset: const Offset(0, 8),
              blurRadius: customElevation!,
            ),
          ]
        : (showGlassEffect
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                    offset: const Offset(0, 12),
                    blurRadius: 30,
                  ),
                ]
              : isPending
              ? AppShadows.level3
              : AppShadows.level0);

    final BoxDecoration decoration = BoxDecoration(
      color: customGradient == null
          ? (showGlassEffect
                ? (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.65))
                : (isCompleted ? completedColor : baseColor))
          : null,
      gradient: customGradient,
      borderRadius: AppRadius.largeRadius,
      border:
          customBorder ??
          Border.all(
            color: isCompleted
                ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
      boxShadow: boxShadows,
    );

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: AppRadius.mediumRadius,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dosage != null) ...[
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          dosage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusIndicator(isDark),
              ],
            ),
            if (isCompleted)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.taken,
                      size: 16,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Taken',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            if (status == MedicineStatus.pending) ...[
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: onTake,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mediumRadius,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, size: 18),
                            SizedBox(width: AppSpacing.xs),
                            Text('Take', style: AppTextStyles.labelMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onSkip,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mediumRadius,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.close, size: 18),
                            SizedBox(width: AppSpacing.xs),
                            Text('Skip', style: AppTextStyles.labelMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    switch (status) {
      case MedicineStatus.completed:
        return Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.taken.withOpacity(0.1),
            borderRadius: AppRadius.smallRadius,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.taken,
            size: 20,
          ),
        );
      case MedicineStatus.overdue:
        return Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.overdue.withOpacity(0.1),
            borderRadius: AppRadius.smallRadius,
          ),
          child: const Icon(Icons.warning, color: AppColors.overdue, size: 20),
        );
      case MedicineStatus.skipped:
        return Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.skipped.withOpacity(0.1),
            borderRadius: AppRadius.smallRadius,
          ),
          child: const Icon(
            Icons.remove_circle,
            color: AppColors.skipped,
            size: 20,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
