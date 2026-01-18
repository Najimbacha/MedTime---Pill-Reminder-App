import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../models/log.dart';

/// Singleton database helper for managing local SQLite database
/// Handles all CRUD operations for medicines, schedules, and logs
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance, creating it if it doesn't exist
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('privacy_meds.db');
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Handle database schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medicines ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE schedules ADD COLUMN interval_days INTEGER');
      await db.execute('ALTER TABLE schedules ADD COLUMN start_date TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE medicines ADD COLUMN pharmacy_name TEXT');
      await db.execute('ALTER TABLE medicines ADD COLUMN pharmacy_phone TEXT');
      await db.execute('ALTER TABLE schedules ADD COLUMN end_date TEXT');
    }
  }

  /// Create all database tables
  Future<void> _createDB(Database db, int version) async {
    // Medicines table
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT,
        type_icon INTEGER DEFAULT 1,
        current_stock INTEGER DEFAULT 0,
        low_stock_threshold INTEGER DEFAULT 5,
        color INTEGER DEFAULT 0xFF2196F3,
        image_path TEXT,
        pharmacy_name TEXT,
        pharmacy_phone TEXT
      )
    ''');

    // Schedules table
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        time_of_day TEXT NOT NULL,
        frequency_type TEXT NOT NULL,
        frequency_days TEXT,
        interval_days INTEGER,
        start_date TEXT,
        end_date TEXT,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // Logs table
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        scheduled_time TEXT NOT NULL,
        actual_time TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== MEDICINE CRUD ====================

  /// Create a new medicine
  Future<Medicine> createMedicine(Medicine medicine) async {
    final db = await database;
    final id = await db.insert('medicines', medicine.toMap());
    return medicine.copyWith(id: id);
  }

  /// Get all medicines
  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((map) => Medicine.fromMap(map)).toList();
  }

  /// Get a single medicine by ID
  Future<Medicine?> getMedicine(int id) async {
    final db = await database;
    final maps = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Medicine.fromMap(maps.first);
    }
    return null;
  }

  /// Update a medicine
  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  /// Delete a medicine
  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Decrement medicine stock by 1
  Future<void> decrementStock(int medicineId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE medicines SET current_stock = current_stock - 1 WHERE id = ? AND current_stock > 0',
      [medicineId],
    );
  }

  /// Delete all stored data
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('logs');
    await db.delete('schedules');
    await db.delete('medicines');
  }

  // ==================== SCHEDULE CRUD ====================

  /// Create a new schedule
  Future<Schedule> createSchedule(Schedule schedule) async {
    final db = await database;
    final id = await db.insert('schedules', schedule.toMap());
    return schedule.copyWith(id: id);
  }

  /// Get all schedules for a medicine
  Future<List<Schedule>> getSchedulesForMedicine(int medicineId) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
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
    return db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all schedules for a medicine
  Future<int> deleteSchedulesForMedicine(int medicineId) async {
    final db = await database;
    return db.delete(
      'schedules',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
  }

  // ==================== LOG CRUD ====================

  /// Create a new log entry
  Future<Log> createLog(Log log) async {
    final db = await database;
    final id = await db.insert('logs', log.toMap());
    return log.copyWith(id: id);
  }

  /// Get logs for a specific medicine
  Future<List<Log>> getLogsForMedicine(int medicineId) async {
    final db = await database;
    final result = await db.query(
      'logs',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
      orderBy: 'scheduled_time DESC',
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
      orderBy: 'scheduled_time DESC',
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
    return db.update(
      'logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  /// Delete a log entry
  Future<int> deleteLog(int id) async {
    final db = await database;
    return db.delete(
      'logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get adherence statistics for a date range
  Future<Map<String, dynamic>> getAdherenceStats(
      DateTime start, DateTime end) async {
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
      'adherence_rate': total > 0 ? (taken / total * 100).toStringAsFixed(1) : '0.0',
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
    await db.delete('logs');
    await db.delete('schedules');
    await db.delete('medicines');
  }
}
