import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/log.dart';
import 'package:privacy_meds/models/schedule.dart';
import '../mocks/mock_services.dart';
import '../fixtures/test_fixtures.dart';

/// A testable version of LogProvider that accepts injected dependencies
class TestableLogProvider {
  final MockDatabaseHelper db;

  List<Log> _logs = [];
  bool _isLoading = false;

  TestableLogProvider({required this.db});

  List<Log> get logs => _logs;
  bool get isLoading => _isLoading;

  /// Get today's logs
  List<Log> get todayLogs {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _logs.where((log) {
      return !log.scheduledTime.isBefore(startOfDay) &&
          log.scheduledTime.isBefore(endOfDay);
    }).toList();
  }

  /// Get logs for a specific medicine
  List<Log> getLogsForMedicine(int medicineId) {
    return _logs.where((log) => log.medicineId == medicineId).toList();
  }

  /// Load logs from database
  Future<void> loadLogs() async {
    _isLoading = true;
    try {
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final startDate = now.subtract(const Duration(days: 30));
      _logs = await db.getLogsByDateRange(startDate, endOfToday);
    } finally {
      _isLoading = false;
    }
  }

  /// Add a new log entry
  Future<Log?> addLog(Log log) async {
    final newLog = await db.createLog(log);
    _logs.insert(0, newLog);
    return newLog;
  }

  /// Update an existing log
  Future<bool> updateLog(Log log) async {
    await db.updateLog(log);
    final index = _logs.indexWhere((l) => l.id == log.id);
    if (index != -1) {
      _logs[index] = log;
    }
    return true;
  }

  /// Delete a log entry
  Future<bool> deleteLog(int id) async {
    await db.deleteLog(id);
    _logs.removeWhere((l) => l.id == id);
    return true;
  }

  /// Mark medicine as taken
  Future<Log> markAsTaken(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.take,
    );
    return await addLog(log) as Log;
  }

  /// Mark medicine as skipped
  Future<Log> markAsSkipped(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.skip,
    );
    return await addLog(log) as Log;
  }

  /// Mark medicine as missed
  Future<Log> markAsMissed(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: null,
      status: LogStatus.missed,
    );
    return await addLog(log) as Log;
  }

  /// Get adherence statistics for a date range
  Future<Map<String, dynamic>> getAdherenceStats(
    DateTime start,
    DateTime end,
  ) async {
    return await db.getAdherenceStats(start, end);
  }

  /// Calculate daily progress
  Map<String, dynamic> calculateDailyProgress(
    DateTime date,
    List<Schedule> schedules,
  ) {
    int total = 0;
    int taken = 0;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logsForDate = _logs
        .where(
          (l) =>
              l.scheduledTime.isAfter(startOfDay) &&
              l.scheduledTime.isBefore(endOfDay),
        )
        .toList();

    for (var schedule in schedules) {
      if (schedule.frequencyType == FrequencyType.asNeeded) continue;

      bool isScheduled = _isScheduledForDate(schedule, date);

      if (isScheduled) {
        total++;

        final parts = schedule.timeOfDay.split(':');
        final scheduledDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final hasTakenLog = logsForDate.any(
          (l) =>
              l.medicineId == schedule.medicineId &&
              l.status == LogStatus.take &&
              l.scheduledTime.year == scheduledDateTime.year &&
              l.scheduledTime.month == scheduledDateTime.month &&
              l.scheduledTime.day == scheduledDateTime.day &&
              l.scheduledTime.hour == scheduledDateTime.hour &&
              l.scheduledTime.minute == scheduledDateTime.minute,
        );

        if (hasTakenLog) {
          taken++;
        }
      }
    }

    return {
      'total': total,
      'taken': taken,
      'percentage': total == 0 ? 0.0 : taken / total,
    };
  }

  bool _isScheduledForDate(Schedule schedule, DateTime date) {
    final dayDate = DateTime(date.year, date.month, date.day);

    if (schedule.startDate != null) {
      final start = DateTime.parse(schedule.startDate!);
      if (dayDate.isBefore(start)) return false;
    }
    if (schedule.endDate != null) {
      final end = DateTime.parse(schedule.endDate!);
      if (dayDate.isAfter(end)) return false;
    }

    switch (schedule.frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.specificDays:
        return schedule.daysList.contains(date.weekday);
      case FrequencyType.interval:
        if (schedule.intervalDays == null || schedule.startDate == null) {
          return true;
        }
        final start = DateTime.parse(schedule.startDate!);
        final diff = dayDate.difference(start).inDays;
        return diff % schedule.intervalDays! == 0;
      case FrequencyType.asNeeded:
        return false;
    }
  }

  /// Clear all logs
  Future<void> clearAllLogs() async {
    _logs.clear();
  }
}

void main() {
  late TestableLogProvider provider;
  late MockDatabaseHelper mockDb;

  setUp(() {
    mockDb = MockDatabaseHelper();
    provider = TestableLogProvider(db: mockDb);
  });

  tearDown(() {
    mockDb.reset();
  });

  group('LogProvider Tests', () {
    group('Initial State', () {
      test('starts with empty list', () {
        expect(provider.logs, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.todayLogs, isEmpty);
      });
    });

    group('loadLogs', () {
      test('loads logs from database', () async {
        // Arrange: Add logs directly to mock DB
        final now = DateTime.now();
        await mockDb.createLog(LogFixtures.taken(scheduledTime: now));
        await mockDb.createLog(
          LogFixtures.taken(
            scheduledTime: now.subtract(const Duration(days: 1)),
          ),
        );

        // Act
        await provider.loadLogs();

        // Assert
        expect(provider.logs.length, 2);
      });

      test('only loads last 30 days', () async {
        final now = DateTime.now();
        await mockDb.createLog(LogFixtures.taken(scheduledTime: now));
        await mockDb.createLog(
          LogFixtures.taken(
            scheduledTime: now.subtract(const Duration(days: 35)),
          ),
        );

        await provider.loadLogs();

        // Only 1 log should be loaded (within 30 days)
        expect(provider.logs.length, 1);
      });
    });

    group('todayLogs', () {
      test('returns only today\'s logs', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10, 0);
        final yesterday = today.subtract(const Duration(days: 1));

        await provider.addLog(LogFixtures.taken(scheduledTime: today));
        await provider.addLog(LogFixtures.taken(scheduledTime: yesterday));

        expect(provider.todayLogs.length, 1);
        expect(provider.todayLogs.first.scheduledTime.day, now.day);
      });

      test('returns empty when no logs today', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await provider.addLog(LogFixtures.taken(scheduledTime: yesterday));

        expect(provider.todayLogs, isEmpty);
      });
    });

    group('getLogsForMedicine', () {
      test('filters logs by medicine ID', () async {
        await provider.addLog(LogFixtures.taken(medicineId: 1));
        await provider.addLog(LogFixtures.taken(medicineId: 2));
        await provider.addLog(LogFixtures.taken(medicineId: 1));

        final logs = provider.getLogsForMedicine(1);

        expect(logs.length, 2);
        expect(logs.every((l) => l.medicineId == 1), isTrue);
      });

      test('returns empty when no logs for medicine', () {
        final logs = provider.getLogsForMedicine(999);
        expect(logs, isEmpty);
      });
    });

    group('addLog', () {
      test('adds log to database and list', () async {
        final log = LogFixtures.taken();

        final result = await provider.addLog(log);

        expect(result, isNotNull);
        expect(result!.id, isNotNull);
        expect(provider.logs.length, 1);
      });

      test('inserts log at beginning of list', () async {
        await provider.addLog(LogFixtures.taken(medicineId: 1));
        await provider.addLog(LogFixtures.taken(medicineId: 2));

        expect(provider.logs.first.medicineId, 2);
      });
    });

    group('markAsTaken', () {
      test('creates log with take status', () async {
        final scheduledTime = DateTime.now();

        final log = await provider.markAsTaken(1, scheduledTime);

        expect(log.status, LogStatus.take);
        expect(log.medicineId, 1);
        expect(log.actualTime, isNotNull);
      });
    });

    group('markAsSkipped', () {
      test('creates log with skip status', () async {
        final scheduledTime = DateTime.now();

        final log = await provider.markAsSkipped(1, scheduledTime);

        expect(log.status, LogStatus.skip);
        expect(log.medicineId, 1);
      });
    });

    group('markAsMissed', () {
      test('creates log with missed status and no actualTime', () async {
        final scheduledTime = DateTime.now();

        final log = await provider.markAsMissed(1, scheduledTime);

        expect(log.status, LogStatus.missed);
        expect(log.actualTime, isNull);
      });
    });

    group('updateLog', () {
      test('updates log in database and list', () async {
        final log = await provider.addLog(LogFixtures.taken());
        final updated = log!.copyWith(status: LogStatus.skip);

        await provider.updateLog(updated);

        expect(provider.logs.first.status, LogStatus.skip);
      });
    });

    group('deleteLog', () {
      test('removes log from database and list', () async {
        final log = await provider.addLog(LogFixtures.taken());

        await provider.deleteLog(log!.id!);

        expect(provider.logs, isEmpty);
      });
    });

    group('calculateDailyProgress', () {
      test('calculates correct progress with all taken', () async {
        final today = DateTime.now();
        final schedules = [
          ScheduleFixtures.daily(medicineId: 1, timeOfDay: '08:00'),
          ScheduleFixtures.daily(medicineId: 2, timeOfDay: '09:00'),
        ];

        // Mark both as taken
        await provider.addLog(
          Log(
            medicineId: 1,
            scheduledTime: DateTime(today.year, today.month, today.day, 8, 0),
            actualTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );
        await provider.addLog(
          Log(
            medicineId: 2,
            scheduledTime: DateTime(today.year, today.month, today.day, 9, 0),
            actualTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );

        final progress = provider.calculateDailyProgress(today, schedules);

        expect(progress['total'], 2);
        expect(progress['taken'], 2);
        expect(progress['percentage'], 1.0);
      });

      test('calculates correct progress with none taken', () async {
        final today = DateTime.now();
        final schedules = [
          ScheduleFixtures.daily(medicineId: 1, timeOfDay: '08:00'),
          ScheduleFixtures.daily(medicineId: 2, timeOfDay: '09:00'),
        ];

        // No logs added

        final progress = provider.calculateDailyProgress(today, schedules);

        expect(progress['total'], 2);
        expect(progress['taken'], 0);
        expect(progress['percentage'], 0.0);
      });

      test('calculates correct progress with partial completion', () async {
        final today = DateTime.now();
        final schedules = [
          ScheduleFixtures.daily(medicineId: 1, timeOfDay: '08:00'),
          ScheduleFixtures.daily(medicineId: 2, timeOfDay: '09:00'),
        ];

        // Only first one taken
        await provider.addLog(
          Log(
            medicineId: 1,
            scheduledTime: DateTime(today.year, today.month, today.day, 8, 0),
            actualTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );

        final progress = provider.calculateDailyProgress(today, schedules);

        expect(progress['total'], 2);
        expect(progress['taken'], 1);
        expect(progress['percentage'], 0.5);
      });

      test('excludes asNeeded schedules from progress', () async {
        final today = DateTime.now();
        final schedules = [
          ScheduleFixtures.daily(medicineId: 1, timeOfDay: '08:00'),
          ScheduleFixtures.asNeeded(medicineId: 2, timeOfDay: '09:00'),
        ];

        final progress = provider.calculateDailyProgress(today, schedules);

        expect(progress['total'], 1); // Only daily, not asNeeded
      });

      test('respects specific days schedule', () async {
        // Create a date that's a Monday (weekday = 1)
        final monday = DateTime(2026, 2, 2); // Feb 2, 2026 is a Monday

        final schedules = [
          ScheduleFixtures.specificDays(
            medicineId: 1,
            timeOfDay: '08:00',
            frequencyDays: '1,3,5', // Mon, Wed, Fri
          ),
        ];

        final progress = provider.calculateDailyProgress(monday, schedules);

        expect(progress['total'], 1); // Monday is included
      });

      test('excludes non-scheduled specific days', () async {
        // Create a date that's a Tuesday (weekday = 2)
        final tuesday = DateTime(2026, 2, 3); // Feb 3, 2026 is a Tuesday

        final schedules = [
          ScheduleFixtures.specificDays(
            medicineId: 1,
            timeOfDay: '08:00',
            frequencyDays: '1,3,5', // Mon, Wed, Fri - NOT Tuesday
          ),
        ];

        final progress = provider.calculateDailyProgress(tuesday, schedules);

        expect(progress['total'], 0); // Tuesday is NOT included
      });
    });

    group('getAdherenceStats', () {
      test('returns correct stats from database', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        await mockDb.createLog(
          Log(
            medicineId: 1,
            scheduledTime: today.add(const Duration(hours: 8)),
            actualTime: today.add(const Duration(hours: 8)),
            status: LogStatus.take,
          ),
        );
        await mockDb.createLog(
          Log(
            medicineId: 1,
            scheduledTime: today.add(const Duration(hours: 12)),
            status: LogStatus.missed,
          ),
        );

        final stats = await provider.getAdherenceStats(
          today,
          today.add(const Duration(days: 1)),
        );

        expect(stats['taken'], 1);
        expect(stats['missed'], 1);
      });
    });

    group('Edge Cases', () {
      test('handles midnight boundary logs correctly', () async {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        final justBeforeMidnight = midnight.subtract(
          const Duration(seconds: 1),
        );

        await provider.addLog(LogFixtures.taken(scheduledTime: midnight));
        await provider.addLog(
          LogFixtures.taken(scheduledTime: justBeforeMidnight),
        );

        expect(provider.todayLogs.length, 1); // Only the midnight one
      });

      test('handles empty schedule list', () {
        final today = DateTime.now();
        final progress = provider.calculateDailyProgress(today, []);

        expect(progress['total'], 0);
        expect(progress['taken'], 0);
        expect(progress['percentage'], 0.0);
      });

      test('clearAllLogs empties the list', () async {
        await provider.addLog(LogFixtures.taken());
        await provider.addLog(LogFixtures.taken());

        await provider.clearAllLogs();

        expect(provider.logs, isEmpty);
      });
    });
  });
}
