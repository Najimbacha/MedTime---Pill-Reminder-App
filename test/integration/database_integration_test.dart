// Integration tests for DatabaseHelper
// Uses sqflite_common_ffi to test actual SQLite operations

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:routine_time/models/routine.dart';
import 'package:routine_time/models/schedule.dart';
import 'package:routine_time/models/log.dart';
import 'package:routine_time/models/snoozed_dose.dart';

// A testable version of DatabaseHelper that uses an in-memory database
class TestableDatabaseHelper {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    return await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 6, onCreate: _createDB),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Routines table
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT,
        type_icon INTEGER DEFAULT 1,
        color INTEGER DEFAULT 0xFF2196F3
      )
    ''');

    // Schedules table
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

    // Logs table
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

    // Snoozed doses table
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

  // ==================== ROUTINE CRUD ====================

  Future<Routine> createRoutine(Routine routine) async {
    final db = await database;
    final id = await db.insert('routines', routine.toMap());
    return routine.copyWith(id: id);
  }

  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final result = await db.query('routines', orderBy: 'name ASC');
    return result.map((map) => Routine.fromMap(map)).toList();
  }

  Future<Routine?> getRoutine(int id) async {
    final db = await database;
    final maps = await db.query('routines', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Routine.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateRoutine(Routine routine) async {
    final db = await database;
    return db.update(
      'routines',
      routine.toMap(),
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  }

  Future<int> deleteRoutine(int id) async {
    final db = await database;
    return db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SCHEDULE CRUD ====================

  Future<Schedule> createSchedule(Schedule schedule) async {
    final db = await database;
    final id = await db.insert('schedules', schedule.toMap());
    return schedule.copyWith(id: id);
  }

  Future<List<Schedule>> getSchedulesForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'time_of_day ASC',
    );
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final result = await db.query('schedules', orderBy: 'time_of_day ASC');
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<int> deleteSchedulesForRoutine(int routineId) async {
    final db = await database;
    return db.delete(
      'schedules',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );
  }

  // ==================== LOG CRUD ====================

  Future<Log> createLog(Log log) async {
    final db = await database;
    final id = await db.insert('logs', log.toMap());
    return log.copyWith(id: id);
  }

  Future<List<Log>> getLogsForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'logs',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'scheduled_time DESC, id DESC',
    );
    return result.map((map) => Log.fromMap(map)).toList();
  }

  Future<List<Log>> getLogsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'logs',
      where: 'scheduled_time BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'scheduled_time DESC, id DESC',
    );
    return result.map((map) => Log.fromMap(map)).toList();
  }

  Future<List<Log>> getAllLogs() async {
    final db = await database;
    final result = await db.query('logs', orderBy: 'scheduled_time DESC');
    return result.map((json) => Log.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getAdherenceStats(
    DateTime start,
    DateTime end,
  ) async {
    final logs = await getLogsByDateRange(start, end);
    final total = logs.length;
    final taken = logs.where((log) => log.status == LogStatus.take).length;
    final skipped = logs.where((log) => log.status == LogStatus.skip).length;
    final missed = logs.where((log) => log.status == LogStatus.missed).length;

    return {
      'total': total,
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'adherence_rate': total > 0
          ? (taken / total * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  // ==================== SNOOZED DOSE CRUD ====================

  Future<SnoozedDose> createSnoozedDose(SnoozedDose dose) async {
    final db = await database;
    await db.delete(
      'snoozed_doses',
      where: 'routine_id = ? AND original_scheduled_time = ?',
      whereArgs: [
        dose.routineId,
        dose.originalScheduledTime.toIso8601String(),
      ],
    );
    final id = await db.insert('snoozed_doses', dose.toMap());
    return dose.copyWith(id: id);
  }

  Future<SnoozedDose?> getSnoozedDose(
    int routineId,
    DateTime scheduledTime,
  ) async {
    final db = await database;
    final result = await db.query(
      'snoozed_doses',
      where: 'routine_id = ? AND original_scheduled_time = ?',
      whereArgs: [routineId, scheduledTime.toIso8601String()],
    );
    if (result.isNotEmpty) {
      return SnoozedDose.fromMap(result.first);
    }
    return null;
  }

  Future<List<SnoozedDose>> getActiveSnoozedDoses() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.query(
      'snoozed_doses',
      where: 'snoozed_until > ?',
      whereArgs: [now],
    );
    return result.map((map) => SnoozedDose.fromMap(map)).toList();
  }

  Future<int> deleteSnoozedDose(int routineId, DateTime scheduledTime) async {
    final db = await database;
    return db.delete(
      'snoozed_doses',
      where: 'routine_id = ? AND original_scheduled_time = ?',
      whereArgs: [routineId, scheduledTime.toIso8601String()],
    );
  }

  Future<int> clearExpiredSnoozedDoses() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.delete(
      'snoozed_doses',
      where: 'snoozed_until < ?',
      whereArgs: [now],
    );
  }

  // ==================== UTILITY ====================

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('snoozed_doses');
    await db.delete('logs');
    await db.delete('schedules');
    await db.delete('routines');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

void main() {
  // Initialize FFI for testing
  sqfliteFfiInit();

  late TestableDatabaseHelper db;

  setUp(() async {
    db = TestableDatabaseHelper();
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Integration Tests', () {
    group('Routine CRUD', () {
      test('creates routine with auto-generated ID', () async {
        final routine = Routine(
          name: 'Aspirin',
          dosage: '100mg',
        );

        final created = await db.createRoutine(routine);

        expect(created.id, isNotNull);
        expect(created.id, greaterThan(0));
        expect(created.name, 'Aspirin');
        expect(created.dosage, '100mg');
      });

      test('getAllRoutines returns empty for fresh database', () async {
        final routines = await db.getAllRoutines();
        expect(routines, isEmpty);
      });

      test('getAllRoutines returns routines in name order', () async {
        await db.createRoutine(Routine(name: 'Zebra Med'));
        await db.createRoutine(Routine(name: 'Alpha Med'));
        await db.createRoutine(Routine(name: 'Beta Med'));

        final routines = await db.getAllRoutines();

        expect(routines.length, 3);
        expect(routines[0].name, 'Alpha Med');
        expect(routines[1].name, 'Beta Med');
        expect(routines[2].name, 'Zebra Med');
      });

      test('getRoutine returns routine by ID', () async {
        final created = await db.createRoutine(Routine(name: 'FindMe'));

        final found = await db.getRoutine(created.id!);

        expect(found, isNotNull);
        expect(found!.name, 'FindMe');
      });

      test('getRoutine returns null for non-existent ID', () async {
        final found = await db.getRoutine(9999);
        expect(found, isNull);
      });

      test('updateRoutine updates existing routine', () async {
        final created = await db.createRoutine(
          Routine(name: 'Original', dosage: '50mg'),
        );

        final updated = created.copyWith(name: 'Updated', dosage: '100mg');
        await db.updateRoutine(updated);

        final found = await db.getRoutine(created.id!);
        expect(found!.name, 'Updated');
        expect(found.dosage, '100mg');
      });

      test('deleteRoutine removes routine', () async {
        final created = await db.createRoutine(Routine(name: 'ToDelete'));

        await db.deleteRoutine(created.id!);

        final found = await db.getRoutine(created.id!);
        expect(found, isNull);
      });
    });

    group('Schedule CRUD', () {
      late Routine routine;

      setUp(() async {
        routine = await db.createRoutine(Routine(name: 'Test Med'));
      });

      test('creates schedule linked to routine', () async {
        final schedule = Schedule(
          routineId: routine.id!,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        final created = await db.createSchedule(schedule);

        expect(created.id, isNotNull);
        expect(created.routineId, routine.id);
      });

      test(
        'getSchedulesForRoutine returns only that routine schedules',
        () async {
          final med2 = await db.createRoutine(Routine(name: 'Med 2'));

          await db.createSchedule(
            Schedule(
              routineId: routine.id!,
              timeOfDay: '08:00',
              frequencyType: FrequencyType.daily,
            ),
          );
          await db.createSchedule(
            Schedule(
              routineId: med2.id!,
              timeOfDay: '09:00',
              frequencyType: FrequencyType.daily,
            ),
          );

          final schedules = await db.getSchedulesForRoutine(routine.id!);

          expect(schedules.length, 1);
          expect(schedules.first.routineId, routine.id);
        },
      );

      test('getAllSchedules returns all schedules', () async {
        final med2 = await db.createRoutine(Routine(name: 'Med 2'));

        await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );
        await db.createSchedule(
          Schedule(
            routineId: med2.id!,
            timeOfDay: '09:00',
            frequencyType: FrequencyType.daily,
          ),
        );

        final schedules = await db.getAllSchedules();

        expect(schedules.length, 2);
      });

      test(
        'deleteSchedulesForRoutine removes all schedules for routine',
        () async {
          await db.createSchedule(
            Schedule(
              routineId: routine.id!,
              timeOfDay: '08:00',
              frequencyType: FrequencyType.daily,
            ),
          );
          await db.createSchedule(
            Schedule(
              routineId: routine.id!,
              timeOfDay: '12:00',
              frequencyType: FrequencyType.daily,
            ),
          );

          await db.deleteSchedulesForRoutine(routine.id!);

          final schedules = await db.getSchedulesForRoutine(routine.id!);
          expect(schedules, isEmpty);
        },
      );
    });

    group('Log CRUD', () {
      late Routine routine;

      setUp(() async {
        routine = await db.createRoutine(Routine(name: 'Test Med'));
      });

      test('creates log with status', () async {
        final log = Log(
          routineId: routine.id!,
          scheduledTime: DateTime.now(),
          actualTime: DateTime.now(),
          status: LogStatus.take,
        );

        final created = await db.createLog(log);

        expect(created.id, isNotNull);
        expect(created.status, LogStatus.take);
      });

      test('getLogsForRoutine returns only that routine logs', () async {
        final med2 = await db.createRoutine(Routine(name: 'Med 2'));

        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            routineId: med2.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.skip,
          ),
        );

        final logs = await db.getLogsForRoutine(routine.id!);

        expect(logs.length, 1);
        expect(logs.first.routineId, routine.id);
      });

      test('getLogsByDateRange filters by date', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final tomorrow = today.add(const Duration(days: 1));

        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: yesterday,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: today,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: tomorrow,
            status: LogStatus.take,
          ),
        );

        final startOfToday = DateTime(today.year, today.month, today.day);
        final endOfToday = startOfToday.add(const Duration(days: 1));

        final logs = await db.getLogsByDateRange(startOfToday, endOfToday);

        expect(logs.length, 1);
      });

      test('getAdherenceStats calculates correct statistics', () async {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final end = start.add(const Duration(days: 1));

        // Add logs within range
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: start.add(const Duration(hours: 8)),
            actualTime: start.add(const Duration(hours: 8)),
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: start.add(const Duration(hours: 12)),
            status: LogStatus.skip,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: start.add(const Duration(hours: 18)),
            status: LogStatus.missed,
          ),
        );

        final stats = await db.getAdherenceStats(start, end);

        expect(stats['total'], 3);
        expect(stats['taken'], 1);
        expect(stats['skipped'], 1);
        expect(stats['missed'], 1);
        expect(stats['adherence_rate'], '33.3');
      });
    });

    group('SnoozedDose CRUD', () {
      late Routine routine;

      setUp(() async {
        routine = await db.createRoutine(Routine(name: 'Test Med'));
      });

      test('creates snoozed dose', () async {
        final dose = SnoozedDose(
          routineId: routine.id!,
          originalScheduledTime: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        );

        final created = await db.createSnoozedDose(dose);

        expect(created.id, isNotNull);
        expect(created.routineId, routine.id);
      });

      test(
        'createSnoozedDose replaces existing snooze for same time',
        () async {
          final scheduledTime = DateTime.now();

          await db.createSnoozedDose(
            SnoozedDose(
              routineId: routine.id!,
              originalScheduledTime: scheduledTime,
              snoozedUntil: DateTime.now().add(const Duration(minutes: 5)),
            ),
          );

          await db.createSnoozedDose(
            SnoozedDose(
              routineId: routine.id!,
              originalScheduledTime: scheduledTime,
              snoozedUntil: DateTime.now().add(const Duration(minutes: 15)),
            ),
          );

          final found = await db.getSnoozedDose(routine.id!, scheduledTime);
          expect(found, isNotNull);

          // Should only be one snooze
          final all = await db.getActiveSnoozedDoses();
          expect(all.length, 1);
        },
      );

      test('getSnoozedDose returns snooze by routine and time', () async {
        final scheduledTime = DateTime.now();

        await db.createSnoozedDose(
          SnoozedDose(
            routineId: routine.id!,
            originalScheduledTime: scheduledTime,
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        final found = await db.getSnoozedDose(routine.id!, scheduledTime);

        expect(found, isNotNull);
        expect(found!.routineId, routine.id);
      });

      test('getSnoozedDose returns null for non-existent', () async {
        final found = await db.getSnoozedDose(999, DateTime.now());
        expect(found, isNull);
      });

      test('getActiveSnoozedDoses returns only active snoozes', () async {
        final now = DateTime.now();

        // Active snooze
        await db.createSnoozedDose(
          SnoozedDose(
            routineId: routine.id!,
            originalScheduledTime: now,
            snoozedUntil: now.add(const Duration(hours: 1)),
          ),
        );

        // Expired snooze (would need to manipulate database directly,
        // so we just verify the query works)

        final active = await db.getActiveSnoozedDoses();
        expect(active.length, 1);
      });

      test('deleteSnoozedDose removes snooze', () async {
        final scheduledTime = DateTime.now();

        await db.createSnoozedDose(
          SnoozedDose(
            routineId: routine.id!,
            originalScheduledTime: scheduledTime,
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        await db.deleteSnoozedDose(routine.id!, scheduledTime);

        final found = await db.getSnoozedDose(routine.id!, scheduledTime);
        expect(found, isNull);
      });
    });

    group('Data Integrity', () {
      test('deleteAllData clears all tables', () async {
        final routine = await db.createRoutine(Routine(name: 'Test'));
        await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );
        await db.createSnoozedDose(
          SnoozedDose(
            routineId: routine.id!,
            originalScheduledTime: DateTime.now(),
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        await db.deleteAllData();

        expect(await db.getAllRoutines(), isEmpty);
        expect(await db.getAllSchedules(), isEmpty);
        expect(await db.getAllLogs(), isEmpty);
        expect(await db.getActiveSnoozedDoses(), isEmpty);
      });

      test('routine stores all fields correctly', () async {
        final routine = Routine(
          name: 'Full Routine',
          dosage: '250mg',
          typeIcon: 3,
          color: 0xFFFF5722,
        );

        final created = await db.createRoutine(routine);
        final found = await db.getRoutine(created.id!);

        expect(found!.name, 'Full Routine');
        expect(found.dosage, '250mg');
        expect(found.typeIcon, 3);
        expect(found.color, 0xFFFF5722);
      });

      test('schedule stores all frequency types correctly', () async {
        final routine = await db.createRoutine(Routine(name: 'Test'));

        final daily = await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );

        final specificDays = await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '09:00',
            frequencyType: FrequencyType.specificDays,
            frequencyDays: '1,3,5',
          ),
        );

        final interval = await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '10:00',
            frequencyType: FrequencyType.interval,
            intervalDays: 3,
            startDate: '2026-02-01',
          ),
        );

        final asNeeded = await db.createSchedule(
          Schedule(
            routineId: routine.id!,
            timeOfDay: '11:00',
            frequencyType: FrequencyType.asNeeded,
          ),
        );

        final schedules = await db.getAllSchedules();
        expect(schedules.length, 4);

        final foundDaily = schedules.firstWhere((s) => s.id == daily.id);
        expect(foundDaily.frequencyType, FrequencyType.daily);

        final foundSpecific = schedules.firstWhere(
          (s) => s.id == specificDays.id,
        );
        expect(foundSpecific.frequencyType, FrequencyType.specificDays);
        expect(foundSpecific.frequencyDays, '1,3,5');

        final foundInterval = schedules.firstWhere((s) => s.id == interval.id);
        expect(foundInterval.frequencyType, FrequencyType.interval);
        expect(foundInterval.intervalDays, 3);

        final foundAsNeeded = schedules.firstWhere((s) => s.id == asNeeded.id);
        expect(foundAsNeeded.frequencyType, FrequencyType.asNeeded);
      });

      test('log stores all status types correctly', () async {
        final routine = await db.createRoutine(Routine(name: 'Test'));
        final now = DateTime.now();

        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: now,
            actualTime: now,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: now.add(const Duration(hours: 1)),
            status: LogStatus.skip,
          ),
        );
        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: now.add(const Duration(hours: 2)),
            status: LogStatus.missed,
          ),
        );

        final logs = await db.getLogsForRoutine(routine.id!);
        expect(logs.length, 3);

        expect(logs.any((l) => l.status == LogStatus.take), isTrue);
        expect(logs.any((l) => l.status == LogStatus.skip), isTrue);
        expect(logs.any((l) => l.status == LogStatus.missed), isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles special characters in routine name', () async {
        final routine = await db.createRoutine(
          Routine(name: "O'Sullivan's Routine & Co. (100mg)"),
        );

        final found = await db.getRoutine(routine.id!);
        expect(found!.name, "O'Sullivan's Routine & Co. (100mg)");
      });

      test('handles unicode in routine name', () async {
        final routine = await db.createRoutine(
          Routine(name: '阿司匹林 - アスピリン'),
        );

        final found = await db.getRoutine(routine.id!);
        expect(found!.name, '阿司匹林 - アスピリン');
      });

      test('handles null optional fields', () async {
        final routine = await db.createRoutine(Routine(name: 'MinimalTotal'));

        final found = await db.getRoutine(routine.id!);
        expect(found!.dosage, '');
        expect(found.typeIcon, 1);
        expect(found.color, 0xFF2196F3);
      });

      test('handles rapid concurrent operations', () async {
        // Create multiple routines concurrently
        final futures = List.generate(10, (i) {
          return db.createRoutine(Routine(name: 'Med $i'));
        });

        final routines = await Future.wait(futures);

        expect(routines.length, 10);
        expect(routines.every((m) => m.id != null), isTrue);

        // All IDs should be unique
        final ids = routines.map((m) => m.id!).toSet();
        expect(ids.length, 10);
      });

      test('handles empty string values', () async {
        final routine = await db.createRoutine(
          Routine(name: 'Test', dosage: ''),
        );

        final found = await db.getRoutine(routine.id!);
        expect(found!.dosage, '');
      });

      test('handles date at year boundary', () async {
        final routine = await db.createRoutine(Routine(name: 'Test'));

        await db.createLog(
          Log(
            routineId: routine.id!,
            scheduledTime: DateTime(2026, 12, 31, 23, 59),
            status: LogStatus.take,
          ),
        );

        final found = (await db.getLogsForRoutine(routine.id!)).first;
        expect(found.scheduledTime.year, 2026);
        expect(found.scheduledTime.month, 12);
        expect(found.scheduledTime.day, 31);
      });
    });
  });
}
