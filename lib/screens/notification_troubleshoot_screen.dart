import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/notification_service.dart';
import '../core/theme/app_colors.dart';

class NotificationTroubleshootScreen extends StatefulWidget {
  const NotificationTroubleshootScreen({super.key});

  @override
  State<NotificationTroubleshootScreen> createState() => _NotificationTroubleshootScreenState();
}

class _NotificationTroubleshootScreenState extends State<NotificationTroubleshootScreen> {
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
    
    // Check permissions
    final notif = await Permission.notification.status;
    final alarm = await Permission.scheduleExactAlarm.status;
    final bat = await Permission.ignoreBatteryOptimizations.status; // status is misleading for this one
    
    // ignoreBatteryOptimizations status logic is tricky with permission_handler headers.
    // It's better to use isIgnoringBatteryOptimizations() directly if available or check status.
    // "Granted" means we are ignoring optimizations (which is GOOD).
    // Actually, "Permission.ignoreBatteryOptimizations.status" checks if we CAN request it or if it's granted.
    // Let's use the status for now. 
    
    final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;

    // Check manufacturer
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _manufacturer = androidInfo.manufacturer;
    }

    if (mounted) {
      setState(() {
        _notificationPermission = notif.isGranted;
        _exactAlarmPermission = alarm.isGranted;
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
      return '1. Go to Settings > Apps > MedTime\n2. Tap "Battery"\n3. Select "Unrestricted"';
    } else if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return '1. Go to Settings > Apps > MedTime\n2. Tap "Battery Saver"\n3. Select "No restrictions"\n4. Enable "Autostart"';
    } else if (m.contains('huawei')) {
      return '1. Go to Settings > Battery > App Launch\n2. Find MedTime\n3. Turn "Manage automatically" OFF\n4. Enable "Auto-launch" & "Run in background"';
    } else if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return '1. Long press MedTime icon > App Info\n2. Tap "Battery usage" > "Allow background activity"\n3. Enable "Allow auto launch"';
    }
    return 'Go to Settings > Apps > MedTime > Battery and verify "Background usage" is allowed and "Battery optimization" is NOT optimized.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                          medicineId: 99999,
                          medicineName: 'Test Reminder', 
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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
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
            isOk ? Icons.check_circle : (isCritical ? Icons.error : Icons.cancel),
            color: isOk ? Colors.green : (isCritical ? Colors.red : Colors.orange),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.red.shade700, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Battery Optimization is ON',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your phone may kill MedTime to save power, preventing reminders. Please disable optimization for this app.',
            style: TextStyle(color: Colors.red.shade800),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _requestBatteryOptimization,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.bolt, color: Colors.white),
              label: const Text('Disable Optimization'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    if (_manufacturer == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.only(left: 4, bottom: 8),
           child: Text(
            'Instructions for ${_manufacturer!.toUpperCase()}', 
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
           ),
         ),
        Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _getManufacturerAdvice(),
                    style: const TextStyle(height: 1.5),
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
