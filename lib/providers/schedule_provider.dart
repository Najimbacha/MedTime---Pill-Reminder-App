import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Provider for managing medicine schedules
class ScheduleProvider with ChangeNotifier {
  final DatabaseHelper _db;
  final NotificationService _notifications;

  ScheduleProvider({
    DatabaseHelper? db,
    NotificationService? notifications,
  })  : _db = db ?? DatabaseHelper.instance,
        _notifications = notifications ?? NotificationService.instance;

  List<Schedule> _schedules = [];
  bool _isLoading = false;

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;

  /// Get schedules for a specific medicine
  List<Schedule> getSchedulesForMedicine(int medicineId) {
    return _schedules.where((s) => s.medicineId == medicineId).toList();
  }

  /// Get today's active schedules
  List<Schedule> get todaySchedules {
    return _schedules.where((s) => s.shouldTriggerToday()).toList();
  }

  /// Load all schedules from database
  Future<void> loadSchedules() async {
    _isLoading = true;
    notifyListeners();

    try {
      _schedules = await _db.getAllSchedules();
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new schedule
  Future<Schedule?> addSchedule(Schedule schedule, Medicine medicine) async {
    try {
      final newSchedule = await _db.createSchedule(schedule);
      _schedules.add(newSchedule);
      
      // Schedule notification
      await _scheduleNotification(newSchedule, medicine);
      
      notifyListeners();
      return newSchedule;
    } catch (e) {
      debugPrint('Error adding schedule: $e');
      return null;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(Schedule schedule, Medicine medicine) async {
    try {
      await _db.updateSchedule(schedule);
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        _schedules[index] = schedule;
        
        // Reschedule notification
        await _scheduleNotification(schedule, medicine);
        
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating schedule: $e');
      return false;
    }
  }

  /// Delete a schedule
  Future<bool> deleteSchedule(int id) async {
    try {
      await _db.deleteSchedule(id);
      _schedules.removeWhere((s) => s.id == id);
      
      // Cancel notification
      await _notifications.cancelNotification(id);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
      return false;
    }
  }

  /// Schedule notification for a schedule
  Future<void> _scheduleNotification(Schedule schedule, Medicine medicine) async {
    final scheduledTime = schedule.getNextScheduledTime();
    if (scheduledTime == null || schedule.id == null) return;

    try {
      await _notifications.scheduleMedicineReminder(
        notificationId: schedule.id!,
        medicineId: medicine.id!,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        scheduledTime: scheduledTime,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Reschedule all notifications (useful after app restart)
  Future<void> rescheduleAllNotifications(List<Medicine> medicines) async {
    try {
      // Cancel all existing notifications
      await _notifications.cancelAllNotifications();

      // Reschedule all active schedules
      for (final schedule in todaySchedules) {
        final medicine = medicines.firstWhere(
          (m) => m.id == schedule.medicineId,
          orElse: () => Medicine(name: 'Unknown', dosage: ''),
        );
        
        await _scheduleNotification(schedule, medicine);
      }
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  /// Snooze a notification
  Future<void> snoozeNotification(Schedule schedule, Medicine medicine) async {
    if (schedule.id == null) return;

    try {
      await _notifications.snoozeNotification(
        notificationId: schedule.id!,
        medicineId: medicine.id!,
        medicineName: medicine.name,
        dosage: medicine.dosage,
      );
    } catch (e) {
      debugPrint('Error snoozing notification: $e');
    }
  }

  /// Calculate average daily dose count for a medicine
  double getDailyDoseCount(int medicineId) {
    final medSchedules = getSchedulesForMedicine(medicineId);
    if (medSchedules.isEmpty) return 0.0;

    double dailyCount = 0.0;
    for (final schedule in medSchedules) {
      switch (schedule.frequencyType) {
        case FrequencyType.daily:
          dailyCount += 1.0;
          break;
        case FrequencyType.specificDays:
          dailyCount += (schedule.daysList.length / 7.0);
          break;
        case FrequencyType.interval:
          if (schedule.intervalDays != null && schedule.intervalDays! > 0) {
            dailyCount += (1.0 / schedule.intervalDays!);
          }
          break;
        case FrequencyType.asNeeded:
          // Cannot predict
          break;
      }
    }
    return dailyCount;
  }

  /// Estimate refill date based on current stock and schedule
  DateTime? getEstimatedRefillDate(int medicineId, int currentStock) {
    final dailyDose = getDailyDoseCount(medicineId);
    if (dailyDose <= 0) return null;

    final daysRemaining = currentStock / dailyDose;
    return DateTime.now().add(Duration(days: daysRemaining.floor()));
  }

  /// Refresh schedules from database
  Future<void> refresh() async {
    await loadSchedules();
  }
}
