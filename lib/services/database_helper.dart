import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/routine.dart';
import '../models/schedule.dart';
import '../models/log.dart';
import '../models/snoozed_dose.dart';
import '../models/routine_deletion_snapshot.dart';

/// Singleton database helper for managing local SQLite database
/// Handles all CRUD operations for routines, schedules, and logs
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance, creating it if it doesn't exist
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('routine_time.db');
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Handle database schema upgrades.
  ///
  /// Version 7 migrates the legacy `medicines` schema to the trimmed `routines`
  /// schema and drops the unused stock/pharmacy/RxNorm columns.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 7) return;

    final tableNames = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name'] as String).toSet();

    Future<Set<String>> columnsOf(String table) async {
      if (!tableNames.contains(table)) return <String>{};
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.map((row) => row['name'] as String).toSet();
    }

    final routineColumns = await columnsOf('medicines');
    final scheduleColumns = await columnsOf('schedules');
    final logColumns = await columnsOf('logs');
    final snoozeColumns = await columnsOf('snoozed_doses');

    // Move legacy tables aside so the new schema can be created cleanly.
    if (routineColumns.isNotEmpty) {
      await db.execute('ALTER TABLE medicines RENAME TO medicines_old');
    }
    if (scheduleColumns.isNotEmpty) {
      await db.execute('ALTER TABLE schedules RENAME TO schedules_old');
    }
    if (logColumns.isNotEmpty) {
      await db.execute('ALTER TABLE logs RENAME TO logs_old');
    }
    if (snoozeColumns.isNotEmpty) {
      await db.execute(
        'ALTER TABLE snoozed_doses RENAME TO snoozed_doses_old',
      );
    }

    await _createDB(db, newVersion);

    if (routineColumns.isNotEmpty) {
      await db.execute(
        'INSERT INTO routines (id, name, dosage, type_icon, color) '
        'SELECT id, name, dosage, type_icon, color FROM medicines_old',
      );
    }
    if (scheduleColumns.isNotEmpty) {
      final interval = scheduleColumns.contains('interval_days')
          ? 'interval_days'
          : 'NULL';
      final startDate = scheduleColumns.contains('start_date')
          ? 'start_date'
          : 'NULL';
      final endDate = scheduleColumns.contains('end_date')
          ? 'end_date'
          : 'NULL';
      await db.execute(
        'INSERT INTO schedules '
        '(id, routine_id, time_of_day, frequency_type, frequency_days, '
        'interval_days, start_date, end_date) '
        'SELECT id, medicine_id, time_of_day, frequency_type, frequency_days, '
        '$interval, $startDate, $endDate FROM schedules_old',
      );
    }
    if (logColumns.isNotEmpty) {
      await db.execute(
        'INSERT INTO logs (id, routine_id, scheduled_time, actual_time, status) '
        'SELECT id, medicine_id, scheduled_time, actual_time, status FROM logs_old',
      );
    }
    if (snoozeColumns.isNotEmpty) {
      await db.execute(
        'INSERT INTO snoozed_doses '
        '(id, routine_id, original_scheduled_time, snoozed_until, created_at) '
        'SELECT id, medicine_id, original_scheduled_time, snoozed_until, '
        'created_at FROM snoozed_doses_old',
      );
    }

    await db.execute('DROP TABLE IF EXISTS medicines_old');
    await db.execute('DROP TABLE IF EXISTS schedules_old');
    await db.execute('DROP TABLE IF EXISTS logs_old');
    await db.execute('DROP TABLE IF EXISTS snoozed_doses_old');
  }

  /// Create all database tables
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

  // ==================== MEDICINE CRUD ====================

  /// Create a new routine
  Future<Routine> createRoutine(Routine routine) async {
    final db = await database;
    final id = await db.insert('routines', routine.toMap());
    return routine.copyWith(id: id);
  }

  /// Get all routines
  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final result = await db.query('routines', orderBy: 'name ASC');
    return result.map((map) => Routine.fromMap(map)).toList();
  }

  /// Get a single routine by ID
  Future<Routine?> getRoutine(int id) async {
    final db = await database;
    final maps = await db.query('routines', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Routine.fromMap(maps.first);
    }
    return null;
  }

  /// Update a routine
  Future<int> updateRoutine(Routine routine) async {
    final db = await database;
    return db.update(
      'routines',
      routine.toMap(),
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  }

  /// Delete a routine
  Future<int> deleteRoutine(int id) async {
    final db = await database;
    return db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete routine and all related records atomically.
  Future<void> deleteRoutineGraph(int routineId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'snoozed_doses',
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );
      await txn.delete(
        'logs',
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );
      await txn.delete(
        'schedules',
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );
      await txn.delete('routines', where: 'id = ?', whereArgs: [routineId]);
    });
  }

  /// Restore routine and all related records atomically.
  Future<void> restoreRoutineGraph(RoutineDeletionSnapshot snapshot) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'routines',
        snapshot.routine.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (final schedule in snapshot.schedules) {
        await txn.insert(
          'schedules',
          schedule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final log in snapshot.logs) {
        await txn.insert(
          'logs',
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final snooze in snapshot.snoozedDoses) {
        await txn.insert(
          'snoozed_doses',
          snooze.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  /// Delete all stored data
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('snoozed_doses');
    await db.delete('logs');
    await db.delete('schedules');
    await db.delete('routines');
  }

  // ==================== SCHEDULE CRUD ====================

  /// Create a new schedule
  Future<Schedule> createSchedule(Schedule schedule) async {
    final db = await database;
    final id = await db.insert('schedules', schedule.toMap());
    return schedule.copyWith(id: id);
  }

  /// Get all schedules for a routine
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

  /// Get all schedules
  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final result = await db.query('schedules', orderBy: 'time_of_day ASC');
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  /// Update a schedule
  Future<int> updateSchedule(Schedule schedule) async {
    final db = await database;
    return db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  /// Delete a schedule
  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all schedules for a routine
  Future<int> deleteSchedulesForRoutine(int routineId) async {
    final db = await database;
    return db.delete(
      'schedules',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );
  }

  // ==================== LOG CRUD ====================

  /// Create a new log entry
  Future<Log> createLog(Log log) async {
    final db = await database;
    final id = await db.insert('logs', log.toMap());
    return log.copyWith(id: id);
  }

  /// Get logs for a specific routine
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

  /// Get logs for a date range
  Future<List<Log>> getLogsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'logs',
      where: 'scheduled_time BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      // Sort by time DESC, then by param ID DESC to ensure latest log (e.g. undo/redo) is first
      orderBy: 'scheduled_time DESC, id DESC',
    );
    return result.map((map) => Log.fromMap(map)).toList();
  }

  /// Get logs for today
  Future<List<Log>> getTodayLogs() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getLogsByDateRange(startOfDay, endOfDay);
  }

  /// Update a log entry
  Future<int> updateLog(Log log) async {
    final db = await database;
    return db.update('logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
  }

  /// Delete a log entry
  Future<int> deleteLog(int id) async {
    final db = await database;
    return db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Get adherence statistics for a date range
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

  // ==================== UTILITY ====================

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Reset all data (for settings)
  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('snoozed_doses');
    await db.delete('logs');
    await db.delete('schedules');
    await db.delete('routines');
  }

  /// Backward-compatible alias for clearing all data
  Future<void> clearAllData() async {
    await resetAllData();
  }

  /// Get all logs
  Future<List<Log>> getAllLogs() async {
    final db = await database;
    final result = await db.query('logs', orderBy: 'scheduled_time DESC');
    return result.map((json) => Log.fromMap(json)).toList();
  }

  // ==================== SNOOZED DOSES CRUD ====================

  /// Create a new snoozed dose
  Future<SnoozedDose> createSnoozedDose(SnoozedDose dose) async {
    final db = await database;
    // First, delete any existing snooze for the same routine and scheduled time
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

  /// Get snoozed dose for specific routine and scheduled time
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

  /// Get all active snoozed doses (not expired)
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

  /// Get all snoozed doses for a routine.
  Future<List<SnoozedDose>> getSnoozedDosesForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'snoozed_doses',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'original_scheduled_time DESC',
    );
    return result.map((map) => SnoozedDose.fromMap(map)).toList();
  }

  /// Get all snoozed doses for today
  Future<List<SnoozedDose>> getSnoozedDosesForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.query(
      'snoozed_doses',
      where: 'original_scheduled_time >= ? AND original_scheduled_time < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return result.map((map) => SnoozedDose.fromMap(map)).toList();
  }

  /// Delete a snoozed dose
  Future<int> deleteSnoozedDose(int routineId, DateTime scheduledTime) async {
    final db = await database;
    return db.delete(
      'snoozed_doses',
      where: 'routine_id = ? AND original_scheduled_time = ?',
      whereArgs: [routineId, scheduledTime.toIso8601String()],
    );
  }

  /// Clear expired snoozed doses
  Future<int> clearExpiredSnoozedDoses() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.delete(
      'snoozed_doses',
      where: 'snoozed_until < ?',
      whereArgs: [now],
    );
  }
}
