import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final int shadowLevel;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.shadowLevel = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = color ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);

    Widget card = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.largeRadius,
        boxShadow: _getShadow(),
      ),
      padding: padding ?? EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: AppRadius.largeRadius,
        child: card,
      );
    }

    return card;
  }

  List<BoxShadow> _getShadow() {
    switch (shadowLevel) {
      case 0:
        return AppShadows.level0;
      case 1:
        return AppShadows.level1;
      case 2:
        return AppShadows.level2;
      case 3:
        return AppShadows.level3;
      case 4:
        return AppShadows.level4;
      default:
        return AppShadows.level1;
    }
  }
}
