import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

/// Singleton service for managing local notifications
/// Handles scheduling, actionable notifications, and callbacks
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Callback for when notification is tapped
  Function(int medicineId, String action)? onNotificationAction;

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
    );

    // Request permissions
    await requestAllPermissions();
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

    // Parse payload: "medicineId:action"
    final parts = payload.split(':');
    if (parts.length == 2) {
      final medicineId = int.tryParse(parts[0]);
      final action = parts[1]; // "take" or "snooze"
      
      if (medicineId != null && onNotificationAction != null) {
        onNotificationAction!(medicineId, action);
      }
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
      payload: '$medicineId:take',
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
      payload: '$medicineId:take',
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
