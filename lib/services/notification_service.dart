import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'database_helper.dart';
import '../models/log.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // handle action
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (payload != null && actionId != null) {
      final parts = payload.split('|');
      final medicineId = int.tryParse(parts[0]);
      
      if (medicineId != null) {
          if (actionId == 'snooze') {
             // Re-schedule for 10 min later
             final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
             
             // Initialize the plugin in background isolate
             const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
             const iosSettings = DarwinInitializationSettings();
             const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
             await flutterLocalNotificationsPlugin.initialize(initSettings);
             
             final now = DateTime.now();
             final scheduledTime = now.add(const Duration(minutes: 10)); // 10 minutes snooze

             // Need timezone initialization here since it's a background isolate
             tz.initializeTimeZones();
             
             String? name = parts.length > 1 ? parts[1] : 'Medicine';
             String? dosage = parts.length > 2 ? parts[2] : '';

             // Re-schedule
              const androidDetails = AndroidNotificationDetails(
                'medicine_reminders',
                'Medicine Reminders',
                channelDescription: 'Notifications for medicine reminders',
                importance: Importance.max,
                priority: Priority.max,
                playSound: true,
                enableVibration: true,
                fullScreenIntent: true,
                category: AndroidNotificationCategory.alarm,
                visibility: NotificationVisibility.public,
                actions: [
                    AndroidNotificationAction('take', 'Take', showsUserInterface: true),
                    AndroidNotificationAction('snooze', 'Snooze 10min', showsUserInterface: false),
                ],
              );
              
              const iosDetails = DarwinNotificationDetails(
                presentAlert: true, presentBadge: true, presentSound: true,
              );

              final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

              await flutterLocalNotificationsPlugin.zonedSchedule(
                medicineId, // Reuse ID
                'Time to take $name (Snoozed)',
                'Dosage: $dosage',
                tz.TZDateTime.from(scheduledTime, tz.local),
                details,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                payload: payload, // Keep same payload
              );
              
              print('✅ Snooze scheduled for $scheduledTime in background');

          } else if (actionId == 'take') {
              final db = DatabaseHelper.instance;

              // 1. Create Log Entry if scheduled time is available
              if (parts.length > 3) {
                final scheduledTimeStr = parts[3];
                try {
                  final scheduledTime = DateTime.parse(scheduledTimeStr);
                  
                  final log = Log(
                    medicineId: medicineId,
                    scheduledTime: scheduledTime,
                    actualTime: DateTime.now(),
                    status: LogStatus.take,
                  );
                  await db.createLog(log);
                  print('✅ Log created in background for medicine $medicineId');
                } catch (e) {
                  print('🔴 Error creating log in background: $e');
                }
              } else {
                  print('⚠️ No scheduled time in payload, cannot create log.');
              }

              // 2. Decrement stock
              final medicine = await db.getMedicine(medicineId);
              if (medicine != null) {
                 final newStock = medicine.currentStock - 1;
                 await db.updateMedicine(medicine.copyWith(
                    currentStock: newStock >= 0 ? newStock : 0
                 ));
                 
                 // Cancel notification
                 final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
                 await flutterLocalNotificationsPlugin.cancel(medicineId);
              }
          }
      }
  }
}

/// Singleton service for managing local notifications
/// Handles scheduling, actionable notifications, and callbacks
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Callback for when notification is tapped
  Function(int medicineId, String action, String? payload)? _onNotificationAction;
  
  // Storage for pending action if listener isn't ready
  Map<String, dynamic>? _pendingAction;

  set onNotificationAction(Function(int medicineId, String action, String? payload)? callback) {
    _onNotificationAction = callback;
    if (callback != null && _pendingAction != null) {
      // Execute pending action
      final id = _pendingAction!['id'];
      final action = _pendingAction!['action'];
      final payload = _pendingAction!['payload'];
      
      print('Executing pending notification action: $action for $id');
      callback(id, action, payload);
      _pendingAction = null;
    }
  }

  // Permission status
  bool _notificationsPermissionGranted = false;
  bool _exactAlarmsPermissionGranted = false;

  NotificationService._init();

  // Getters for permission status
  bool get notificationsPermissionGranted => _notificationsPermissionGranted;
  bool get exactAlarmsPermissionGranted => _exactAlarmsPermissionGranted;
  bool get allPermissionsGranted => 
      _notificationsPermissionGranted && _exactAlarmsPermissionGranted;

  /// Initialize notification service
  Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with callback for notification taps
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Permissions should be requested from UI, not during initialization
  }

  /// Request all required permissions
  Future<bool> requestAllPermissions() async {
    _notificationsPermissionGranted = await _requestNotificationsPermission();
    _exactAlarmsPermissionGranted = await _requestExactAlarmPermission();
    return allPermissionsGranted;
  }

  /// Request notification permissions (Android 13+)
  Future<bool> _requestNotificationsPermission() async {
    if (!Platform.isAndroid) {
      // iOS permissions are handled during initialization
      return true;
    }

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Request exact alarm permission (Android 12+)
  Future<bool> _requestExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
    }
    return true;
  }

  /// Check if exact alarms can be scheduled
  Future<bool> canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.canScheduleExactNotifications() ?? false;
      }
    }
    return true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload; 
    if (payload == null) return;

    // Payload can be "id" or "id|name|dosage|scheduledTime"
    final parts = payload.split('|');
    final medicineId = int.tryParse(parts[0]);
    if (medicineId == null) return;

    // Determine action from button ID, or default to 'view' if body tapped
    final action = response.actionId == 'take' ? 'take' 
                 : response.actionId == 'snooze' ? 'snooze' 
                 : 'view';

    if (_onNotificationAction != null) {
      _onNotificationAction!(medicineId, action, payload);
    } else {
      // Store pending action
      print('Storing pending notification action: $action for $medicineId');
      _pendingAction = {
        'id': medicineId,
        'action': action,
        'payload': payload,
      };
    }
  }

  /// Schedule a medicine reminder notification
  Future<void> scheduleMedicineReminder({
    required int notificationId,
    required int medicineId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    // Create notification details with actions and custom sound
    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: [
        const AndroidNotificationAction(
          'take',
          'Take',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze',
          'Snooze 10min',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'medicine_reminder',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alert.mp3',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule notification
    await _notifications.zonedSchedule(
      notificationId,
      'Time to take $medicineName',
      'Dosage: $dosage',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$medicineId|$medicineName|$dosage|${scheduledTime.toIso8601String()}',
    );
  }

  /// Show immediate notification (for testing or immediate reminders)
  Future<void> showImmediateNotification({
    required int notificationId,
    required int medicineId,
    required String medicineName,
    required String dosage,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: [
        const AndroidNotificationAction(
          'take',
          'Take',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze',
          'Snooze 10min',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'medicine_reminder',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alert.mp3',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      'Time to take $medicineName',
      'Dosage: $dosage',
      notificationDetails,
      payload: '$medicineId|$medicineName|$dosage|${DateTime.now().toIso8601String()}',
    );
  }

  /// Snooze notification (reschedule for 10 minutes later)
  Future<void> snoozeNotification({
    required int notificationId,
    required int medicineId,
    required String medicineName,
    required String dosage,
  }) async {
    // Cancel current notification
    await cancelNotification(notificationId);

    // Reschedule for 10 minutes from now
    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    
    await scheduleMedicineReminder(
      notificationId: notificationId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      scheduledTime: snoozeTime,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Show low stock alert
  Future<void> showLowStockAlert({
    required int medicineId,
    required String medicineName,
    required int currentStock,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'low_stock_alerts',
      'Low Stock Alerts',
      channelDescription: 'Alerts when medicine stock is low',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      medicineId + 10000, // Offset to avoid conflicts with reminder IDs
      'Low Stock: $medicineName',
      'Only $currentStock ${currentStock == 1 ? 'dose' : 'doses'} remaining. Time to refill!',
      notificationDetails,
    );
  }

  /// Schedule a refill reminder for a future date
  Future<void> scheduleRefillReminder({
    required int medicineId,
    required String medicineName,
    required DateTime refillDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'refill_reminders',
      'Refill Reminders',
      channelDescription: 'Reminders when it is time to refill medicine',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for 10:00 AM on the refill date
    final scheduledTime = DateTime(
      refillDate.year,
      refillDate.month,
      refillDate.day,
      10,
      0,
    );

    // If already passed, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      medicineId + 20000, // Different offset for refill reminders
      'Refill Reminder: $medicineName',
      'You are estimated to run out of $medicineName today. Time for a refill!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
