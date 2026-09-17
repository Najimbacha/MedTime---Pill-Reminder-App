import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../models/routine.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Provider for managing routine schedules
class ScheduleProvider with ChangeNotifier {
  final DatabaseHelper _db;
  final NotificationService _notifications;

  ScheduleProvider({DatabaseHelper? db, NotificationService? notifications})
    : _db = db ?? DatabaseHelper.instance,
      _notifications = notifications ?? NotificationService.instance;

  List<Schedule> _schedules = [];
  bool _isLoading = false;
  bool _isRescheduling = false;
  DateTime? _lastRescheduleAt;

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;

  /// Get schedules for a specific routine
  List<Schedule> getSchedulesForRoutine(int routineId) {
    return _schedules.where((s) => s.routineId == routineId).toList();
  }

  /// Get today's active schedules
  List<Schedule> get todaySchedules {
    return getSchedulesForDate(DateTime.now());
  }

  /// Get schedules for a specific date
  List<Schedule> getSchedulesForDate(DateTime date) {
    return _schedules.where((s) => s.shouldTriggerOnDate(date)).toList();
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
  Future<Schedule?> addSchedule(Schedule schedule, Routine routine) async {
    try {
      final newSchedule = await _db.createSchedule(schedule);
      _schedules.add(newSchedule);

      // Schedule notification
      await _scheduleNotification(newSchedule, routine);

      notifyListeners();
      return newSchedule;
    } catch (e) {
      debugPrint('Error adding schedule: $e');
      return null;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(Schedule schedule, Routine routine) async {
    try {
      final previousSchedule = _schedules.firstWhere(
        (s) => s.id == schedule.id,
        orElse: () => schedule,
      );

      await _db.updateSchedule(schedule);
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        _schedules[index] = schedule;

        // Cancel before re-scheduling to avoid ghost notifications.
        await _cancelNotificationForSchedule(previousSchedule);

        // Reschedule notification
        await _scheduleNotification(schedule, routine);

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
      final schedule = _schedules.firstWhere(
        (s) => s.id == id,
        orElse: () => Schedule(
          id: id,
          routineId: -1,
          timeOfDay: '00:00',
          frequencyType: FrequencyType.daily,
        ),
      );
      await _db.deleteSchedule(id);
      _schedules.removeWhere((s) => s.id == id);

      // Cancel notification
      await _cancelNotificationForSchedule(schedule);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
      return false;
    }
  }

  /// Replace all schedules for a routine with a new set (Batch Operation)
  Future<void> replaceSchedulesForRoutine(
    int routineId,
    List<Schedule> newSchedules,
    Routine routine,
  ) async {
    try {
      // 1. Get existing schedules to cancel notifications
      final existingSchedules = getSchedulesForRoutine(routineId);
      for (final s in existingSchedules) {
        await _cancelNotificationForSchedule(s);
      }

      // 2. Delete from DB
      await _db.deleteSchedulesForRoutine(routineId);
      _schedules.removeWhere((s) => s.routineId == routineId);

      // 3. Create and add new schedules
      for (var schedule in newSchedules) {
        final created = await _db.createSchedule(schedule);
        _schedules.add(created);

        // 4. Schedule new notification
        await _scheduleNotification(created, routine);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error replacing schedules: $e');
    }
  }

  /// Schedule notification for a schedule
  Future<void> _scheduleNotification(
    Schedule schedule,
    Routine routine,
  ) async {
    if (schedule.id == null || routine.id == null) return;

    try {
      if (schedule.frequencyType == FrequencyType.specificDays &&
          schedule.daysList.isNotEmpty) {
        for (final weekday in schedule.daysList) {
          final nextTime = _nextSpecificWeekdayTime(schedule, weekday);
          if (nextTime == null) continue;

          await _notifications.scheduleRoutineReminder(
            notificationId: NotificationService.specificDayNotificationId(
              schedule.id!,
              weekday,
            ),
            routineId: routine.id!,
            routineName: routine.name,
            dosage: routine.dosage,
            scheduledTime: nextTime,
            frequencyType: FrequencyType.specificDays,
          );
        }
        return;
      }

      final scheduledTime = schedule.getNextScheduledTime();
      if (scheduledTime == null) return;

      await _notifications.scheduleRoutineReminder(
        notificationId: schedule.id!,
        routineId: routine.id!,
        routineName: routine.name,
        dosage: routine.dosage,
        scheduledTime: scheduledTime,
        frequencyType: schedule.frequencyType, // ← enables auto-repeat
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> _cancelNotificationForSchedule(Schedule schedule) async {
    if (schedule.id == null) return;
    await _notifications.cancelScheduleNotifications(
      baseNotificationId: schedule.id!,
      frequencyType: schedule.frequencyType,
      specificDays: schedule.daysList,
    );
  }

  DateTime? _nextSpecificWeekdayTime(Schedule schedule, int weekday) {
    final now = DateTime.now();
    final parts = schedule.timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    for (var i = 0; i <= 370; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: i));
      if (date.weekday != weekday) continue;

      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (!candidate.isAfter(now)) continue;
      if (!schedule.shouldTriggerOnDate(candidate)) continue;
      return candidate;
    }

    return null;
  }

  /// Reschedule all notifications (useful after app restart)
  Future<void> rescheduleAllNotifications(List<Routine> routines) async {
    // Prevent burst calls from re-canceling/recreating alarms repeatedly.
    if (_isRescheduling) return;
    final now = DateTime.now();
    if (_lastRescheduleAt != null &&
        now.difference(_lastRescheduleAt!) < const Duration(seconds: 30)) {
      return;
    }

    _isRescheduling = true;
    try {
      // Cancel all existing notifications
      await _notifications.cancelAllNotifications();

      // Reschedule ALL active schedules (not just today's — daily/interval
      // schedules with matchDateTimeComponents handle their own repeats)
      for (final schedule in _schedules) {
        final routine = routines.firstWhere(
          (m) => m.id == schedule.routineId,
          orElse: () => Routine(name: 'Unknown', dosage: ''),
        );

        await _scheduleNotification(schedule, routine);
      }
      _lastRescheduleAt = now;
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    } finally {
      _isRescheduling = false;
    }
  }

  /// Snooze a notification
  Future<void> snoozeNotification(Schedule schedule, Routine routine) async {
    if (schedule.id == null) return;

    try {
      await _notifications.snoozeNotification(
        notificationId: schedule.id!,
        routineId: routine.id!,
        routineName: routine.name,
        dosage: routine.dosage,
      );
    } catch (e) {
      debugPrint('Error snoozing notification: $e');
    }
  }

  /// Refresh schedules from database
  Future<void> refresh() async {
    await loadSchedules();
  }
}
