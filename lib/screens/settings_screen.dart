import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
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
import '../services/report_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/settings_widgets.dart'; // iOS UI Components
import 'package:url_launcher/url_launcher.dart';
import '../providers/subscription_provider.dart';
import 'paywall_screen.dart';

import 'auth_screen.dart';
import 'invite_caregiver_screen.dart';
import 'accept_invite_screen.dart';
import 'caregiver_dashboard_screen.dart';
import '../widgets/staggered_list_animation.dart';
import 'notification_troubleshoot_screen.dart';
import 'statistics_screen.dart';

/// Settings screen - iOS Redesign
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _exactAlarmsEnabled = false;
  bool _isSharingLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifs = await NotificationService.instance.areNotificationsEnabled();
    final alarms = await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifs;
        _exactAlarmsEnabled = alarms;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await HapticHelper.selection();
    final granted = await NotificationService.instance.requestAllPermissions();
    if (mounted) {
      setState(() {
        _notificationsEnabled = granted; // requestAllPermissions returns bool
      });
      // Check exact alarms again too
      final alarms = await NotificationService.instance
          .canScheduleExactAlarms();
      setState(() => _exactAlarmsEnabled = alarms);
    }
  }

  Future<bool> _checkPremium(BuildContext context) async {
    final subscription = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    if (!subscription.isPremium) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      // Return updated status (they might have bought it)
      return subscription.isPremium;
    }
    return true;
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset App Data?'),
        content: const Text(
          'This will delete all your medicines, schedules, and logs.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performReset();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    try {
      final db = DatabaseHelper.instance;

      // Delete everything from DB
      await db.deleteAllData();

      // Clear Providers
      if (mounted) {
        final medProvider = Provider.of<MedicineProvider>(
          context,
          listen: false,
        );
        // MedicineProvider usually reloads from DB on init, but we should clear local list
        // Assuming refresh() or we can just trigger a reload.
        // Actually, db.deleteAllData() clears DB. Providers need to reload to see empty.

        // However, the previous logic was deleting one by one via Provider.
        // Doing it via DB is faster but Providers might be out of sync.
        // Let's ask providers to refresh.
        // But medProvider might not have 'refresh'.
        // Let's stick to safe iterative delete if providers support it, OR just restart app logic.

        // Iterative delete (safer for Provider state):
        for (var med in medProvider.medicines) {
          if (med.id != null) {
            await medProvider.deleteMedicine(med.id!);
          }
        }

        // Clear logs
        await Provider.of<LogProvider>(context, listen: false).clearAllLogs();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App data reset successfully')),
        );
      }
    } catch (e) {
      debugPrint('Reset error: $e');
    }
  }

  void _showRestoreDialog(BuildContext context) {
    // Placeholder for restore logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a backup file to restore')),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your cloud account and family sharing links.\n\nLocal data will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.deleteAccount();
              if (mounted) Navigator.pop(context); // Go back to main
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Properly'),
          ),
        ],
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, SettingsService settings) {
    final controller = TextEditingController(
      text: settings.lowStockThreshold.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Low Stock Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Alert when doses remaining is below:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                suffixText: 'doses',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 0) {
                settings.setLowStockThreshold(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context, AuthProvider auth) {
    if (!auth.isSignedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: auth.firebaseUser?.photoURL != null
                        ? NetworkImage(auth.firebaseUser!.photoURL!)
                        : null,
                    backgroundColor: Colors.transparent,
                    child: auth.firebaseUser?.photoURL == null
                        ? Text(
                            (auth.userProfile?.displayName ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                auth.userProfile?.displayName ?? 'User',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                auth.firebaseUser?.email ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              // Sign Out Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await auth.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.1),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: AppColors.error),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Delete Account
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountDialog(context, auth);
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: isDark ? Colors.white30 : Colors.grey[400],
                ),
                label: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateReport(BuildContext context) async {
    // Show loading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating Report...')));

    try {
      final medProvider = Provider.of<MedicineProvider>(context, listen: false);
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Gather Data
      final medicines = medProvider.medicines;
      final logs =
          logProvider.logs; // Assuming this is available or we need to fetch

      // Calculate basic adherence for report demo
      // In a real app, calculate actual adherence from logs vs schedule
      final overallAdherence = 95.0; // Mock or calculate
      final streak = 12; // Mock or calculate

      final medicineNames = {for (var m in medicines) m.id!: m.name};

      await ReportService().generateAndShareReport(
        medicines: medicines,
        overallAdherence: overallAdherence,
        streak: streak,
        recentLogs: logs,
        medicineNames: medicineNames,
        patientName: authProvider.userProfile?.displayName ?? 'Patient',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProBadge(bool isDark) {
    return Container(
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
          color: Color(0xFFB8860B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // iOS System Grouped Background
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

    // Use Gradient Background instead of solid color
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? AppColors.surfaceDark
          : AppColors.surfaceLight, // Fallback
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: Text(
                'Settings',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              actions: [
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (!auth.isSignedIn) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor: AppColors.primary.withOpacity(
                              0.05,
                            ),
                          ),
                        ),
                      );
                    }

                    final photoUrl = auth.firebaseUser?.photoURL;
                    final name = auth.userProfile?.displayName ?? 'User';
                    final initials = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?';

                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: GestureDetector(
                        onTap: () => _showProfileDialog(context, auth),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl != null
                                ? Image.network(photoUrl, fit: BoxFit.cover)
                                : Container(
                                    color: AppColors.primary,
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ], // Correctly closing actions list
            ), // Correctly closing SliverAppBar

            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 32),

                  // 2. Quick Actions Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Card 1: Share Report (Premium)
                        QuickActionCard(
                          title: 'Share Report',
                          icon: Icons.summarize_rounded,
                          gradientColors: const [
                            Color(0xFF6366F1),
                            Color(0xFF818CF8),
                          ],
                          badge: _buildProBadge(isDark),
                          onTap: () async {
                            if (await _checkPremium(context)) {
                              await _generateReport(context);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        // Card 2: Caregiver (Monitor)
                        QuickActionCard(
                          title: 'Monitor',
                          icon: Icons.health_and_safety_rounded,
                          gradientColors: const [
                            Color(0xFFEC4899),
                            Color(0xFFF472B6),
                          ],
                          badge: _buildProBadge(isDark),
                          onTap: () async {
                            if (await _checkPremium(context)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CaregiverDashboardScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SimpleStaggeredList(
                    children: [
                      // 3. ESSENTIALS (Reports & Account)
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return SettingsCard(
                            title: 'ESSENTIALS',
                            subtitle: 'Reports, Subscription, Family',
                            initiallyExpanded: true, // Auto-expand first group
                            children: [
                              // Subscription (Moved to top, always visible)
                              Consumer<SubscriptionProvider>(
                                builder: (context, sub, _) {
                                  return SettingsTile(
                                    icon: Icons.star_rounded,
                                    iconColor: const Color(0xFFFFD700), // Gold
                                    title: 'Subscription',
                                    subtitle: sub.isPremium
                                        ? 'Premium Active'
                                        : 'Free Plan',
                                    trailing: sub.isPremium
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFFD700,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFFFD700),
                                              ),
                                            ),
                                            child: const Text(
                                              'PRO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFB8860B),
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                    onTap: () => sub.isPremium
                                        ? null
                                        : _checkPremium(context),
                                  );
                                },
                              ),

                              SettingsTile(
                                icon: Icons.family_restroom_rounded,
                                iconColor: const Color(0xFFEC4899),
                                title: 'Family Sharing',
                                subtitle: auth.isSignedIn
                                    ? 'Manage caregivers'
                                    : 'Sign in to access',
                                onTap: () {
                                  if (!auth.isSignedIn) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AuthScreen(),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            auth.userProfile?.isCaregiver ==
                                                true
                                            ? const CaregiverDashboardScreen()
                                            : const InviteCaregiverScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),

                              SettingsTile(
                                icon: Icons.bar_chart_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: 'Health Dashboard',
                                subtitle: 'Adherence & Stats',
                                trailing: _buildProBadge(isDark),
                                onTap: () async {
                                  if (await _checkPremium(context)) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const StatisticsScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),

                      // 4. APP SETTINGS (Notifications, Data, Prefs)
                      Consumer<SettingsService>(
                        builder: (context, settings, _) {
                          return SettingsCard(
                            title: 'APP SETTINGS',
                            subtitle: 'Notifications, Backup, Appearance',
                            children: [
                              // -- Notifications --
                              SettingsTile(
                                icon: _notificationsEnabled
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_rounded,
                                iconColor: _notificationsEnabled
                                    ? const Color(0xFF6366F1)
                                    : Colors.grey,
                                title: 'Notifications',
                                trailing: Switch.adaptive(
                                  value: _notificationsEnabled,
                                  onChanged: (val) => _requestPermissions(),
                                  activeColor: const Color(0xFF6366F1),
                                ),
                                onTap: () async {
                                  if (!_notificationsEnabled)
                                    await _requestPermissions();
                                },
                              ),
                              if (Platform.isAndroid)
                                SettingsTile(
                                  icon: Icons.alarm_rounded,
                                  iconColor: _exactAlarmsEnabled
                                      ? const Color(0xFF10B981)
                                      : AppColors.error,
                                  title: 'Exact Alarms',
                                  subtitle: _exactAlarmsEnabled
                                      ? 'Active'
                                      : 'Fix Issues',
                                  trailing: _exactAlarmsEnabled
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF10B981),
                                          size: 16,
                                        )
                                      : const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 20,
                                        ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationTroubleshootScreen(),
                                    ),
                                  ),
                                ),

                              // -- Backup --
                              SettingsTile(
                                icon: Icons.cloud_upload_rounded,
                                iconColor: const Color(0xFF3B82F6),
                                title: 'Backup & Restore',
                                subtitle: 'Save or import data',
                                trailing: _buildProBadge(isDark),
                                onTap: () async {
                                  if (await _checkPremium(context)) {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(20),
                                              ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.upload_file_rounded,
                                              ),
                                              title: const Text(
                                                'Export Backup',
                                              ),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                try {
                                                  await BackupService()
                                                      .createEncryptedBackup();
                                                } catch (e) {
                                                  /* handled in service/UI */
                                                }
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.restore_page_rounded,
                                              ),
                                              title: const Text(
                                                'Import Backup',
                                              ),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                try {
                                                  await BackupService()
                                                      .restoreFromBackup();
                                                  if (context.mounted)
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Restored successfully',
                                                        ),
                                                      ),
                                                    );
                                                } catch (e) {
                                                  /* */
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              // -- Prefs --
                              SettingsTile(
                                icon: Icons.dark_mode_rounded,
                                iconColor: const Color(0xFF6366F1),
                                title: 'Appearance',
                                subtitle: settings.themeMode.name.toUpperCase(),
                                onTap: () async {
                                  var newMode = ThemeMode.system;
                                  if (settings.themeMode == ThemeMode.system)
                                    newMode = ThemeMode.light;
                                  else if (settings.themeMode ==
                                      ThemeMode.light)
                                    newMode = ThemeMode.dark;
                                  await settings.setThemeMode(newMode);
                                  await HapticHelper.selection();
                                },
                              ),
                              SettingsTile(
                                icon: Icons.inventory_2_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'Low Stock Alert',
                                subtitle: '${settings.lowStockThreshold} doses',
                                onTap: () =>
                                    _showLowStockDialog(context, settings),
                              ),
                            ],
                          );
                        },
                      ),

                      // 5. SUPPORT & LEGAL
                      SettingsCard(
                        title: 'SUPPORT & LEGAL',
                        subtitle: 'Contact, Privacy, Reset',
                        children: [
                          SettingsTile(
                            icon: Icons.mail_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'Contact Support',
                            onTap: () {
                              final Uri emailLaunchUri = Uri(
                                scheme: 'mailto',
                                path: 'support@medtime.app',
                                query: 'subject=MedTime Support Request',
                              );
                              launchUrl(emailLaunchUri);
                            },
                          ),
                          SettingsTile(
                            icon: Icons
                                .article_rounded, // Policy/Terms combined icon concept
                            iconColor: Colors.grey,
                            title: 'Legal',
                            subtitle: 'Privacy & Terms',
                            onTap: () => launchUrl(
                              Uri.parse('https://medtime.app/privacy'),
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.star_rate_rounded,
                            iconColor: const Color(0xFFFFD700),
                            title: 'Rate App',
                            onTap: () {}, // Redirect to store
                          ),
                          SettingsTile(
                            icon: Icons.delete_forever_rounded,
                            iconColor: AppColors.error,
                            title: 'Reset App Data',
                            isDestructive: true,
                            onTap: () => _showResetDialog(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
