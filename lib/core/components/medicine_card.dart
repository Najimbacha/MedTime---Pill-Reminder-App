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
    
    // Modern Gradient for Card Background
    final LinearGradient? backgroundGradient = isCompleted
      ? null
      : LinearGradient(
          colors: isDark 
            ? [AppColors.surface1Dark, AppColors.surface1Dark.withOpacity(0.8)]
            : [Colors.white, Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final EdgeInsets padding = EdgeInsets.all(isCompleted ? 16 : 20);
    final double opacity = isCompleted ? 0.7 : 1.0;
    
    // Soft Shadows
    final List<BoxShadow> boxShadows = customElevation != null
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              offset: const Offset(0, 8),
              blurRadius: customElevation!,
            ),
          ]
        : (isPending
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                    offset: const Offset(0, 10),
                    blurRadius: 20,
                    spreadRadius: -5,
                  )
                ]
              : []);

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: customGradient != null || backgroundGradient != null 
             ? null 
             : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          gradient: customGradient ?? backgroundGradient,
          borderRadius: BorderRadius.circular(24), // Softer corners
          border: Border.all(
            color: isDark 
               ? Colors.white.withOpacity(0.05) 
               : AppColors.borderLight.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: boxShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon Container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                       if (dosage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          dosage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusIndicator(isDark),
              ],
            ),
            
             // Action Buttons for Pending Status
            if (isPending) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: onTake,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Take', 
                              style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: OutlinedButton(
                      onPressed: onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Icon(
                         Icons.close_rounded, 
                         color: isDark ? Colors.grey[400] : Colors.grey[600],
                         size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Taken Status
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Taken',
                      style: AppTextStyles.labelMedium.copyWith(
                         color: AppColors.success,
                         fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    if (status == MedicineStatus.pending) return const SizedBox.shrink();
    
    Color color;
    IconData icon;
    
    switch (status) {
      case MedicineStatus.completed:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case MedicineStatus.overdue:
        color = AppColors.error;
        icon = Icons.warning_rounded;
        break;
      case MedicineStatus.skipped:
        color = AppColors.textDisabledLight;
        icon = Icons.remove_circle_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
