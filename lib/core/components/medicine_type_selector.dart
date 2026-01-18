import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class MedicineTypeOption {
  final String label;
  final IconData icon;
  final String value;

  const MedicineTypeOption({
    required this.label,
    required this.icon,
    required this.value,
  });
}

class MedicineTypeSelector extends StatelessWidget {
  final List<MedicineTypeOption> options;
  final String? selectedValue;
  final ValueChanged<String> onChanged;

  const MedicineTypeSelector({
    Key? key,
    required this.options,
    this.selectedValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: options.map((option) {
        final isSelected = option.value == selectedValue;
        
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: AppRadius.mediumRadius,
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : (isDark ? AppColors.surface1Dark : AppColors.surface1Light),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: AppRadius.mediumRadius,
                ),
                child: Column(
                  children: [
                    Icon(
                      option.icon,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      size: 32,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      option.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
