import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';
import 'emergency_info_screen.dart';

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.medication,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MedTime',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Offline-first medicine reminder that respects your privacy',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Emergency Section
          const Text(
            'Emergency',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.emergency,
                size: 28,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Emergency QR Code',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Critical medical info for paramedics',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyInfoScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Section
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<SettingsService>(
            builder: (context, settings, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.palette_outlined, size: 28, color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          'App Theme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) async {
                            await HapticHelper.selection();
                            await SoundHelper.playClick();
                            await settings.setThemeMode(newSelection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Preferences Section
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<SettingsService>(
            builder: (context, settings, _) {
              return Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.vibration,
                        size: 28,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      title: Text(
                        'Haptic Feedback',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Vibrate on button press',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      value: settings.hapticFeedbackEnabled,
                      onChanged: (value) async {
                        await settings.setHapticFeedback(value);
                        if (value) {
                          await HapticHelper.success();
                          await SoundHelper.playClick();
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.volume_up,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Sound Effects',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Play sounds for notifications',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      value: settings.soundEnabled,
                      onChanged: (value) async {
                        await settings.setSoundEnabled(value);
                        await HapticHelper.selection();
                        if (value) await SoundHelper.playClick();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.inventory_2,
                        size: 28,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      title: Text(
                        'Low Stock Alert',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Alert when ${settings.lowStockThreshold} or fewer doses remain',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: Text(
                        '${settings.lowStockThreshold}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () => _showLowStockDialog(context, settings),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Privacy Section
          const Text(
            'Privacy',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield, size: 28, color: Colors.green),
                  title: const Text(
                    'Data Storage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'All data stored locally on your device',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_off, size: 28, color: Colors.blue),
                  title: const Text(
                    'No Cloud Sync',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Your data never leaves your device',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined, size: 28, color: Colors.orange),
                  title: const Text(
                    'No Analytics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'We don\'t track your usage',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data Management
          const Text(
            'Data Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, size: 28, color: Colors.red),
              title: const Text(
                'Reset All Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Delete all medicines, schedules, and logs',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () => _showResetDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          // About
          const Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MedTime is designed with privacy as the core principle. '
                    'We do not collect, store, or transmit any of your personal '
                    'health information. All data is stored locally on your device '
                    'using SQLite database. The app functions completely offline '
                    'and does not require an internet connection.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, SettingsService settings) async {
    await HapticHelper.light();
    await SoundHelper.playClick();
    
    showDialog(
      context: context,
      builder: (context) {
        int threshold = settings.lowStockThreshold;
        
        return AlertDialog(
          title: const Text(
            'Low Stock Alert Threshold',
            style: TextStyle(fontSize: 22),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Alert me when doses remaining are:',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 36),
                        onPressed: threshold > 1
                            ? () async {
                                await HapticHelper.light();
                                setState(() => threshold--);
                              }
                            : null,
                      ),
                      const SizedBox(width: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Text(
                          '$threshold',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 36),
                        onPressed: threshold < 30
                            ? () async {
                                await HapticHelper.light();
                                setState(() => threshold++);
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    threshold == 1 ? '1 dose' : '$threshold doses',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticHelper.light();
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () async {
                await HapticHelper.success();
                await settings.setLowStockThreshold(threshold);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) async {
    await HapticHelper.warning();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset All Data',
          style: TextStyle(fontSize: 22),
        ),
        content: const Text(
          'This will permanently delete all medicines, schedules, and logs. '
          'This action cannot be undone.\n\nAre you sure?',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticHelper.light();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () async {
              await HapticHelper.heavy();
              
              // Reset database
              await DatabaseHelper.instance.resetAllData();

              // Reload providers
              if (context.mounted) {
                final medicineProvider = context.read<MedicineProvider>();
                final scheduleProvider = context.read<ScheduleProvider>();
                final logProvider = context.read<LogProvider>();

                await Future.wait([
                  medicineProvider.loadMedicines(),
                  scheduleProvider.loadSchedules(),
                  logProvider.loadLogs(),
                ]);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✓ All data has been reset',
                      style: TextStyle(fontSize: 18),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
