// Mock implementations for testing
// Provides mock versions of DatabaseHelper and NotificationService

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:routine_time/models/routine.dart';
import 'package:routine_time/models/schedule.dart';
import 'package:routine_time/models/log.dart';
import 'package:routine_time/models/snoozed_dose.dart';
import 'package:routine_time/services/database_helper.dart';
import 'package:routine_time/services/notification_service.dart';

// Mock implementation of DatabaseHelper for testing
class MockDatabaseHelper implements DatabaseHelper {
  final List<Routine> _routines = [];
  final List<Schedule> _schedules = [];
  final List<Log> _logs = [];
  final List<SnoozedDose> _snoozedDoses = [];
  int _routineIdCounter = 1;
  int _scheduleIdCounter = 1;
  int _logIdCounter = 1;
  int _snoozedDoseIdCounter = 1;

  /// Clear all mock data
  void reset() {
    _routines.clear();
    _schedules.clear();
    _logs.clear();
    _snoozedDoses.clear();
    _routineIdCounter = 1;
    _scheduleIdCounter = 1;
    _logIdCounter = 1;
    _snoozedDoseIdCounter = 1;
  }

  // ==================== Routine CRUD ====================

  @override
  Future<Routine> createRoutine(Routine routine) async {
    final newRoutine = routine.copyWith(id: _routineIdCounter++);
    _routines.add(newRoutine);
    return newRoutine;
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    return List.from(_routines);
  }

  @override
  Future<Routine?> getRoutine(int id) async {
    try {
      return _routines.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> updateRoutine(Routine routine) async {
    final index = _routines.indexWhere((m) => m.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteRoutine(int id) async {
    _routines.removeWhere((m) => m.id == id);
    _schedules.removeWhere((s) => s.routineId == id);
    return 1;
  }

  // ==================== Schedule CRUD ====================

  @override
  Future<Schedule> createSchedule(Schedule schedule) async {
    final newSchedule = schedule.copyWith(id: _scheduleIdCounter++);
    _schedules.add(newSchedule);
    return newSchedule;
  }

  @override
  Future<List<Schedule>> getAllSchedules() async {
    return List.from(_schedules);
  }

  @override
  Future<List<Schedule>> getSchedulesForRoutine(int routineId) async {
    return _schedules.where((s) => s.routineId == routineId).toList();
  }

  @override
  Future<int> updateSchedule(Schedule schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteSchedule(int id) async {
    _schedules.removeWhere((s) => s.id == id);
    return 1;
  }

  @override
  Future<int> deleteSchedulesForRoutine(int routineId) async {
    final count = _schedules.where((s) => s.routineId == routineId).length;
    _schedules.removeWhere((s) => s.routineId == routineId);
    return count;
  }

  // ==================== Log CRUD ====================

  @override
  Future<Log> createLog(Log log) async {
    final newLog = log.copyWith(id: _logIdCounter++);
    _logs.add(newLog);
    return newLog;
  }

  @override
  Future<List<Log>> getAllLogs() async {
    return List.from(_logs);
  }

  @override
  Future<List<Log>> getLogsForRoutine(int routineId) async {
    return _logs.where((l) => l.routineId == routineId).toList();
  }

  @override
  Future<List<Log>> getTodayLogs() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _logs
        .where(
          (l) =>
              l.scheduledTime.isAfter(startOfDay) &&
              l.scheduledTime.isBefore(endOfDay),
        )
        .toList();
  }

  @override
  Future<List<Log>> getLogsByDateRange(DateTime start, DateTime end) async {
    return _logs
        .where(
          (l) =>
              !l.scheduledTime.isBefore(start) && l.scheduledTime.isBefore(end),
        )
        .toList();
  }

  @override
  Future<int> updateLog(Log log) async {
    final index = _logs.indexWhere((l) => l.id == log.id);
    if (index != -1) {
      _logs[index] = log;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteLog(int id) async {
    _logs.removeWhere((l) => l.id == id);
    return 1;
  }

  @override
  Future<Map<String, int>> getAdherenceStats(
    DateTime start,
    DateTime end,
  ) async {
    final logs = await getLogsByDateRange(start, end);
    int taken = 0, skipped = 0, missed = 0;

    for (final log in logs) {
      switch (log.status) {
        case LogStatus.take:
          taken++;
          break;
        case LogStatus.skip:
          skipped++;
          break;
        case LogStatus.missed:
          missed++;
          break;
      }
    }

    return {'taken': taken, 'skipped': skipped, 'missed': missed};
  }

  // ==================== Snoozed Dose CRUD ====================

  @override
  Future<SnoozedDose> createSnoozedDose(SnoozedDose dose) async {
    final newDose = dose.copyWith(id: _snoozedDoseIdCounter++);
    _snoozedDoses.add(newDose);
    return newDose;
  }

  @override
  Future<SnoozedDose?> getSnoozedDose(
    int routineId,
    DateTime scheduledTime,
  ) async {
    try {
      return _snoozedDoses.firstWhere(
        (d) =>
            d.routineId == routineId &&
            d.originalScheduledTime == scheduledTime,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SnoozedDose>> getActiveSnoozedDoses() async {
    final now = DateTime.now();
    return _snoozedDoses.where((d) => d.snoozedUntil.isAfter(now)).toList();
  }

  @override
  Future<List<SnoozedDose>> getSnoozedDosesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _snoozedDoses
        .where(
          (d) =>
              d.originalScheduledTime.isAfter(startOfDay) &&
              d.originalScheduledTime.isBefore(endOfDay),
        )
        .toList();
  }

  @override
  Future<int> deleteSnoozedDose(int routineId, DateTime scheduledTime) async {
    _snoozedDoses.removeWhere(
      (d) =>
          d.routineId == routineId &&
          d.originalScheduledTime == scheduledTime,
    );
    return 1;
  }

  @override
  Future<int> clearExpiredSnoozedDoses() async {
    final now = DateTime.now();
    final expiredCount = _snoozedDoses
        .where((d) => d.snoozedUntil.isBefore(now))
        .length;
    _snoozedDoses.removeWhere((d) => d.snoozedUntil.isBefore(now));
    return expiredCount;
  }

  // ==================== Other Methods ====================

  @override
  Future<void> deleteAllData() async {
    reset();
  }

  @override
  Future<void> resetAllData() async {
    reset();
  }

  @override
  Future<void> clearAllData() async {
    reset();
  }

  @override
  Future<void> close() async {
    // No-op for mock
  }

  // Stub for any missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock implementation of NotificationService for testing
class MockNotificationService implements NotificationService {
  final List<int> scheduledNotificationIds = [];
  final List<int> cancelledNotificationIds = [];
  bool _initialized = false;
  bool _notificationsEnabled = true;
  bool _exactAlarmsEnabled = true;

  /// Reset mock state
  void reset() {
    scheduledNotificationIds.clear();
    cancelledNotificationIds.clear();
    _initialized = false;
    _notificationsEnabled = true;
    _exactAlarmsEnabled = true;
  }

  /// Configure mock behavior
  void setNotificationsEnabled(bool enabled) => _notificationsEnabled = enabled;
  void setExactAlarmsEnabled(bool enabled) => _exactAlarmsEnabled = enabled;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  @override
  Future<bool> requestAllPermissions() async {
    return true;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    return _notificationsEnabled;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    return _exactAlarmsEnabled;
  }

  @override
  Future<NotificationSchedulingReadiness> checkSchedulingReadiness() async {
    final canSchedule = _notificationsEnabled && _exactAlarmsEnabled;
    return NotificationSchedulingReadiness(
      canSchedule: canSchedule,
      platformSupported: true,
      notificationGranted: _notificationsEnabled,
      exactAlarmGranted: _exactAlarmsEnabled,
      reason: canSchedule ? 'Ready' : 'Permissions required',
    );
  }

  @override
  Future<void> scheduleRoutineReminder({
    required int notificationId,
    required int routineId,
    required String routineName,
    required String dosage,
    required DateTime scheduledTime,
    FrequencyType? frequencyType,
  }) async {
    scheduledNotificationIds.add(notificationId);
  }

  @override
  Future<void> showImmediateNotification({
    required int notificationId,
    required int routineId,
    required String routineName,
    required String dosage,
  }) async {
    scheduledNotificationIds.add(notificationId);
  }

  @override
  Future<void> scheduleSnooze({
    required int routineId,
    required String routineName,
    required String dosage,
    required int minutes,
  }) async {
    scheduledNotificationIds.add(routineId * 1000); // Unique ID for snooze
  }

  @override
  Future<void> snoozeNotification({
    required int notificationId,
    required int routineId,
    required String routineName,
    required String dosage,
  }) async {
    scheduledNotificationIds.add(notificationId + 10000);
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    cancelledNotificationIds.add(notificationId);
    scheduledNotificationIds.remove(notificationId);
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelledNotificationIds.addAll(scheduledNotificationIds);
    scheduledNotificationIds.clear();
  }

  @override
  Future<void> cancelScheduleNotifications({
    required int baseNotificationId,
    FrequencyType? frequencyType,
    List<int> specificDays = const [],
  }) async {
    cancelledNotificationIds.add(baseNotificationId);
    scheduledNotificationIds.remove(baseNotificationId);

    if (frequencyType == FrequencyType.specificDays) {
      for (final day in specificDays) {
        final derivedId = NotificationService.specificDayNotificationId(
          baseNotificationId,
          day,
        );
        cancelledNotificationIds.add(derivedId);
        scheduledNotificationIds.remove(derivedId);
      }
    }
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    // Return mock pending notification requests
    return scheduledNotificationIds
        .map((id) => PendingNotificationRequest(id, null, null, null))
        .toList();
  }

  // Stub for any missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
