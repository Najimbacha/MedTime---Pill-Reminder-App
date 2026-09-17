import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/log_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import 'notification_troubleshoot_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset RoutineTime?'),
        content: const Text(
          'This will permanently delete your routines, schedules, and history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _runBusy(() async {
      await NotificationService.instance.cancelAllNotifications();
      await DatabaseHelper.instance.resetAllData();
      if (!mounted) return;
      await Future.wait([
        context.read<RoutineProvider>().loadRoutines(),
        context.read<ScheduleProvider>().loadSchedules(),
        context.read<LogProvider>().loadLogs(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('RoutineTime reset')));
    });
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@routinetime.app',
      query: 'subject=RoutineTime Support Request',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/splash_icon.png',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RoutineTime',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Simple recurring reminders',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Appearance',
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  settings.setThemeMode(selection.first);
                },
              ),
            ],
          ),
          _Section(
            title: 'Reminders',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('Haptics'),
                value: settings.hapticFeedbackEnabled,
                onChanged: settings.setHapticFeedback,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notification Help'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationTroubleshootScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Backup',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Export Backup'),
                onTap: _busy
                    ? null
                    : () => _runBusy(BackupService().createEncryptedBackup),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore Backup'),
                onTap: _busy
                    ? null
                    : () => _runBusy(BackupService().restoreFromBackup),
              ),
            ],
          ),
          _Section(
            title: 'Data',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Reset Data',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: _busy ? null : _resetData,
              ),
            ],
          ),
          _Section(
            title: 'About',
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline_rounded),
                title: Text('RoutineTime'),
                subtitle: Text('Simple recurring reminders'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Contact Support'),
                onTap: _contactSupport,
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}
