import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/notification_service.dart';

class NotificationTroubleshootScreen extends StatefulWidget {
  const NotificationTroubleshootScreen({super.key});

  @override
  State<NotificationTroubleshootScreen> createState() =>
      _NotificationTroubleshootScreenState();
}

class _NotificationTroubleshootScreenState
    extends State<NotificationTroubleshootScreen> {
  bool _notificationPermission = false;
  bool _exactAlarmPermission = false;
  bool _isIgnoringBatteryOptimizations = false;
  String? _manufacturer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);

    var notifGranted = false;
    var exactAlarmGranted = true;
    var isIgnoring = true;

    try {
      notifGranted = (await Permission.notification.status).isGranted;
    } catch (_) {
      notifGranted = true;
    }

    if (Platform.isAndroid) {
      try {
        exactAlarmGranted =
            (await Permission.scheduleExactAlarm.status).isGranted;
      } catch (_) {
        exactAlarmGranted = false;
      }

      try {
        isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
      } catch (_) {
        isIgnoring = false;
      }
    }

    // Check manufacturer
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _manufacturer = androidInfo.manufacturer;
    }

    if (mounted) {
      setState(() {
        _notificationPermission = notifGranted;
        _exactAlarmPermission = exactAlarmGranted;
        _isIgnoringBatteryOptimizations = isIgnoring;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
    // Wait a bit for user to return
    await Future.delayed(const Duration(seconds: 1));
    await _checkStatus();
  }

  String _getManufacturerAdvice() {
    final m = _manufacturer?.toLowerCase() ?? '';
    if (m.contains('samsung')) {
      return '1. Go to Settings > Apps > RoutineTime\n2. Tap "Battery"\n3. Select "Unrestricted"';
    } else if (m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('poco')) {
      return '1. Go to Settings > Apps > RoutineTime\n2. Tap "Battery Saver"\n3. Select "No restrictions"\n4. Enable "Autostart"';
    } else if (m.contains('huawei')) {
      return '1. Go to Settings > Battery > App Launch\n2. Find RoutineTime\n3. Turn "Manage automatically" OFF\n4. Enable "Auto-launch" & "Run in background"';
    } else if (m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus')) {
      return '1. Long press RoutineTime icon > App Info\n2. Tap "Battery usage" > "Allow background activity"\n3. Enable "Allow auto launch"';
    }
    return 'Go to Settings > Apps > RoutineTime > Battery and verify "Background usage" is allowed and "Battery optimization" is NOT optimized.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Notification Help')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                      Icon(
                        Icons.notifications_active_outlined,
                        color: colorScheme.onPrimaryContainer,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'RoutineTime needs notification and alarm access to remind you on time.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusCard(),
                const SizedBox(height: 24),
                if (!_isIgnoringBatteryOptimizations) ...[
                  _buildBatteryActionCard(),
                  const SizedBox(height: 24),
                ],
                _buildInstructionsCard(),
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      NotificationService.instance.showImmediateNotification(
                        notificationId: 99999,
                        routineId: 99999,
                        routineName: 'Test Reminder',
                        dosage: 'Test',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification sent')),
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Send Test Notification'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCheckItem('Notification Permission', _notificationPermission),
            const Divider(),
            _buildCheckItem('Exact Alarm Permission', _exactAlarmPermission),
            const Divider(),
            _buildCheckItem(
              'Battery Exempt (Unrestricted)',
              _isIgnoringBatteryOptimizations,
              isCritical: !_isIgnoringBatteryOptimizations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String title, bool isOk, {bool isCritical = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isOk
                ? Icons.check_circle_rounded
                : (isCritical
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded),
            color: isOk
                ? Theme.of(context).colorScheme.primary
                : (isCritical
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.tertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (!isOk)
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Fix'),
            ),
        ],
      ),
    );
  }

  Widget _buildBatteryActionCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.battery_alert_outlined,
                color: colorScheme.onErrorContainer,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Battery Optimization is ON',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your phone may kill RoutineTime to save power, preventing reminders. Please disable optimization for this app.',
            style: TextStyle(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _requestBatteryOptimization,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.bolt),
              label: const Text('Disable Optimization'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    if (_manufacturer == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Instructions for ${_manufacturer!.toUpperCase()}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _getManufacturerAdvice(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
