import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/log_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/haptic_helper.dart';
import '../services/backup_service.dart';
import '../services/report_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/settings_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/subscription_provider.dart';
import 'paywall_screen.dart';
import 'auth_screen.dart';
import 'invite_caregiver_screen.dart';
import 'caregiver_dashboard_screen.dart';

import 'statistics_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
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
      return subscription.isPremium;
    }
    return true;
  }

  // ─── Dialogs ─────────────────────────────────────────────

  void _showResetDialog(BuildContext context) {
    _showPremiumDialog(
      context: context,
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.error,
      title: 'Reset App Data?',
      message:
          'This will permanently delete all your medicines, schedules, and logs. This action cannot be undone.',
      confirmLabel: 'Reset Everything',
      confirmColor: AppColors.error,
      onConfirm: () => _performReset(),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    _showPremiumDialog(
      context: context,
      icon: Icons.person_off_rounded,
      iconColor: AppColors.error,
      title: 'Delete Account?',
      message:
          'This will permanently delete your cloud account and all family sharing links. Your local data will remain.',
      confirmLabel: 'Delete Account',
      confirmColor: AppColors.error,
      onConfirm: () async {
        await auth.deleteAccount();
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider auth) {
    _showPremiumDialog(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Sign Out?',
      message: 'You can always sign back in to sync your data across devices.',
      confirmLabel: 'Sign Out',
      confirmColor: const Color(0xFF6366F1),
      onConfirm: () async {
        await auth.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed out successfully')),
          );
        }
      },
    );
  }

  void _showLowStockDialog(BuildContext context, SettingsService settings) {
    final controller = TextEditingController(
      text: settings.lowStockThreshold.toString(),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BottomSheetContainer(
          isDark: isDark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(isDark: isDark),
              const SizedBox(height: 8),
              Text(
                'Low Stock Alert',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Alert when doses remaining fall below:',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  suffixText: 'doses',
                  suffixStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SheetPrimaryButton(
                label: 'Save',
                onTap: () {
                  final val = int.tryParse(controller.text);
                  if (val != null && val >= 0)
                    settings.setLowStockThreshold(val);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _SheetSecondaryButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(ctx),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackupSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheetContainer(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(isDark: isDark),
            const SizedBox(height: 8),
            Text(
              'Backup & Restore',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _BackupOption(
              icon: Icons.cloud_upload_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Export Backup',
              subtitle: 'Save an encrypted copy of your data',
              isDark: isDark,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await BackupService().createEncryptedBackup();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 12),
            _BackupOption(
              icon: Icons.restore_rounded,
              color: const Color(0xFF10B981),
              title: 'Import Backup',
              subtitle: 'Restore from a previous backup file',
              isDark: isDark,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await BackupService().restoreFromBackup();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restored successfully')),
                    );
                  }
                } catch (_) {}
              },
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _BottomSheetContainer(
          isDark: isDark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(isDark: isDark),
              const SizedBox(height: 4),
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: auth.firebaseUser?.photoURL != null
                      ? Image.network(
                          auth.firebaseUser!.photoURL!,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            (auth.userProfile?.displayName ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                auth.userProfile?.displayName ?? 'User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              if (auth.firebaseUser?.email != null)
                Text(
                  auth.firebaseUser!.email!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              const SizedBox(height: 32),

              // Sign out
              _SheetPrimaryButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSignOutDialog(context, auth);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountDialog(context, auth);
                },
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white30
                        : Colors.black.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performReset() async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteAllData();
      if (mounted) {
        final medProvider = Provider.of<MedicineProvider>(
          context,
          listen: false,
        );
        for (var med in medProvider.medicines) {
          if (med.id != null) await medProvider.deleteMedicine(med.id!);
        }
        await Provider.of<LogProvider>(context, listen: false).clearAllLogs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App data reset successfully')),
        );
      }
    } catch (e) {
      debugPrint('Reset error: $e');
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating report…')));
    try {
      final medProvider = Provider.of<MedicineProvider>(context, listen: false);
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final medicines = medProvider.medicines;
      final logs = logProvider.logs;
      final medicineNames = {for (var m in medicines) m.id!: m.name};
      await ReportService().generateAndShareReport(
        medicines: medicines,
        overallAdherence: 95.0,
        streak: 12,
        recentLogs: logs,
        medicineNames: medicineNames,
        patientName: authProvider.userProfile?.displayName ?? 'Patient',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Generic styled modal ──────────────────────────────────
  void _showPremiumDialog({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheetContainer(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(isDark: isDark),
            const SizedBox(height: 8),

            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onConfirm();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _SheetSecondaryButton(
              label: 'Cancel',
              onTap: () => Navigator.pop(ctx),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF2F2F7),
      body: Consumer3<AuthProvider, SubscriptionProvider, SettingsService>(
        builder: (context, auth, subscription, settings, _) {
          final name =
              auth.userProfile?.displayName ?? auth.firebaseUser?.displayName;
          final email = auth.firebaseUser?.email;
          final photoUrl = auth.firebaseUser?.photoURL;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── AppBar ──────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                centerTitle: true,
              ),

              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // ── Profile Hero ────────────────────────
                  SettingsHeader(
                    name: name,
                    email: email,
                    photoUrl: photoUrl,
                    isPremium: subscription.isPremium,
                    isSignedIn: auth.isSignedIn,
                    onTap: auth.isSignedIn
                        ? () => _showProfileSheet(context, auth)
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                          ),
                  ),

                  const SizedBox(height: 28),

                  // ── Quick Actions ───────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        QuickActionCard(
                          title: 'Share Report',
                          subtitle: 'PDF Health Summary',
                          icon: Icons.summarize_rounded,
                          gradientColors: const [
                            Color(0xFF6366F1),
                            Color(0xFF818CF8),
                          ],
                          badge: subscription.isPremium
                              ? null
                              : const StatusBadge(
                                  label: 'PRO',
                                  color: Color(0xFFFFD700),
                                  outline: true,
                                ),
                          onTap: () async {
                            if (await _checkPremium(context)) {
                              await _generateReport(context);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        QuickActionCard(
                          title: 'Family Care',
                          subtitle: 'Monitor loved ones',
                          icon: Icons.health_and_safety_rounded,
                          gradientColors: const [
                            Color(0xFFEC4899),
                            Color(0xFFF472B6),
                          ],
                          badge: subscription.isPremium
                              ? null
                              : const StatusBadge(
                                  label: 'PRO',
                                  color: Color(0xFFFFD700),
                                  outline: true,
                                ),
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

                  // ── Subscription ───────────────────────
                  const SettingsSectionLabel(
                    title: 'Subscription',
                    icon: Icons.star_rounded,
                  ),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: subscription.isPremium
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        iconColor: const Color(0xFFFFD700),
                        title: subscription.isPremium
                            ? 'MedTime Premium'
                            : 'Upgrade to Premium',
                        subtitle: subscription.isPremium
                            ? 'Active — thank you!'
                            : 'Unlock all features',
                        trailing: subscription.isPremium
                            ? const StatusBadge(
                                label: 'ACTIVE',
                                color: Color(0xFF10B981),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFA500),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Upgrade',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                        showChevron: false,
                        onTap: subscription.isPremium
                            ? null
                            : () => _checkPremium(context),
                      ),
                      SettingsTile(
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Health Dashboard',
                        subtitle: 'Adherence & statistics',
                        trailing: subscription.isPremium
                            ? null
                            : const StatusBadge(
                                label: 'PRO',
                                color: Color(0xFF8B5CF6),
                              ),
                        onTap: () async {
                          if (await _checkPremium(context)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatisticsScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  // ── App Settings ───────────────────────
                  const SettingsSectionLabel(
                    title: 'App Settings',
                    icon: Icons.tune_rounded,
                  ),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: Icons.dark_mode_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Appearance',
                        subtitle: () {
                          switch (settings.themeMode) {
                            case ThemeMode.dark:
                              return 'Dark';
                            case ThemeMode.light:
                              return 'Light';
                            default:
                              return 'System Default';
                          }
                        }(),
                        trailing: _ThemeSelectorWidget(
                          current: settings.themeMode,
                          isDark: isDark,
                          onChange: (mode) async {
                            await settings.setThemeMode(mode);
                            await HapticHelper.selection();
                          },
                        ),
                        showChevron: false,
                        onTap: null,
                      ),
                      SettingsTile(
                        icon: Icons.inventory_2_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Low Stock Alert',
                        subtitle:
                            'Warn at ${settings.lowStockThreshold} doses remaining',
                        onTap: () => _showLowStockDialog(context, settings),
                      ),
                      SettingsTile(
                        icon: Icons.cloud_upload_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Backup & Restore',
                        subtitle: 'Encrypted local backup',
                        trailing: subscription.isPremium
                            ? null
                            : const StatusBadge(
                                label: 'PRO',
                                color: Color(0xFF3B82F6),
                              ),
                        onTap: () async {
                          if (await _checkPremium(context)) {
                            _showBackupSheet(context);
                          }
                        },
                      ),
                    ],
                  ),

                  // ── Family ─────────────────────────────
                  const SettingsSectionLabel(
                    title: 'Family',
                    icon: Icons.people_rounded,
                  ),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: Icons.family_restroom_rounded,
                        iconColor: const Color(0xFFEC4899),
                        title: 'Family Sharing',
                        subtitle: auth.isSignedIn
                            ? 'Manage caregivers & patients'
                            : 'Sign in to access',
                        onTap: () async {
                          if (!auth.isSignedIn) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          } else if (await _checkPremium(context)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    auth.userProfile?.isCaregiver == true
                                    ? const CaregiverDashboardScreen()
                                    : const InviteCaregiverScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      SettingsTile(
                        icon: Icons.qr_code_scanner_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Accept Invite',
                        subtitle: 'Join a family care circle',
                        onTap: () async {
                          if (!auth.isSignedIn) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  // ── Support ────────────────────────────
                  const SettingsSectionLabel(
                    title: 'Support & Legal',
                    icon: Icons.help_outline_rounded,
                  ),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: Icons.mail_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Contact Support',
                        subtitle: 'support@medtime.app',
                        onTap: () => launchUrl(
                          Uri(
                            scheme: 'mailto',
                            path: 'support@medtime.app',
                            query: 'subject=MedTime Support Request',
                          ),
                        ),
                      ),

                      SettingsTile(
                        icon: Icons.article_rounded,
                        iconColor: Colors.blueGrey,
                        title: 'Privacy & Terms',
                        onTap: () =>
                            launchUrl(Uri.parse('https://medtime.app/privacy')),
                      ),
                    ],
                  ),

                  // ── Danger Zone ────────────────────────
                  const SettingsSectionLabel(
                    title: 'Danger Zone',
                    icon: Icons.warning_amber_rounded,
                  ),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: Icons.delete_forever_rounded,
                        iconColor: AppColors.error,
                        title: 'Reset App Data',
                        subtitle: 'Permanently delete all local data',
                        isDestructive: true,
                        showChevron: false,
                        onTap: () => _showResetDialog(context),
                      ),
                      if (auth.isSignedIn)
                        SettingsTile(
                          icon: Icons.person_off_rounded,
                          iconColor: AppColors.error,
                          title: 'Delete Account',
                          subtitle: 'Remove cloud account permanently',
                          isDestructive: true,
                          showChevron: false,
                          onTap: () => _showDeleteAccountDialog(context, auth),
                        ),
                    ],
                  ),

                  // ── Footer ─────────────────────────────
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                size: 14,
                                color: AppColors.primary.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MedTime  v1.0.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black.withOpacity(0.3),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Made with ❤️ for your health',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// THEME SELECTOR — inline segmented control
// ──────────────────────────────────────────────────────────
class _ThemeSelectorWidget extends StatelessWidget {
  final ThemeMode current;
  final bool isDark;
  final ValueChanged<ThemeMode> onChange;

  const _ThemeSelectorWidget({
    required this.current,
    required this.isDark,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeChip(
          icon: Icons.brightness_auto_rounded,
          mode: ThemeMode.system,
          selected: current == ThemeMode.system,
          isDark: isDark,
          onTap: () => onChange(ThemeMode.system),
        ),
        const SizedBox(width: 4),
        _ThemeChip(
          icon: Icons.light_mode_rounded,
          mode: ThemeMode.light,
          selected: current == ThemeMode.light,
          isDark: isDark,
          onTap: () => onChange(ThemeMode.light),
        ),
        const SizedBox(width: 4),
        _ThemeChip(
          icon: Icons.dark_mode_rounded,
          mode: ThemeMode.dark,
          selected: current == ThemeMode.dark,
          isDark: isDark,
          onTap: () => onChange(ThemeMode.dark),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final ThemeMode mode;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.icon,
    required this.mode,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? AppColors.primary
              : (isDark ? Colors.white38 : Colors.black38),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// BOTTOM SHEET HELPERS
// ──────────────────────────────────────────────────────────
class _BottomSheetContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _BottomSheetContainer({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final bool isDark;
  const _SheetHandle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _SheetPrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SheetSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _SheetSecondaryButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ),
    );
  }
}

class _BackupOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _BackupOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black.withOpacity(0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
