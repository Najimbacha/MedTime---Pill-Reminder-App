import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/components/section_header.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/medicine_provider.dart';
import '../providers/log_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/database_helper.dart';
import '../services/history_service.dart';
import '../services/report_service.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTheme = 'system';
  bool _hapticFeedback = true;
  bool _notificationSound = true;
  bool _vibration = true;
  bool _persistentNotification = false;
  bool _use24HourFormat = false;

  final HistoryService _historyService = HistoryService();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFFAFAFA),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppInfoSection(isDark),
            const SizedBox(height: 40),

            _SectionLabel(label: 'NOTIFICATIONS', isDark: isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notification Sound',
                  value: _notificationSound,
                  onChanged: (value) =>
                      setState(() => _notificationSound = value),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  value: _vibration,
                  onChanged: (value) => setState(() => _vibration = value),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  icon: Icons.notifications_none_outlined,
                  title: 'Persistent Notification',
                  value: _persistentNotification,
                  onChanged: (value) =>
                      setState(() => _persistentNotification = value),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),

            _SectionLabel(label: 'APPEARANCE', isDark: isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeSwitcher(isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _SectionLabel(label: 'PREFERENCES', isDark: isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  icon: Icons.vibration,
                  title: 'Haptic Feedback',
                  value: _hapticFeedback,
                  onChanged: (value) => setState(() => _hapticFeedback = value),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  icon: Icons.access_time,
                  title: '24-Hour Format',
                  value: _use24HourFormat,
                  onChanged: (value) =>
                      setState(() => _use24HourFormat = value),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 32),

            _SectionLabel(label: 'DATA & PRIVACY', isDark: isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildNavigationTile(
                  icon: Icons.download_outlined,
                  title: 'Export Data',
                  onTap: _showExportDialog,
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildNavigationTile(
                  icon: Icons.backup_outlined,
                  title: 'Backup & Restore',
                  onTap: () => _showComingSoon('Backup & Restore'),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildNavigationTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _showComingSoon('Privacy Policy'),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildNavigationTile(
                  icon: Icons.delete_outline,
                  title: 'Delete All Data',
                  onTap: _showDeleteConfirmation,
                  isDark: isDark,
                  textColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 32),

            _SectionLabel(label: 'ABOUT', isDark: isDark),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  value: '1.0.0',
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildNavigationTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () => _showComingSoon('Help & Support'),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildNavigationTile(
                  icon: Icons.rate_review_outlined,
                  title: 'Rate App',
                  onTap: () => _showComingSoon('Rate App'),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
              ),
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 40,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'MedTime',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Medicine Reminder',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: textColor ?? (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: isDark ? Colors.white : Colors.black,
              activeTrackColor: isDark ? Colors.white38 : Colors.black26,
              inactiveThumbColor: isDark ? Colors.white38 : Colors.black38,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSwitcher(bool isDark) {
    final themes = [
      {'label': 'Light', 'value': 'light', 'icon': Icons.light_mode_outlined},
      {'label': 'Dark', 'value': 'dark', 'icon': Icons.dark_mode_outlined},
      {
        'label': 'Auto',
        'value': 'system',
        'icon': Icons.brightness_auto_outlined,
      },
    ];

    return Row(
      children: themes.map((theme) {
        final isSelected = _selectedTheme == theme['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedTheme = theme['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                            ? const Color(0xFF0A0A0A)
                            : const Color(0xFFF5F5F5)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE5E5E5)),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      theme['icon'] as IconData,
                      size: 20,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
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

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      indent: 16,
      endIndent: 16,
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showExportDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Export Data',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Your medication data will be exported as a PDF report.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportData();
            },
            child: Text(
              'Export',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    await HapticHelper.selection();
    await SoundHelper.playClick();

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF report...')));

    try {
      final medicines = context.read<MedicineProvider>().medicines;
      final overallAdherence = await _historyService.getOverallAdherence();
      final streak = await _historyService.getCurrentStreak();
      final recentLogs = await _historyService.getRecentLogs(limit: 50);
      final medNames = {
        for (final med in medicines)
          if (med.id != null) med.id!: med.name,
      };

      final reportService = ReportService();
      await reportService.generateAndShareReport(
        medicines: medicines,
        overallAdherence: overallAdherence,
        streak: streak,
        recentLogs: recentLogs,
        medicineNames: medNames,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete All Data?',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
        ),
        content: Text(
          'This will permanently delete all your medication records, schedules, and settings. This action cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllData();
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllData() async {
    final messenger = ScaffoldMessenger.of(context);
    final medicineProvider = context.read<MedicineProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final logProvider = context.read<LogProvider>();

    await DatabaseHelper.instance.deleteAllData();

    await Future.wait([
      medicineProvider.loadMedicines(),
      scheduleProvider.loadSchedules(),
      logProvider.loadLogs(),
    ]);

    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('All data deleted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white60 : Colors.black54,
        letterSpacing: 0.8,
      ),
    );
  }
}
