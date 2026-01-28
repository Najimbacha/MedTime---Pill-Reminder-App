import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';

class SettingsCard extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  const SettingsCard({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_controller);
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));
    
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface1Dark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : AppColors.borderLight.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header
          if (widget.title != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title!,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.subtitle != null && !_isExpanded) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RotationTransition(
                        turns: _iconTurns,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Body
          AnimatedBuilder(
            animation: _controller.view,
            builder: (BuildContext context, Widget? child) {
              return ClipRect(
                child: Align(
                  heightFactor: _heightFactor.value,
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                if (widget.title != null)
                   Divider(height: 1, thickness: 1, color: isDark ? Colors.white.withOpacity(0.05) : AppColors.borderLight.withOpacity(0.5)),
                   
                for (int i = 0; i < widget.children.length; i++) ...[
                  widget.children[i],
                  if (i < widget.children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 60, right: 20), // Indented divider
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? Colors.white.withOpacity(0.05) : AppColors.borderLight.withOpacity(0.5),
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
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isDestructive;
  final bool isLoading;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDestructive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Modern Icon Container (Squircle)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isDestructive 
                            ? AppColors.error 
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing
              if (isLoading) ...[
                 const SizedBox(width: 8),
                 const SizedBox(
                   width: 18, 
                   height: 18, 
                   child: CircularProgressIndicator(strokeWidth: 2),
                 ),
              ] else if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  color: isDark ? Colors.white30 : Colors.black26, 
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110, // Decreased height from 130 to 110
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24), // Softer corners
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1), // Glass hint
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8), 
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24), 
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15, 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final String? name;
  final String? email;
  final String? photoUrl;
  final bool isPremium;
  final VoidCallback? onTap;

  const SettingsHeader({
    super.key, 
    this.name,
    this.email,
    this.photoUrl,
    this.isPremium = false,
    this.onTap,
  });

  String _getInitials() {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.split(' ');
      if (parts.length > 1) {
        return parts[0][0] + parts[1][0];
      }
      return name![0];
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final goldGradient = const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface1Dark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isPremium 
            ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5)
            : Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: isPremium 
                   ? const Color(0xFFFFD700).withOpacity(0.15)
                   : Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
             // Avatar
             Stack(
               children: [
                 Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isPremium ? goldGradient : null,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: photoUrl != null 
                          ? Image.network(photoUrl!, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: Center(
                                child: Text(
                                  _getInitials(), 
                                  style: const TextStyle(
                                    fontSize: 20, 
                                    color: AppColors.primary, 
                                    fontWeight: FontWeight.bold
                                  )
                                )
                              ),
                            ),
                      ),
                    ),
                 ),
                 if (isPremium)
                   Positioned(
                     bottom: 0,
                     right: 0,
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(
                         gradient: goldGradient,
                         shape: BoxShape.circle,
                         border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                         boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                         ]
                       ),
                       child: const Icon(Icons.star_rounded, color: Colors.white, size: 10),
                     ),
                   ),
               ],
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Row(
                     children: [
                       Expanded(
                         child: Text(
                           name ?? 'User',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                             letterSpacing: -0.5,
                           ),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       if (isPremium) ...[
                         const SizedBox(width: 8),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                           decoration: BoxDecoration(
                             color: const Color(0xFFFFD700).withOpacity(0.2),
                             border: Border.all(color: const Color(0xFFFFD700), width: 1),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: const Text(
                             'PRO',
                             style: TextStyle(
                               fontSize: 10,
                               fontWeight: FontWeight.w900,
                               color: Color(0xFFB8860B), // Dark Gold text
                               letterSpacing: 0.5,
                             ),
                           ),
                         ),
                       ],
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(
                     email ?? '',
                     style: TextStyle(
                       fontSize: 13,
                       color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                       fontWeight: FontWeight.w500,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ],
               ),
             ),
             const SizedBox(width: 12),
             Icon(
               Icons.arrow_forward_ios_rounded,
               color: isDark ? Colors.white30 : Colors.black26, 
               size: 16,
             ),
          ],
        ),
      ),
    );
  }
}
