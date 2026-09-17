// End-to-end user flow integration tests
// Tests complete user scenarios from routine creation to adherence tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:routine_time/models/routine.dart';
import 'package:routine_time/models/schedule.dart';
import 'package:routine_time/models/log.dart';
import 'package:routine_time/models/snoozed_dose.dart';

// Integrated test harness that simulates the full app flow
class IntegrationTestHarness {
  Database? _database;

  // In-memory caches (simulating providers)
  List<Routine> routines = [];
  List<Schedule> schedules = [];
  List<Log> logs = [];
  Map<String, SnoozedDose> snoozedDoses = {};

  Future<void> initialize() async {
    _database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT,
        type_icon INTEGER DEFAULT 1,
        color INTEGER DEFAULT 0xFF2196F3
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        time_of_day TEXT NOT NULL,
        frequency_type TEXT NOT NULL,
        frequency_days TEXT,
        interval_days INTEGER,
        start_date TEXT,
        end_date TEXT,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        scheduled_time TEXT NOT NULL,
        actual_time TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE snoozed_doses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        original_scheduled_time TEXT NOT NULL,
        snoozed_until TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== User Actions ====================

  /// User adds a new routine with schedules
  Future<Routine> addRoutine({
    required String name,
    required String dosage,
    required List<String> scheduleTimes,
    FrequencyType frequencyType = FrequencyType.daily,
  }) async {
    final db = _database!;

    // Create routine
    final routineId = await db.insert('routines', {
      'name': name,
      'dosage': dosage,
      'type_icon': 1,
      'color': 0xFF2196F3,
    });

    final routine = Routine(id: routineId, name: name, dosage: dosage);
    routines.add(routine);

    // Create schedules
    for (final time in scheduleTimes) {
      final scheduleId = await db.insert('schedules', {
        'routine_id': routineId,
        'time_of_day': time,
        'frequency_type': frequencyType.name,
      });
      schedules.add(
        Schedule(
          id: scheduleId,
          routineId: routineId,
          timeOfDay: time,
          frequencyType: frequencyType,
        ),
      );
    }

    return routine;
  }

  /// User takes their routine
  Future<Log> takeRoutine(int routineId, DateTime scheduledTime) async {
    final db = _database!;
    final now = DateTime.now();

    // Create log
    final logId = await db.insert('logs', {
      'routine_id': routineId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': now.toIso8601String(),
      'status': 'take',
    });

    final log = Log(
      id: logId,
      routineId: routineId,
      scheduledTime: scheduledTime,
      actualTime: now,
      status: LogStatus.take,
    );
    logs.add(log);

    return log;
  }

  /// User skips their routine
  Future<Log> skipRoutine(int routineId, DateTime scheduledTime) async {
    final db = _database!;

    final logId = await db.insert('logs', {
      'routine_id': routineId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': null,
      'status': 'skip',
    });

    final log = Log(
      id: logId,
      routineId: routineId,
      scheduledTime: scheduledTime,
      status: LogStatus.skip,
    );
    logs.add(log);

    return log;
  }

  /// User snoozes a dose
  Future<SnoozedDose> snoozeDose({
    required int routineId,
    required DateTime scheduledTime,
    required int minutes,
  }) async {
    final db = _database!;
    final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));

    // Delete existing snooze for same routine/time
    await db.delete(
      'snoozed_doses',
      where: 'routine_id = ? AND original_scheduled_time = ?',
      whereArgs: [routineId, scheduledTime.toIso8601String()],
    );

    final id = await db.insert('snoozed_doses', {
      'routine_id': routineId,
      'original_scheduled_time': scheduledTime.toIso8601String(),
      'snoozed_until': snoozedUntil.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    final dose = SnoozedDose(
      id: id,
      routineId: routineId,
      originalScheduledTime: scheduledTime,
      snoozedUntil: snoozedUntil,
    );

    final key = '${routineId}_${scheduledTime.toIso8601String()}';
    snoozedDoses[key] = dose;

    return dose;
  }

  /// User deletes a routine
  Future<void> deleteRoutine(int routineId) async {
    final db = _database!;

    await db.delete('routines', where: 'id = ?', whereArgs: [routineId]);
    await db.delete(
      'schedules',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );
    await db.delete('logs', where: 'routine_id = ?', whereArgs: [routineId]);
    await db.delete(
      'snoozed_doses',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );

    routines.removeWhere((m) => m.id == routineId);
    schedules.removeWhere((s) => s.routineId == routineId);
    logs.removeWhere((l) => l.routineId == routineId);
    snoozedDoses.removeWhere((k, v) => v.routineId == routineId);
  }

  // ==================== Queries ====================

  /// Get all scheduled doses for a date
  List<Map<String, dynamic>> getScheduledDosesForDate(DateTime date) {
    final result = <Map<String, dynamic>>[];

    for (final schedule in schedules) {
      if (!schedule.shouldTriggerOnDate(date)) continue;

      final parts = schedule.timeOfDay.split(':');
      final scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final routine = routines.firstWhere(
        (m) => m.id == schedule.routineId,
        orElse: () => Routine(name: 'Unknown'),
      );

      // Check if already logged
      final hasLog = logs.any(
        (l) =>
            l.routineId == schedule.routineId &&
            l.scheduledTime.year == scheduledTime.year &&
            l.scheduledTime.month == scheduledTime.month &&
            l.scheduledTime.day == scheduledTime.day &&
            l.scheduledTime.hour == scheduledTime.hour &&
            l.scheduledTime.minute == scheduledTime.minute,
      );

      result.add({
        'routine': routine,
        'schedule': schedule,
        'scheduledTime': scheduledTime,
        'hasLog': hasLog,
      });
    }

    return result;
  }

  /// Calculate adherence rate
  double calculateAdherenceRate(DateTime start, DateTime end) {
    final logsInRange = logs.where(
      (l) => !l.scheduledTime.isBefore(start) && l.scheduledTime.isBefore(end),
    );

    if (logsInRange.isEmpty) return 0.0;

    final taken = logsInRange.where((l) => l.status == LogStatus.take).length;
    return taken / logsInRange.length;
  }

  Future<void> dispose() async {
    await _database?.close();
  }
}

void main() {
  sqfliteFfiInit();

  late IntegrationTestHarness harness;

  setUp(() async {
    harness = IntegrationTestHarness();
    await harness.initialize();
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('End-to-End User Flows', () {
    group('Complete Routine Workflow', () {
      test('User adds routine → schedules dose → completes routine', () async {
        // 1. User adds a new routine
        final routine = await harness.addRoutine(
          name: 'Read',
          dosage: '20 min',
          scheduleTimes: ['08:00', '20:00'],
        );

        expect(harness.routines.length, 1);
        expect(harness.schedules.length, 2);

        // 2. User gets their scheduled doses for today
        final today = DateTime.now();
        final doses = harness.getScheduledDosesForDate(today);

        expect(doses.length, 2);
        expect(doses.every((d) => d['hasLog'] == false), isTrue);

        // 3. User completes their morning dose
        final morningDose = doses.firstWhere(
          (d) => (d['schedule'] as Schedule).timeOfDay == '08:00',
        );
        await harness.takeRoutine(
          routine.id!,
          morningDose['scheduledTime'] as DateTime,
        );

        expect(harness.logs.length, 1);
        expect(harness.logs.first.status, LogStatus.take);
      });

      test('User maintains adherence over multiple days', () async {
        final routine = await harness.addRoutine(
          name: 'Daily Walk',
          dosage: '30 min',
          scheduleTimes: ['09:00'],
        );

        // Simulate 7 days of completing the routine
        final startDate = DateTime.now();

        for (var i = 0; i < 7; i++) {
          final date = startDate.add(Duration(days: i));
          final scheduledTime = DateTime(date.year, date.month, date.day, 9, 0);

          await harness.takeRoutine(routine.id!, scheduledTime);
        }

        expect(harness.logs.length, 7);

        // Calculate adherence
        final adherence = harness.calculateAdherenceRate(
          startDate,
          startDate.add(const Duration(days: 8)),
        );
        expect(adherence, 1.0); // 100% adherence
      });

      test('User skips some doses → partial adherence', () async {
        final routine = await harness.addRoutine(
          name: 'Meditation',
          dosage: '10 min',
          scheduleTimes: ['08:00'],
        );

        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month, now.day);

        // Complete for 3 days, skip for 2 days
        for (var i = 0; i < 5; i++) {
          final date = startDate.add(Duration(days: i));
          final scheduledTime = DateTime(date.year, date.month, date.day, 8, 0);

          if (i < 3) {
            await harness.takeRoutine(routine.id!, scheduledTime);
          } else {
            await harness.skipRoutine(routine.id!, scheduledTime);
          }
        }

        expect(harness.logs.length, 5);

        final adherence = harness.calculateAdherenceRate(
          startDate,
          startDate.add(const Duration(days: 6)),
        );
        expect(adherence, 0.6); // 60% adherence (3/5)
      });
    });

    group('Snooze Workflow', () {
      test('User snoozes dose → takes later', () async {
        final routine = await harness.addRoutine(
          name: 'Snooze Test',
          dosage: '20 min',
          scheduleTimes: ['08:00'],
        );

        final scheduledTime = DateTime.now();

        // User snoozes for 10 minutes
        final snooze = await harness.snoozeDose(
          routineId: routine.id!,
          scheduledTime: scheduledTime,
          minutes: 10,
        );

        expect(harness.snoozedDoses.length, 1);
        expect(snooze.snoozedUntil.isAfter(DateTime.now()), isTrue);

        // Later, user completes the routine
        await harness.takeRoutine(routine.id!, scheduledTime);

        expect(harness.logs.length, 1);
        expect(harness.logs.first.status, LogStatus.take);
      });

      test('Multiple snoozes replace previous', () async {
        final routine = await harness.addRoutine(
          name: 'Multi Snooze',
          dosage: '10 min',
          scheduleTimes: ['08:00'],
        );

        final scheduledTime = DateTime.now();

        await harness.snoozeDose(
          routineId: routine.id!,
          scheduledTime: scheduledTime,
          minutes: 10,
        );

        await harness.snoozeDose(
          routineId: routine.id!,
          scheduledTime: scheduledTime,
          minutes: 20,
        );

        // Should still only have 1 snooze
        expect(harness.snoozedDoses.length, 1);
      });
    });

    group('Delete Routine Cascade', () {
      test('Deleting routine removes related data', () async {
        final routine = await harness.addRoutine(
          name: 'To Delete',
          dosage: '15 min',
          scheduleTimes: ['08:00', '20:00'],
        );

        // Add some activity
        await harness.takeRoutine(routine.id!, DateTime.now());
        await harness.snoozeDose(
          routineId: routine.id!,
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          minutes: 10,
        );

        expect(harness.routines.length, 1);
        expect(harness.schedules.length, 2);
        expect(harness.logs.length, 1);
        expect(harness.snoozedDoses.length, 1);

        // Delete routine
        await harness.deleteRoutine(routine.id!);

        // All related data should be gone
        expect(harness.routines, isEmpty);
        expect(harness.schedules, isEmpty);
        expect(harness.logs, isEmpty);
        expect(harness.snoozedDoses, isEmpty);
      });
    });

    group('Multiple Routines', () {
      test('User manages multiple routines independently', () async {
        final read = await harness.addRoutine(
          name: 'Read',
          dosage: '20 min',
          scheduleTimes: ['08:00'],
        );

        final walk = await harness.addRoutine(
          name: 'Walk',
          dosage: '30 min',
          scheduleTimes: ['09:00'],
        );

        final meditate = await harness.addRoutine(
          name: 'Meditate',
          dosage: '10 min',
          scheduleTimes: ['07:00', '13:00', '19:00'],
        );

        expect(harness.routines.length, 3);
        expect(harness.schedules.length, 5); // 1 + 1 + 3

        // Complete read and meditate, skip walk
        final now = DateTime.now();
        await harness.takeRoutine(read.id!, now);
        await harness.takeRoutine(meditate.id!, now);
        await harness.skipRoutine(walk.id!, now);

        final readLogs = harness.logs
            .where((l) => l.routineId == read.id)
            .toList();
        final walkLogs = harness.logs
            .where((l) => l.routineId == walk.id)
            .toList();
        final meditateLogs = harness.logs
            .where((l) => l.routineId == meditate.id)
            .toList();

        expect(readLogs.single.status, LogStatus.take);
        expect(meditateLogs.single.status, LogStatus.take);
        expect(walkLogs.single.status, LogStatus.skip);
      });
    });

    group('Complex Scheduling', () {
      test('Specific days schedule only triggers on correct days', () async {
        await harness.addRoutine(
          name: 'MWF Routine',
          dosage: '20 min',
          scheduleTimes: ['08:00'],
          frequencyType: FrequencyType.specificDays,
        );

        // Manually update the schedule to have specific days
        final schedule = harness.schedules.first;
        harness.schedules[0] = Schedule(
          id: schedule.id,
          routineId: schedule.routineId,
          timeOfDay: schedule.timeOfDay,
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5', // Mon, Wed, Fri
        );

        // Monday should have doses
        final monday = DateTime(2026, 2, 2); // Feb 2, 2026 is Monday
        final mondayDoses = harness.getScheduledDosesForDate(monday);
        expect(mondayDoses.length, 1);

        // Tuesday should NOT have doses
        final tuesday = DateTime(2026, 2, 3);
        final tuesdayDoses = harness.getScheduledDosesForDate(tuesday);
        expect(tuesdayDoses, isEmpty);

        // Wednesday should have doses
        final wednesday = DateTime(2026, 2, 4);
        final wednesdayDoses = harness.getScheduledDosesForDate(wednesday);
        expect(wednesdayDoses.length, 1);
      });
    });

    group('Edge Cases', () {
      test('Empty state queries work correctly', () {
        final today = DateTime.now();

        expect(harness.routines, isEmpty);
        expect(harness.getScheduledDosesForDate(today), isEmpty);
        expect(
          harness.calculateAdherenceRate(
            today,
            today.add(const Duration(days: 1)),
          ),
          0.0,
        );
      });

      test('Handles routine with no schedules', () async {
        await harness.addRoutine(
          name: 'One-off',
          dosage: '15 min',
          scheduleTimes: [], // No schedules
        );

        expect(harness.routines.length, 1);
        expect(harness.schedules, isEmpty);

        final doses = harness.getScheduledDosesForDate(DateTime.now());
        expect(doses, isEmpty);
      });
    });
  });
}
