import 'package:flutter/foundation.dart';
import '../models/routine.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/schedule.dart';
import '../models/routine_deletion_snapshot.dart';

/// Provider for managing routines.
class RoutineProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<Routine> _routines = [];
  bool _isLoading = false;

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  /// Load all routines from database.
  Future<void> loadRoutines() async {
    _isLoading = true;
    notifyListeners();

    try {
      _routines = await _db.getAllRoutines();
    } catch (e) {
      debugPrint('Error loading routines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new routine.
  Future<Routine?> addRoutine(Routine routine) async {
    try {
      final newRoutine = await _db.createRoutine(routine);
      _routines.add(newRoutine);
      notifyListeners();
      return newRoutine;
    } catch (e) {
      debugPrint('Error adding routine: $e');
      return null;
    }
  }

  /// Update an existing routine.
  Future<bool> updateRoutine(Routine routine) async {
    try {
      await _db.updateRoutine(routine);
      final index = _routines.indexWhere((m) => m.id == routine.id);
      if (index != -1) {
        _routines[index] = routine;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating routine: $e');
      return false;
    }
  }

  /// Delete a routine.
  Future<bool> deleteRoutine(int id) async {
    try {
      await _db.deleteRoutine(id);
      _routines.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting routine: $e');
      return false;
    }
  }

  /// Delete a routine and return snapshot for undo.
  Future<RoutineDeletionSnapshot?> deleteRoutineWithSnapshot(
    int routineId,
  ) async {
    try {
      final routine = await _db.getRoutine(routineId);
      if (routine == null) return null;

      final schedules = await _db.getSchedulesForRoutine(routineId);
      final logs = await _db.getLogsForRoutine(routineId);
      final snoozedDoses = await _db.getSnoozedDosesForRoutine(routineId);

      final snapshot = RoutineDeletionSnapshot(
        routine: routine,
        schedules: schedules,
        logs: logs,
        snoozedDoses: snoozedDoses,
      );

      await _notifications.cancelNotificationsForRoutine(
        routineId: routineId,
        scheduleIds: schedules.map((s) => s.id).whereType<int>().toList(),
      );

      await _db.deleteRoutineGraph(routineId);
      _routines.removeWhere((m) => m.id == routineId);
      notifyListeners();

      return snapshot;
    } catch (e) {
      debugPrint('Error deleting routine with snapshot: $e');
      return null;
    }
  }

  /// Restore previously deleted routine data graph.
  Future<bool> restoreDeletedRoutine(RoutineDeletionSnapshot snapshot) async {
    try {
      await _db.restoreRoutineGraph(snapshot);
      await loadRoutines();

      await _rescheduleSnapshotSchedules(snapshot);

      return true;
    } catch (e) {
      debugPrint('Error restoring deleted routine: $e');
      return false;
    }
  }

  /// Get routine by ID.
  Routine? getRoutineById(int id) {
    try {
      return _routines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refresh routines from database.
  Future<void> refresh() async {
    await loadRoutines();
  }

  Future<void> _rescheduleSnapshotSchedules(
    RoutineDeletionSnapshot snapshot,
  ) async {
    final routineId = snapshot.routine.id;
    if (routineId == null) return;

    for (final schedule in snapshot.schedules) {
      final scheduleId = schedule.id;
      if (scheduleId == null) continue;

      if (schedule.frequencyType == FrequencyType.specificDays &&
          schedule.daysList.isNotEmpty) {
        for (final weekday in schedule.daysList) {
          final nextTime = _nextSpecificWeekdayTime(schedule, weekday);
          if (nextTime == null) continue;

          await _notifications.scheduleRoutineReminder(
            notificationId: NotificationService.specificDayNotificationId(
              scheduleId,
              weekday,
            ),
            routineId: routineId,
            routineName: snapshot.routine.name,
            dosage: snapshot.routine.dosage,
            scheduledTime: nextTime,
            frequencyType: FrequencyType.specificDays,
          );
        }
        continue;
      }

      final nextTime = schedule.getNextScheduledTime();
      if (nextTime == null) continue;

      await _notifications.scheduleRoutineReminder(
        notificationId: scheduleId,
        routineId: routineId,
        routineName: snapshot.routine.name,
        dosage: snapshot.routine.dosage,
        scheduledTime: nextTime,
        frequencyType: schedule.frequencyType,
      );
    }
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
}
