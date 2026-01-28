import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          // Full width, no floating margins
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF0F172A).withOpacity(0.90) 
                : Colors.white.withOpacity(0.90),
            border: Border(
              top: BorderSide(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 64, // Standard tab bar height
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context, 
                    0, 
                    IconlyBold.home, 
                    IconlyLight.home, 
                    'Home'
                  ),
                  _buildNavItem(
                    context, 
                    1, 
                    IconlyBold.discovery, 
                    IconlyLight.discovery, 
                    'Meds'
                  ),
                  _buildNavItem(
                    context, 
                    2, 
                    IconlyBold.calendar, 
                    IconlyLight.calendar, 
                    'History'
                  ),
                  _buildNavItem(
                    context, 
                    3, 
                    IconlyBold.setting, 
                    IconlyLight.setting, 
                    'Settings'
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            onTap(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()..scale(isSelected ? 1.1 : 1.0),
              alignment: Alignment.center,
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected 
                    ? primaryColor 
                    : (isDark ? Colors.white38 : Colors.grey[500]),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                    ? primaryColor 
                    : (isDark ? Colors.white38 : Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

