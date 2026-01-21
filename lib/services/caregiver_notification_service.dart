import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/user_profile.dart';

class CaregiverNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Singleton
  static final CaregiverNotificationService _instance = CaregiverNotificationService._internal();
  factory CaregiverNotificationService() => _instance;
  CaregiverNotificationService._internal();

  /// Initialize FCM and Local Notifications
  Future<void> initialize() async {
    try {
      // 1. Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 FCM Permission: ${settings.authorizationStatus}');

      // 2. Get APNS token (iOS)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _fcm.getAPNSToken();
        debugPrint('🍎 APNS Token: $apnsToken');
      }

      // 3. Get FCM token
      final fcmToken = await _fcm.getToken();
      debugPrint('🔥 FCM Token: $fcmToken');
      
      // 4. Update token in Firestore if user is logged in
      // (This should also be called from AuthProvider on login)
      
      // 5. Setup Foreground listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // 6. Setup Background/Terminated handler (top-level function required, see main.dart)
      
      // 7. Initialize Local Notifications for foreground display
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(initializationSettings);

    } catch (e) {
      debugPrint('❌ Error initializing CaregiverNotificationService: $e');
    }
  }

  /// Handle messages received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground Message received: ${message.notification?.title}');
    
    // Show local notification
    if (message.notification != null) {
      _showLocalNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'New Alert',
        body: message.notification!.body ?? '',
      );
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'caregiver_alerts',
      'Caregiver Alerts',
      channelDescription: 'Notifications for missed doses and urgent alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(id, title, body, details);
  }

  /// Save the current FCM token to the user's profile
  Future<void> updateToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM Token updated for user $userId');
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

  /// Create a notification request in Firestore
  /// (This assumes a Cloud Function triggers the actual FCM send)
  Future<void> sendMissedDoseAlert({
    required String patientName,
    required String medicineName,
    required List<String> caregiverIds,
  }) async {
    if (caregiverIds.isEmpty) return;

    try {
      // Create a notification document for each caregiver
      // Or a single document that fan-outs
      
      final batch = _firestore.batch();
      
      for (final caregiverId in caregiverIds) {
        final docRef = _firestore.collection('notifications').doc();
        
        batch.set(docRef, {
          'recipientId': caregiverId,
          'type': 'missed_dose',
          'title': 'Missed Dose Alert',
          'body': '$patientName missed their dose of $medicineName',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'priority': 'high',
            'patientName': patientName,
            'medicineName': medicineName,
          }
        });
      }

      await batch.commit();
      debugPrint('🚀 Notification requests sent to ${caregiverIds.length} caregivers');

    } catch (e) {
      debugPrint('❌ Error sending missed dose alert: $e');
    }
  }

  /// Send Low Stock Alert
  Future<void> sendLowStockAlert({
    required String patientName,
    required String medicineName,
    required int remainingCount,
    required List<String> caregiverIds,
  }) async {
     if (caregiverIds.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final caregiverId in caregiverIds) {
        final docRef = _firestore.collection('notifications').doc();
        
        batch.set(docRef, {
          'recipientId': caregiverId,
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'body': '$patientName is running low on $medicineName ($remainingCount remaining)',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await batch.commit();
      debugPrint('🚀 Low Stock alerts sent');

    } catch (e) {
      debugPrint('❌ Error sending low stock alert: $e');
    }
  }
}
