import 'package:flutter/material.dart';
import '../models/snoozed_dose.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Provider for managing snoozed doses
/// Handles snooze creation, cancellation, and notification scheduling
class SnoozeProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notificationService = NotificationService.instance;

  /// Map of snoozed doses keyed by "${medicineId}_${originalScheduledTime.toIso8601String()}"
  final Map<String, SnoozedDose> _snoozedDoses = {};

  /// Get all active snoozed doses
  List<SnoozedDose> get snoozedDoses => _snoozedDoses.values.toList();

  /// Initialize provider - load snoozed doses from database
  Future<void> initialize() async {
    await _loadSnoozedDoses();
    await _cleanupExpiredSnoozes();
  }

  /// Load snoozed doses from database
  Future<void> _loadSnoozedDoses() async {
    final doses = await _db.getActiveSnoozedDoses();
    _snoozedDoses.clear();
    for (final dose in doses) {
      _snoozedDoses[_key(dose.medicineId, dose.originalScheduledTime)] = dose;
    }
    notifyListeners();
  }

  /// Create a key for the snooze map
  String _key(int medicineId, DateTime scheduledTime) {
    return '${medicineId}_${scheduledTime.toIso8601String()}';
  }

  /// Snooze a dose for a specified number of minutes
  Future<void> snoozeDose({
    required int medicineId,
    required String medicineName,
    required DateTime originalScheduledTime,
    required int minutes,
  }) async {
    final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));

    final dose = SnoozedDose(
      medicineId: medicineId,
      originalScheduledTime: originalScheduledTime,
      snoozedUntil: snoozedUntil,
    );

    // Save to database
    await _db.createSnoozedDose(dose);

    // Add to local cache
    _snoozedDoses[_key(medicineId, originalScheduledTime)] = dose;

    // Schedule snooze notification (wrapped in try-catch to not block UI update)
    try {
      await _scheduleSnoozeNotification(
        medicineId: medicineId,
        medicineName: medicineName,
        snoozedUntil: snoozedUntil,
        originalScheduledTime: originalScheduledTime,
      );
    } catch (e) {
      debugPrint('⚠️ SnoozeProvider: Failed to schedule notification: $e');
    }

    debugPrint(
      '🔔 SnoozeProvider: Snooze added for medicine $medicineId, notifying listeners...',
    );
    notifyListeners();
  }

  /// Cancel a snooze
  Future<void> cancelSnooze({
    required int medicineId,
    required DateTime originalScheduledTime,
  }) async {
    final key = _key(medicineId, originalScheduledTime);

    // Remove from database
    await _db.deleteSnoozedDose(medicineId, originalScheduledTime);

    // Remove from local cache
    _snoozedDoses.remove(key);

    // Cancel the snooze notification
    final notificationId = _getSnoozeNotificationId(
      medicineId,
      originalScheduledTime,
    );
    await _notificationService.cancelNotification(notificationId);

    notifyListeners();
  }

  /// Check if a dose is snoozed
  bool isSnoozed(int medicineId, DateTime scheduledTime) {
    final key = _key(medicineId, scheduledTime);
    final dose = _snoozedDoses[key];
    if (dose == null) return false;
    // Check if snooze is still active
    if (dose.isExpired) {
      _snoozedDoses.remove(key);
      return false;
    }
    return true;
  }

  /// Get the snoozed time for a dose (if snoozed)
  DateTime? getSnoozedTimeFor(int medicineId, DateTime scheduledTime) {
    final key = _key(medicineId, scheduledTime);
    final dose = _snoozedDoses[key];
    if (dose == null || dose.isExpired) return null;
    return dose.snoozedUntil;
  }

  /// Get SnoozedDose object if exists
  SnoozedDose? getSnooze(int medicineId, DateTime scheduledTime) {
    final key = _key(medicineId, scheduledTime);
    return _snoozedDoses[key];
  }

  /// Schedule a notification for snoozed dose
  Future<void> _scheduleSnoozeNotification({
    required int medicineId,
    required String medicineName,
    required DateTime snoozedUntil,
    required DateTime originalScheduledTime,
  }) async {
    final notificationId = _getSnoozeNotificationId(
      medicineId,
      originalScheduledTime,
    );

    await _notificationService.scheduleMedicineReminder(
      notificationId: notificationId,
      medicineId: medicineId,
      medicineName: '⏰ $medicineName (Snoozed)',
      dosage: 'Time to take your snoozed dose!',
      scheduledTime: snoozedUntil,
    );
  }

  /// Generate unique notification ID for snooze
  int _getSnoozeNotificationId(int medicineId, DateTime scheduledTime) {
    // Use a high base to avoid collision with regular notification IDs
    // Format: 900000 + medicineId * 1000 + (hour * 60 + minute)
    return 900000 +
        (medicineId * 1000) +
        (scheduledTime.hour * 60 + scheduledTime.minute);
  }

  /// Clean up expired snoozes
  Future<void> _cleanupExpiredSnoozes() async {
    await _db.clearExpiredSnoozedDoses();

    // Also clean local cache
    final expiredKeys = <String>[];
    _snoozedDoses.forEach((key, dose) {
      if (dose.isExpired) {
        expiredKeys.add(key);
      }
    });
    for (final key in expiredKeys) {
      _snoozedDoses.remove(key);
    }
  }

  /// Reload snoozes from database
  Future<void> refresh() async {
    await _loadSnoozedDoses();
  }
}
