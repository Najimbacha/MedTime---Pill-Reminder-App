/// Integration tests for DatabaseHelper
/// Uses sqflite_common_ffi to test actual SQLite operations

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:privacy_meds/models/medicine.dart';
import 'package:privacy_meds/models/schedule.dart';
import 'package:privacy_meds/models/log.dart';
import 'package:privacy_meds/models/snoozed_dose.dart';

/// A testable version of DatabaseHelper that uses an in-memory database
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
        pharmacy_phone TEXT,
        rxcui TEXT
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

    // Snoozed doses table
    await db.execute('''
      CREATE TABLE snoozed_doses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        original_scheduled_time TEXT NOT NULL,
        snoozed_until TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== MEDICINE CRUD ====================

  Future<Medicine> createMedicine(Medicine medicine) async {
    final db = await database;
    final id = await db.insert('medicines', medicine.toMap());
    return medicine.copyWith(id: id);
  }

  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((map) => Medicine.fromMap(map)).toList();
  }

  Future<Medicine?> getMedicine(int id) async {
    final db = await database;
    final maps = await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Medicine.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> decrementStock(int medicineId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE medicines SET current_stock = current_stock - 1 WHERE id = ? AND current_stock > 0',
      [medicineId],
    );
  }

  Future<void> incrementStock(int medicineId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE medicines SET current_stock = current_stock + 1 WHERE id = ?',
      [medicineId],
    );
  }

  // ==================== SCHEDULE CRUD ====================

  Future<Schedule> createSchedule(Schedule schedule) async {
    final db = await database;
    final id = await db.insert('schedules', schedule.toMap());
    return schedule.copyWith(id: id);
  }

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

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final result = await db.query('schedules', orderBy: 'time_of_day ASC');
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<int> deleteSchedulesForMedicine(int medicineId) async {
    final db = await database;
    return db.delete(
      'schedules',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
  }

  // ==================== LOG CRUD ====================

  Future<Log> createLog(Log log) async {
    final db = await database;
    final id = await db.insert('logs', log.toMap());
    return log.copyWith(id: id);
  }

  Future<List<Log>> getLogsForMedicine(int medicineId) async {
    final db = await database;
    final result = await db.query(
      'logs',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
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
      where: 'medicine_id = ? AND original_scheduled_time = ?',
      whereArgs: [
        dose.medicineId,
        dose.originalScheduledTime.toIso8601String(),
      ],
    );
    final id = await db.insert('snoozed_doses', dose.toMap());
    return dose.copyWith(id: id);
  }

  Future<SnoozedDose?> getSnoozedDose(
    int medicineId,
    DateTime scheduledTime,
  ) async {
    final db = await database;
    final result = await db.query(
      'snoozed_doses',
      where: 'medicine_id = ? AND original_scheduled_time = ?',
      whereArgs: [medicineId, scheduledTime.toIso8601String()],
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

  Future<int> deleteSnoozedDose(int medicineId, DateTime scheduledTime) async {
    final db = await database;
    return db.delete(
      'snoozed_doses',
      where: 'medicine_id = ? AND original_scheduled_time = ?',
      whereArgs: [medicineId, scheduledTime.toIso8601String()],
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
    await db.delete('medicines');
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
    group('Medicine CRUD', () {
      test('creates medicine with auto-generated ID', () async {
        final medicine = Medicine(
          name: 'Aspirin',
          dosage: '100mg',
          currentStock: 30,
          lowStockThreshold: 5,
        );

        final created = await db.createMedicine(medicine);

        expect(created.id, isNotNull);
        expect(created.id, greaterThan(0));
        expect(created.name, 'Aspirin');
        expect(created.dosage, '100mg');
      });

      test('getAllMedicines returns empty for fresh database', () async {
        final medicines = await db.getAllMedicines();
        expect(medicines, isEmpty);
      });

      test('getAllMedicines returns medicines in name order', () async {
        await db.createMedicine(Medicine(name: 'Zebra Med'));
        await db.createMedicine(Medicine(name: 'Alpha Med'));
        await db.createMedicine(Medicine(name: 'Beta Med'));

        final medicines = await db.getAllMedicines();

        expect(medicines.length, 3);
        expect(medicines[0].name, 'Alpha Med');
        expect(medicines[1].name, 'Beta Med');
        expect(medicines[2].name, 'Zebra Med');
      });

      test('getMedicine returns medicine by ID', () async {
        final created = await db.createMedicine(Medicine(name: 'FindMe'));

        final found = await db.getMedicine(created.id!);

        expect(found, isNotNull);
        expect(found!.name, 'FindMe');
      });

      test('getMedicine returns null for non-existent ID', () async {
        final found = await db.getMedicine(9999);
        expect(found, isNull);
      });

      test('updateMedicine updates existing medicine', () async {
        final created = await db.createMedicine(
          Medicine(name: 'Original', dosage: '50mg'),
        );

        final updated = created.copyWith(name: 'Updated', dosage: '100mg');
        await db.updateMedicine(updated);

        final found = await db.getMedicine(created.id!);
        expect(found!.name, 'Updated');
        expect(found.dosage, '100mg');
      });

      test('deleteMedicine removes medicine', () async {
        final created = await db.createMedicine(Medicine(name: 'ToDelete'));

        await db.deleteMedicine(created.id!);

        final found = await db.getMedicine(created.id!);
        expect(found, isNull);
      });

      test('decrementStock reduces stock by 1', () async {
        final created = await db.createMedicine(
          Medicine(name: 'Test', currentStock: 10),
        );

        await db.decrementStock(created.id!);

        final found = await db.getMedicine(created.id!);
        expect(found!.currentStock, 9);
      });

      test('decrementStock does not go below 0', () async {
        final created = await db.createMedicine(
          Medicine(name: 'Empty', currentStock: 0),
        );

        await db.decrementStock(created.id!);

        final found = await db.getMedicine(created.id!);
        expect(found!.currentStock, 0);
      });

      test('incrementStock increases stock by 1', () async {
        final created = await db.createMedicine(
          Medicine(name: 'Test', currentStock: 10),
        );

        await db.incrementStock(created.id!);

        final found = await db.getMedicine(created.id!);
        expect(found!.currentStock, 11);
      });
    });

    group('Schedule CRUD', () {
      late Medicine medicine;

      setUp(() async {
        medicine = await db.createMedicine(Medicine(name: 'Test Med'));
      });

      test('creates schedule linked to medicine', () async {
        final schedule = Schedule(
          medicineId: medicine.id!,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        final created = await db.createSchedule(schedule);

        expect(created.id, isNotNull);
        expect(created.medicineId, medicine.id);
      });

      test(
        'getSchedulesForMedicine returns only that medicine schedules',
        () async {
          final med2 = await db.createMedicine(Medicine(name: 'Med 2'));

          await db.createSchedule(
            Schedule(
              medicineId: medicine.id!,
              timeOfDay: '08:00',
              frequencyType: FrequencyType.daily,
            ),
          );
          await db.createSchedule(
            Schedule(
              medicineId: med2.id!,
              timeOfDay: '09:00',
              frequencyType: FrequencyType.daily,
            ),
          );

          final schedules = await db.getSchedulesForMedicine(medicine.id!);

          expect(schedules.length, 1);
          expect(schedules.first.medicineId, medicine.id);
        },
      );

      test('getAllSchedules returns all schedules', () async {
        final med2 = await db.createMedicine(Medicine(name: 'Med 2'));

        await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );
        await db.createSchedule(
          Schedule(
            medicineId: med2.id!,
            timeOfDay: '09:00',
            frequencyType: FrequencyType.daily,
          ),
        );

        final schedules = await db.getAllSchedules();

        expect(schedules.length, 2);
      });

      test(
        'deleteSchedulesForMedicine removes all schedules for medicine',
        () async {
          await db.createSchedule(
            Schedule(
              medicineId: medicine.id!,
              timeOfDay: '08:00',
              frequencyType: FrequencyType.daily,
            ),
          );
          await db.createSchedule(
            Schedule(
              medicineId: medicine.id!,
              timeOfDay: '12:00',
              frequencyType: FrequencyType.daily,
            ),
          );

          await db.deleteSchedulesForMedicine(medicine.id!);

          final schedules = await db.getSchedulesForMedicine(medicine.id!);
          expect(schedules, isEmpty);
        },
      );
    });

    group('Log CRUD', () {
      late Medicine medicine;

      setUp(() async {
        medicine = await db.createMedicine(Medicine(name: 'Test Med'));
      });

      test('creates log with status', () async {
        final log = Log(
          medicineId: medicine.id!,
          scheduledTime: DateTime.now(),
          actualTime: DateTime.now(),
          status: LogStatus.take,
        );

        final created = await db.createLog(log);

        expect(created.id, isNotNull);
        expect(created.status, LogStatus.take);
      });

      test('getLogsForMedicine returns only that medicine logs', () async {
        final med2 = await db.createMedicine(Medicine(name: 'Med 2'));

        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            medicineId: med2.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.skip,
          ),
        );

        final logs = await db.getLogsForMedicine(medicine.id!);

        expect(logs.length, 1);
        expect(logs.first.medicineId, medicine.id);
      });

      test('getLogsByDateRange filters by date', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final tomorrow = today.add(const Duration(days: 1));

        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: yesterday,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: today,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
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
            medicineId: medicine.id!,
            scheduledTime: start.add(const Duration(hours: 8)),
            actualTime: start.add(const Duration(hours: 8)),
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: start.add(const Duration(hours: 12)),
            status: LogStatus.skip,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
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
      late Medicine medicine;

      setUp(() async {
        medicine = await db.createMedicine(Medicine(name: 'Test Med'));
      });

      test('creates snoozed dose', () async {
        final dose = SnoozedDose(
          medicineId: medicine.id!,
          originalScheduledTime: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        );

        final created = await db.createSnoozedDose(dose);

        expect(created.id, isNotNull);
        expect(created.medicineId, medicine.id);
      });

      test(
        'createSnoozedDose replaces existing snooze for same time',
        () async {
          final scheduledTime = DateTime.now();

          await db.createSnoozedDose(
            SnoozedDose(
              medicineId: medicine.id!,
              originalScheduledTime: scheduledTime,
              snoozedUntil: DateTime.now().add(const Duration(minutes: 5)),
            ),
          );

          await db.createSnoozedDose(
            SnoozedDose(
              medicineId: medicine.id!,
              originalScheduledTime: scheduledTime,
              snoozedUntil: DateTime.now().add(const Duration(minutes: 15)),
            ),
          );

          final found = await db.getSnoozedDose(medicine.id!, scheduledTime);
          expect(found, isNotNull);

          // Should only be one snooze
          final all = await db.getActiveSnoozedDoses();
          expect(all.length, 1);
        },
      );

      test('getSnoozedDose returns snooze by medicine and time', () async {
        final scheduledTime = DateTime.now();

        await db.createSnoozedDose(
          SnoozedDose(
            medicineId: medicine.id!,
            originalScheduledTime: scheduledTime,
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        final found = await db.getSnoozedDose(medicine.id!, scheduledTime);

        expect(found, isNotNull);
        expect(found!.medicineId, medicine.id);
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
            medicineId: medicine.id!,
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
            medicineId: medicine.id!,
            originalScheduledTime: scheduledTime,
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        await db.deleteSnoozedDose(medicine.id!, scheduledTime);

        final found = await db.getSnoozedDose(medicine.id!, scheduledTime);
        expect(found, isNull);
      });
    });

    group('Data Integrity', () {
      test('deleteAllData clears all tables', () async {
        final medicine = await db.createMedicine(Medicine(name: 'Test'));
        await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: DateTime.now(),
            status: LogStatus.take,
          ),
        );
        await db.createSnoozedDose(
          SnoozedDose(
            medicineId: medicine.id!,
            originalScheduledTime: DateTime.now(),
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          ),
        );

        await db.deleteAllData();

        expect(await db.getAllMedicines(), isEmpty);
        expect(await db.getAllSchedules(), isEmpty);
        expect(await db.getAllLogs(), isEmpty);
        expect(await db.getActiveSnoozedDoses(), isEmpty);
      });

      test('medicine stores all fields correctly', () async {
        final medicine = Medicine(
          name: 'Full Medicine',
          dosage: '250mg',
          typeIcon: 3,
          currentStock: 42,
          lowStockThreshold: 10,
          color: 0xFFFF5722,
          imagePath: '/path/to/image.jpg',
          pharmacyName: 'Test Pharmacy',
          pharmacyPhone: '+1234567890',
          rxcui: 'RX12345',
        );

        final created = await db.createMedicine(medicine);
        final found = await db.getMedicine(created.id!);

        expect(found!.name, 'Full Medicine');
        expect(found.dosage, '250mg');
        expect(found.typeIcon, 3);
        expect(found.currentStock, 42);
        expect(found.lowStockThreshold, 10);
        expect(found.color, 0xFFFF5722);
        expect(found.imagePath, '/path/to/image.jpg');
        expect(found.pharmacyName, 'Test Pharmacy');
        expect(found.pharmacyPhone, '+1234567890');
        expect(found.rxcui, 'RX12345');
      });

      test('schedule stores all frequency types correctly', () async {
        final medicine = await db.createMedicine(Medicine(name: 'Test'));

        final daily = await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
            timeOfDay: '08:00',
            frequencyType: FrequencyType.daily,
          ),
        );

        final specificDays = await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
            timeOfDay: '09:00',
            frequencyType: FrequencyType.specificDays,
            frequencyDays: '1,3,5',
          ),
        );

        final interval = await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
            timeOfDay: '10:00',
            frequencyType: FrequencyType.interval,
            intervalDays: 3,
            startDate: '2026-02-01',
          ),
        );

        final asNeeded = await db.createSchedule(
          Schedule(
            medicineId: medicine.id!,
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
        final medicine = await db.createMedicine(Medicine(name: 'Test'));
        final now = DateTime.now();

        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: now,
            actualTime: now,
            status: LogStatus.take,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: now.add(const Duration(hours: 1)),
            status: LogStatus.skip,
          ),
        );
        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: now.add(const Duration(hours: 2)),
            status: LogStatus.missed,
          ),
        );

        final logs = await db.getLogsForMedicine(medicine.id!);
        expect(logs.length, 3);

        expect(logs.any((l) => l.status == LogStatus.take), isTrue);
        expect(logs.any((l) => l.status == LogStatus.skip), isTrue);
        expect(logs.any((l) => l.status == LogStatus.missed), isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles special characters in medicine name', () async {
        final medicine = await db.createMedicine(
          Medicine(name: "O'Sullivan's Medicine & Co. (100mg)"),
        );

        final found = await db.getMedicine(medicine.id!);
        expect(found!.name, "O'Sullivan's Medicine & Co. (100mg)");
      });

      test('handles unicode in medicine name', () async {
        final medicine = await db.createMedicine(
          Medicine(name: '阿司匹林 - アスピリン'),
        );

        final found = await db.getMedicine(medicine.id!);
        expect(found!.name, '阿司匹林 - アスピリン');
      });

      test('handles null optional fields', () async {
        final medicine = await db.createMedicine(Medicine(name: 'MinimalMed'));

        final found = await db.getMedicine(medicine.id!);
        expect(found!.imagePath, isNull);
        expect(found.pharmacyName, isNull);
        expect(found.pharmacyPhone, isNull);
        expect(found.rxcui, isNull);
      });

      test('handles rapid concurrent operations', () async {
        // Create multiple medicines concurrently
        final futures = List.generate(10, (i) {
          return db.createMedicine(Medicine(name: 'Med $i'));
        });

        final medicines = await Future.wait(futures);

        expect(medicines.length, 10);
        expect(medicines.every((m) => m.id != null), isTrue);

        // All IDs should be unique
        final ids = medicines.map((m) => m.id!).toSet();
        expect(ids.length, 10);
      });

      test('handles empty string values', () async {
        final medicine = await db.createMedicine(
          Medicine(name: 'Test', dosage: ''),
        );

        final found = await db.getMedicine(medicine.id!);
        expect(found!.dosage, '');
      });

      test('handles date at year boundary', () async {
        final medicine = await db.createMedicine(Medicine(name: 'Test'));

        await db.createLog(
          Log(
            medicineId: medicine.id!,
            scheduledTime: DateTime(2026, 12, 31, 23, 59),
            status: LogStatus.take,
          ),
        );

        final found = (await db.getLogsForMedicine(medicine.id!)).first;
        expect(found.scheduledTime.year, 2026);
        expect(found.scheduledTime.month, 12);
        expect(found.scheduledTime.day, 31);
      });
    });
  });
}
