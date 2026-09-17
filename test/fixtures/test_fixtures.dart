// Test fixtures for creating test data
// Provides factory methods for creating Routine, Schedule, Log, and other models

import 'package:routine_time/models/routine.dart';
import 'package:routine_time/models/schedule.dart';
import 'package:routine_time/models/log.dart';
import 'package:routine_time/models/snoozed_dose.dart';

// Factory for creating test Routine objects
class RoutineFixtures {
  /// Creates a default test routine
  static Routine create({
    int? id,
    String name = 'Test Routine',
    String dosage = '100mg',
    int typeIcon = 1,
    int color = 0xFF2196F3,
  }) {
    return Routine(
      id: id,
      name: name,
      dosage: dosage,
      typeIcon: typeIcon,
      color: color,
    );
  }

  /// Creates a list of test routines
  static List<Routine> createList(int count) {
    return List.generate(
      count,
      (i) => create(id: i + 1, name: 'Routine ${i + 1}'),
    );
  }
}

// Factory for creating test Schedule objects
class ScheduleFixtures {
  /// Creates a daily schedule
  static Schedule daily({
    int? id,
    int routineId = 1,
    String timeOfDay = '08:00',
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      routineId: routineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.daily,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Creates a specific days schedule (MWF by default)
  static Schedule specificDays({
    int? id,
    int routineId = 1,
    String timeOfDay = '08:00',
    String frequencyDays = '1,3,5', // Mon, Wed, Fri
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      routineId: routineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.specificDays,
      frequencyDays: frequencyDays,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Creates an interval schedule
  static Schedule interval({
    int? id,
    int routineId = 1,
    String timeOfDay = '08:00',
    int intervalDays = 3,
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      routineId: routineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.interval,
      intervalDays: intervalDays,
      startDate: startDate ?? DateTime.now().toIso8601String().split('T')[0],
      endDate: endDate,
    );
  }

  /// Creates an as-needed schedule
  static Schedule asNeeded({
    int? id,
    int routineId = 1,
    String timeOfDay = '08:00',
  }) {
    return Schedule(
      id: id,
      routineId: routineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.asNeeded,
    );
  }
}

// Factory for creating test Log objects
class LogFixtures {
  /// Creates a "taken" log
  static Log taken({
    int? id,
    int routineId = 1,
    DateTime? scheduledTime,
    DateTime? actualTime,
  }) {
    final scheduled = scheduledTime ?? DateTime.now();
    return Log(
      id: id,
      routineId: routineId,
      scheduledTime: scheduled,
      actualTime: actualTime ?? scheduled,
      status: LogStatus.take,
    );
  }

  /// Creates a "taken late" log (more than 30 mins after scheduled)
  static Log takenLate({int? id, int routineId = 1, DateTime? scheduledTime}) {
    final scheduled = scheduledTime ?? DateTime.now();
    return Log(
      id: id,
      routineId: routineId,
      scheduledTime: scheduled,
      actualTime: scheduled.add(const Duration(minutes: 45)),
      status: LogStatus.take,
    );
  }

  /// Creates a "skipped" log
  static Log skipped({int? id, int routineId = 1, DateTime? scheduledTime}) {
    return Log(
      id: id,
      routineId: routineId,
      scheduledTime: scheduledTime ?? DateTime.now(),
      status: LogStatus.skip,
    );
  }

  /// Creates a "missed" log
  static Log missed({int? id, int routineId = 1, DateTime? scheduledTime}) {
    return Log(
      id: id,
      routineId: routineId,
      scheduledTime: scheduledTime ?? DateTime.now(),
      status: LogStatus.missed,
    );
  }
}

// Factory for creating test SnoozedDose objects
class SnoozedDoseFixtures {
  /// Creates a snoozed dose that's still active
  static SnoozedDose active({
    int? id,
    int routineId = 1,
    DateTime? originalScheduledTime,
    int snoozeMinutes = 10,
  }) {
    final original = originalScheduledTime ?? DateTime.now();
    return SnoozedDose(
      id: id,
      routineId: routineId,
      originalScheduledTime: original,
      snoozedUntil: DateTime.now().add(Duration(minutes: snoozeMinutes)),
    );
  }

  /// Creates an expired snoozed dose
  static SnoozedDose expired({int? id, int routineId = 1}) {
    final now = DateTime.now();
    return SnoozedDose(
      id: id,
      routineId: routineId,
      originalScheduledTime: now.subtract(const Duration(hours: 1)),
      snoozedUntil: now.subtract(const Duration(minutes: 30)),
    );
  }
}
