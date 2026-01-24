import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/settings_widgets.dart'; // Premium UI Components
import 'package:url_launcher/url_launcher.dart';

import 'auth_screen.dart';
import 'invite_caregiver_screen.dart';
import 'accept_invite_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'notification_troubleshoot_screen.dart';

/// Settings screen - Premium Redesign
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _exactAlarmsEnabled = false;
  bool _isCheckingPermissions = true;
  bool _isSharingLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notificationService = NotificationService.instance;
    final notificationsEnabled = await notificationService.areNotificationsEnabled();
    final exactAlarmsEnabled = await notificationService.canScheduleExactAlarms();
    
    if (mounted) {
      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _exactAlarmsEnabled = exactAlarmsEnabled;
        _isCheckingPermissions = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await HapticHelper.selection();
    final notificationService = NotificationService.instance;
    await notificationService.requestAllPermissions();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // Clean background
      extendBodyBehindAppBar: true,
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 120), // Top 60, Bottom 120 for Glass Nav
          child: Column(
            children: [
            // 1. Premium Header
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                 final displayName = authProvider.userProfile?.displayName 
                                   ?? authProvider.firebaseUser?.displayName 
                                   ?? 'Friend';
                 final photoUrl = authProvider.firebaseUser?.photoURL;
                 final email = authProvider.userProfile?.email ?? authProvider.firebaseUser?.email;
                 
                 return PremiumAppHeader(
                   name: displayName,
                   photoUrl: photoUrl,
                   email: email,
                   onTap: () => _showProfileDialog(context, authProvider),
                 );
              },
            ),
            const SizedBox(height: 16),

            // 2. Preferences (Sound, Haptics) - Personalization
            Consumer<SettingsService>(
              builder: (context, settings, _) {
                return SettingsSection(
                  title: 'PREFERENCES',
                  children: [
                    SettingsTile(
                      icon: Icons.vibration, 
                      iconColor: Colors.teal,
                      title: 'Haptic Feedback',
                      trailing: Switch(
                        value: settings.hapticFeedbackEnabled,
                        onChanged: (value) async {
                           await settings.setHapticFeedback(value);
                           if (value) {
                             await HapticHelper.success();
                             await SoundHelper.playClick();
                           }
                        },
                      ),
                      onTap: () async {
                         final newVal = !settings.hapticFeedbackEnabled;
                         await settings.setHapticFeedback(newVal);
                         if (newVal) await HapticHelper.success();
                      },
                    ),
                    SettingsTile(
                      icon: Icons.volume_up,
                      iconColor: Colors.indigo,
                      title: 'Sound Effects',
                      trailing: Switch(
                         value: settings.soundEnabled,
                         onChanged: (value) async {
                           await settings.setSoundEnabled(value);
                           if (value) await SoundHelper.playClick();
                         },
                      ),
                      onTap: () async {
                         final newVal = !settings.soundEnabled;
                         await settings.setSoundEnabled(newVal);
                         if (newVal) await SoundHelper.playClick();
                      },
                    ),
                     SettingsTile(
                       icon: Icons.palette,
                       iconColor: Colors.pink,
                       title: 'App Theme',
                       showChevron: false,
                       trailing: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          segments: const [
                            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) async {
                            await HapticHelper.selection();
                            await SoundHelper.playClick();
                            await settings.setThemeMode(newSelection.first);
                          },
                       ),
                     ),
                    SettingsTile(
                      icon: Icons.inventory_2,
                      iconColor: Colors.brown,
                      title: 'Low Stock Alert',
                      subtitle: 'Threshold: ${settings.lowStockThreshold} doses',
                      onTap: () => _showLowStockDialog(context, settings),
                    ),
                  ],
                );
              },
            ),

            // 3. Notifications Section - Core Utility
            SettingsSection(
              title: 'NOTIFICATIONS',
              children: [
                SettingsTile(
                  icon: _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                  iconColor: _notificationsEnabled ? Colors.green : Colors.red,
                  title: 'Reminders',
                  subtitle: _notificationsEnabled ? 'Permission granted' : 'Permission required',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) => _requestPermissions(), // Always request if toggled
                    activeColor: Colors.green,
                  ),
                  onTap: _requestPermissions,
                ),
                if (Platform.isAndroid)
                  SettingsTile(
                    icon: Icons.access_time_filled,
                    iconColor: _exactAlarmsEnabled ? Colors.blue : Colors.orange,
                    title: 'Exact Alarms',
                    subtitle: _exactAlarmsEnabled ? 'For precise timing' : 'Required for accuracy',
                    trailing: _exactAlarmsEnabled 
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                      : OutlinedButton(
                          onPressed: _requestPermissions,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Enable'),
                        ),
                    onTap: _exactAlarmsEnabled ? null : _requestPermissions, 
                    showChevron: !_exactAlarmsEnabled,
                  ),
                
                // Troubleshoot Tile
                SettingsTile(
                  icon: Icons.build_circle,
                  iconColor: Colors.amber.shade800,
                  title: 'Troubleshoot Issues',
                  subtitle: 'Fix missed reminders',
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const NotificationTroubleshootScreen()),
                  ),
                ),
              ],
            ),

            // 4. Family Sharing (Cloud) - High Importance / Account
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isSignedIn = authProvider.isSignedIn;
                final profile = authProvider.userProfile;
                
                return SettingsSection(
                  title: 'FAMILY SHARING',
                  children: [
                    if (isSignedIn) ...[
                      // Share Toggle
                      SettingsTile(
                        icon: Icons.share,
                        iconColor: Theme.of(context).colorScheme.primary,
                        title: 'Enable Sharing',
                        subtitle: 'Allow caregivers to view logs',
                        isLoading: _isSharingLoading,
                        trailing: Switch(
                          value: profile?.shareEnabled ?? false,
                          onChanged: _isSharingLoading ? null : (value) async {
                            setState(() => _isSharingLoading = true);
                            await HapticHelper.selection();
                            try {
                              await authProvider.setShareEnabled(value);
                            } finally {
                              if (mounted) setState(() => _isSharingLoading = false);
                            }
                          },
                        ),
                        onTap: () async {
                           if (_isSharingLoading) return;
                           final newValue = !(profile?.shareEnabled ?? false);
                           setState(() => _isSharingLoading = true);
                           await HapticHelper.selection();
                           try {
                             await authProvider.setShareEnabled(newValue);
                           } finally {
                             if (mounted) setState(() => _isSharingLoading = false);
                           }
                        },
                      ),
                      
                      // Invite Caregiver
                      SettingsTile(
                        icon: Icons.qr_code,
                        iconColor: Colors.purple,
                        title: 'Invite Caregiver',
                        subtitle: 'Share access code',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InviteCaregiverScreen()),
                        ),
                      ),
                      
                      // Accept Invite
                      SettingsTile(
                        icon: Icons.qr_code_scanner,
                        iconColor: Colors.deepOrange,
                        title: 'Accept Invite',
                        subtitle: 'Become a caregiver',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AcceptInviteScreen()),
                        ),
                      ),
                      
                      // Dashboard (if caregiver)
                      if (profile?.isCaregiver == true)
                        SettingsTile(
                          icon: Icons.dashboard,
                          iconColor: Colors.indigo,
                          title: 'Caregiver Dashboard',
                          subtitle: 'Monitor patients',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CaregiverDashboardScreen()),
                          ),
                        ),
                    ] else ...[
                       // If not signed in, show a simple "Get Started" tile instead of full account status
                       SettingsTile(
                          icon: Icons.cloud_off,
                          iconColor: Colors.grey,
                          title: 'Setup Family Sharing',
                          subtitle: 'Sign in to sync & share',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                          ),
                       ),
                    ],
                  ],
                );
              },
            ),



            // 5. Legal & Data - Compliance
            SettingsSection(
              title: 'LEGAL & DATA',
              children: [
                SettingsTile(
                  icon: Icons.privacy_tip,
                  iconColor: Colors.blueGrey,
                  title: 'Privacy Policy',
                  onTap: () async {
                    const url = 'https://www.privacypolicies.com/live/placeholder'; // Placeholder
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Could not open Privacy Policy')),
                         );
                       }
                    }
                  },
                ),
                SettingsTile(
                  icon: Icons.upload_file,
                  iconColor: Colors.deepPurple,
                  title: 'Backup Data',
                  onTap: () async {
                    await HapticHelper.selection();
                    try {
                      await BackupService().createEncryptedBackup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup ready to share')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                SettingsTile(
                  icon: Icons.download,
                  iconColor: Colors.tealAccent.shade700,
                  title: 'Restore Data',
                  onTap: () { 
                    HapticHelper.warning();
                    _showRestoreDialog(context);
                  },
                ),
                SettingsTile(
                  icon: Icons.delete_sweep, // Less scary than delete_forever for local reset
                  iconColor: Colors.orange,
                  title: 'Reset Local Data',
                  subtitle: 'Use if app is buggy',
                  onTap: () => _showResetDialog(context),
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (!auth.isSignedIn) return const SizedBox.shrink();
                    return SettingsTile(
                      icon: Icons.delete_forever,
                      iconColor: Colors.red,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove all cloud data',
                      isDestructive: true,
                      onTap: () => _showDeleteAccountDialog(context, auth),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        ), // SingleChildScrollView
      ), // Container
    ); // Scaffold
  }

  // Helper Methods

  void _showLowStockDialog(BuildContext context, SettingsService settings) async {
    await HapticHelper.light();
    await SoundHelper.playClick();
    
    showDialog(
      context: context,
      builder: (context) {
        int threshold = settings.lowStockThreshold;
        
        return AlertDialog(
          title: const Text('Low Stock Alert'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Alert when doses remaining:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 32),
                        onPressed: threshold > 1
                            ? () {
                                HapticHelper.light();
                                setState(() => threshold--);
                              }
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$threshold',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 32),
                        onPressed: threshold < 30
                            ? () {
                                HapticHelper.light();
                                setState(() => threshold++);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await settings.setLowStockThreshold(threshold);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.clearAllData();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text('This will OVERWRITE all current data with the backup. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await BackupService().restoreFromBackup();
                if (context.mounted) {
                  // Reload data logic...
                  // Simplified for brevity, in a real app would use a clearer provider methods 
                  // Assuming simple reload works:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restore successful! Please restart app for best results.')),
                  );
                }
              } catch (e) {
                debugPrint('Restore error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Restore', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) {
        final isSignedIn = authProvider.isSignedIn;
        final email = authProvider.userProfile?.email ?? authProvider.firebaseUser?.email;
        final name = authProvider.userProfile?.displayName ?? 'Friend';

        return AlertDialog(
          title: Text(isSignedIn ? 'Account' : 'Welcome'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSignedIn) ...[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: authProvider.firebaseUser?.photoURL != null
                      ? NetworkImage(authProvider.firebaseUser!.photoURL!)
                      : null,
                  child: authProvider.firebaseUser?.photoURL == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24))
                      : null,
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(email ?? '', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 24),
                const Text('Signed in via Google'),
              ] else ...[
                const Icon(Icons.account_circle, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Sign in to sync your data and share with caregivers.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (isSignedIn)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await authProvider.signOut();
                },
                child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Text('Sign In'),
              ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete your account and all synced data from the cloud. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              
              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final success = await auth.deleteAccount();
              
              if (context.mounted) {
                Navigator.pop(context); // Pop loading
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully')),
                  );
                  Navigator.pop(context); // Go back to Home/Auth
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(auth.error ?? 'Failed to delete account'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
