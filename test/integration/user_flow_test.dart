/// End-to-end user flow integration tests
/// Tests complete user scenarios from medicine creation to adherence tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:privacy_meds/models/medicine.dart';
import 'package:privacy_meds/models/schedule.dart';
import 'package:privacy_meds/models/log.dart';
import 'package:privacy_meds/models/snoozed_dose.dart';

/// Integrated test harness that simulates the full app flow
class IntegrationTestHarness {
  Database? _database;

  // In-memory caches (simulating providers)
  List<Medicine> medicines = [];
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

  // ==================== User Actions ====================

  /// User adds a new medicine with schedules
  Future<Medicine> addMedicine({
    required String name,
    required String dosage,
    required int currentStock,
    required int lowStockThreshold,
    required List<String> scheduleTimes,
    FrequencyType frequencyType = FrequencyType.daily,
  }) async {
    final db = _database!;

    // Create medicine
    final medicineId = await db.insert('medicines', {
      'name': name,
      'dosage': dosage,
      'current_stock': currentStock,
      'low_stock_threshold': lowStockThreshold,
      'type_icon': 1,
      'color': 0xFF2196F3,
    });

    final medicine = Medicine(
      id: medicineId,
      name: name,
      dosage: dosage,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
    );
    medicines.add(medicine);

    // Create schedules
    for (final time in scheduleTimes) {
      final scheduleId = await db.insert('schedules', {
        'medicine_id': medicineId,
        'time_of_day': time,
        'frequency_type': frequencyType.name,
      });
      schedules.add(
        Schedule(
          id: scheduleId,
          medicineId: medicineId,
          timeOfDay: time,
          frequencyType: frequencyType,
        ),
      );
    }

    return medicine;
  }

  /// User takes their medicine
  Future<Log> takeMedicine(int medicineId, DateTime scheduledTime) async {
    final db = _database!;
    final now = DateTime.now();

    // Create log
    final logId = await db.insert('logs', {
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': now.toIso8601String(),
      'status': 'take',
    });

    final log = Log(
      id: logId,
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: now,
      status: LogStatus.take,
    );
    logs.add(log);

    // Decrement stock
    await db.rawUpdate(
      'UPDATE medicines SET current_stock = current_stock - 1 WHERE id = ? AND current_stock > 0',
      [medicineId],
    );

    // Update local cache
    final index = medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      medicines[index] = medicines[index].copyWith(
        currentStock: medicines[index].currentStock - 1,
      );
    }

    return log;
  }

  /// User skips their medicine
  Future<Log> skipMedicine(int medicineId, DateTime scheduledTime) async {
    final db = _database!;

    final logId = await db.insert('logs', {
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': null,
      'status': 'skip',
    });

    final log = Log(
      id: logId,
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      status: LogStatus.skip,
    );
    logs.add(log);

    return log;
  }

  /// User snoozes a dose
  Future<SnoozedDose> snoozeDose({
    required int medicineId,
    required DateTime scheduledTime,
    required int minutes,
  }) async {
    final db = _database!;
    final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));

    // Delete existing snooze for same medicine/time
    await db.delete(
      'snoozed_doses',
      where: 'medicine_id = ? AND original_scheduled_time = ?',
      whereArgs: [medicineId, scheduledTime.toIso8601String()],
    );

    final id = await db.insert('snoozed_doses', {
      'medicine_id': medicineId,
      'original_scheduled_time': scheduledTime.toIso8601String(),
      'snoozed_until': snoozedUntil.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    final dose = SnoozedDose(
      id: id,
      medicineId: medicineId,
      originalScheduledTime: scheduledTime,
      snoozedUntil: snoozedUntil,
    );

    final key = '${medicineId}_${scheduledTime.toIso8601String()}';
    snoozedDoses[key] = dose;

    return dose;
  }

  /// User deletes a medicine
  Future<void> deleteMedicine(int medicineId) async {
    final db = _database!;

    await db.delete('medicines', where: 'id = ?', whereArgs: [medicineId]);
    await db.delete(
      'schedules',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
    await db.delete('logs', where: 'medicine_id = ?', whereArgs: [medicineId]);
    await db.delete(
      'snoozed_doses',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );

    medicines.removeWhere((m) => m.id == medicineId);
    schedules.removeWhere((s) => s.medicineId == medicineId);
    logs.removeWhere((l) => l.medicineId == medicineId);
    snoozedDoses.removeWhere((k, v) => v.medicineId == medicineId);
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

      final medicine = medicines.firstWhere(
        (m) => m.id == schedule.medicineId,
        orElse: () => Medicine(name: 'Unknown'),
      );

      // Check if already logged
      final hasLog = logs.any(
        (l) =>
            l.medicineId == schedule.medicineId &&
            l.scheduledTime.year == scheduledTime.year &&
            l.scheduledTime.month == scheduledTime.month &&
            l.scheduledTime.day == scheduledTime.day &&
            l.scheduledTime.hour == scheduledTime.hour &&
            l.scheduledTime.minute == scheduledTime.minute,
      );

      result.add({
        'medicine': medicine,
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

  /// Get low stock medicines
  List<Medicine> getLowStockMedicines() {
    return medicines.where((m) => m.isLowStock).toList();
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
    group('Complete Medicine Workflow', () {
      test('User adds medicine → schedules dose → takes medicine', () async {
        // 1. User adds a new medicine
        final medicine = await harness.addMedicine(
          name: 'Aspirin',
          dosage: '100mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00', '20:00'],
        );

        expect(harness.medicines.length, 1);
        expect(harness.schedules.length, 2);

        // 2. User gets their scheduled doses for today
        final today = DateTime.now();
        final doses = harness.getScheduledDosesForDate(today);

        expect(doses.length, 2);
        expect(doses.every((d) => d['hasLog'] == false), isTrue);

        // 3. User takes their morning dose
        final morningDose = doses.firstWhere(
          (d) => (d['schedule'] as Schedule).timeOfDay == '08:00',
        );
        await harness.takeMedicine(
          medicine.id!,
          morningDose['scheduledTime'] as DateTime,
        );

        expect(harness.logs.length, 1);
        expect(harness.logs.first.status, LogStatus.take);
        expect(harness.medicines.first.currentStock, 29);
      });

      test('User maintains adherence over multiple days', () async {
        final medicine = await harness.addMedicine(
          name: 'Daily Vitamin',
          dosage: '1 tablet',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['09:00'],
        );

        // Simulate 7 days of taking medication
        final startDate = DateTime.now();

        for (var i = 0; i < 7; i++) {
          final date = startDate.add(Duration(days: i));
          final scheduledTime = DateTime(date.year, date.month, date.day, 9, 0);

          await harness.takeMedicine(medicine.id!, scheduledTime);
        }

        expect(harness.logs.length, 7);
        expect(harness.medicines.first.currentStock, 23);

        // Calculate adherence
        final adherence = harness.calculateAdherenceRate(
          startDate,
          startDate.add(const Duration(days: 8)),
        );
        expect(adherence, 1.0); // 100% adherence
      });

      test('User skips some doses → partial adherence', () async {
        final medicine = await harness.addMedicine(
          name: 'Medication',
          dosage: '50mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
        );

        final now = DateTime.now();
        final startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ); // Start of day

        // Take for 3 days, skip for 2 days
        for (var i = 0; i < 5; i++) {
          final date = startDate.add(Duration(days: i));
          final scheduledTime = DateTime(date.year, date.month, date.day, 8, 0);

          if (i < 3) {
            await harness.takeMedicine(medicine.id!, scheduledTime);
          } else {
            await harness.skipMedicine(medicine.id!, scheduledTime);
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

    group('Stock Management', () {
      test('Stock depletes correctly with each dose', () async {
        final medicine = await harness.addMedicine(
          name: 'Limited Stock Med',
          dosage: '25mg',
          currentStock: 5,
          lowStockThreshold: 3,
          scheduleTimes: ['08:00'],
        );

        expect(harness.getLowStockMedicines(), isEmpty);

        // Take 3 doses
        for (var i = 0; i < 3; i++) {
          final scheduledTime = DateTime.now().add(Duration(hours: i));
          await harness.takeMedicine(medicine.id!, scheduledTime);
        }

        // Check stock
        expect(harness.medicines.first.currentStock, 2);

        // Now should be low stock
        expect(harness.getLowStockMedicines().length, 1);
      });

      test('Low stock alert triggers at threshold', () async {
        final medicine = await harness.addMedicine(
          name: 'Threshold Test',
          dosage: '10mg',
          currentStock: 6,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
        );

        // Stock is 6, threshold is 5 - not low stock
        expect(medicine.isLowStock, isFalse);

        // Take one dose
        await harness.takeMedicine(medicine.id!, DateTime.now());

        // Stock is now 5, at threshold - IS low stock
        expect(harness.medicines.first.currentStock, 5);
        expect(harness.medicines.first.isLowStock, isTrue);
      });
    });

    group('Snooze Workflow', () {
      test('User snoozes dose → takes later', () async {
        final medicine = await harness.addMedicine(
          name: 'Snooze Test Med',
          dosage: '100mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
        );

        final scheduledTime = DateTime.now();

        // User snoozes for 10 minutes
        final snooze = await harness.snoozeDose(
          medicineId: medicine.id!,
          scheduledTime: scheduledTime,
          minutes: 10,
        );

        expect(harness.snoozedDoses.length, 1);
        expect(snooze.snoozedUntil.isAfter(DateTime.now()), isTrue);

        // Later, user takes the dose
        await harness.takeMedicine(medicine.id!, scheduledTime);

        expect(harness.logs.length, 1);
        expect(harness.logs.first.status, LogStatus.take);
      });

      test('Multiple snoozes replace previous', () async {
        final medicine = await harness.addMedicine(
          name: 'Multi Snooze',
          dosage: '50mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
        );

        final scheduledTime = DateTime.now();

        // Snooze for 10 minutes
        await harness.snoozeDose(
          medicineId: medicine.id!,
          scheduledTime: scheduledTime,
          minutes: 10,
        );

        // Snooze again for 20 minutes
        await harness.snoozeDose(
          medicineId: medicine.id!,
          scheduledTime: scheduledTime,
          minutes: 20,
        );

        // Should still only have 1 snooze
        expect(harness.snoozedDoses.length, 1);
      });
    });

    group('Delete Medicine Cascade', () {
      test('Deleting medicine removes related data', () async {
        final medicine = await harness.addMedicine(
          name: 'To Delete',
          dosage: '100mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00', '20:00'],
        );

        // Add some activity
        await harness.takeMedicine(medicine.id!, DateTime.now());
        await harness.snoozeDose(
          medicineId: medicine.id!,
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          minutes: 10,
        );

        expect(harness.medicines.length, 1);
        expect(harness.schedules.length, 2);
        expect(harness.logs.length, 1);
        expect(harness.snoozedDoses.length, 1);

        // Delete medicine
        await harness.deleteMedicine(medicine.id!);

        // All related data should be gone
        expect(harness.medicines, isEmpty);
        expect(harness.schedules, isEmpty);
        expect(harness.logs, isEmpty);
        expect(harness.snoozedDoses, isEmpty);
      });
    });

    group('Multiple Medicines', () {
      test('User manages multiple medicines independently', () async {
        final aspirin = await harness.addMedicine(
          name: 'Aspirin',
          dosage: '100mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
        );

        final vitamin = await harness.addMedicine(
          name: 'Vitamin D',
          dosage: '1000 IU',
          currentStock: 90,
          lowStockThreshold: 10,
          scheduleTimes: ['09:00'],
        );

        final insulin = await harness.addMedicine(
          name: 'Insulin',
          dosage: '10 units',
          currentStock: 20,
          lowStockThreshold: 5,
          scheduleTimes: ['07:00', '13:00', '19:00'],
        );

        expect(harness.medicines.length, 3);
        expect(harness.schedules.length, 5); // 1 + 1 + 3

        // Take aspirin and insulin, skip vitamin
        final now = DateTime.now();
        await harness.takeMedicine(aspirin.id!, now);
        await harness.takeMedicine(insulin.id!, now);
        await harness.skipMedicine(vitamin.id!, now);

        // Check stocks
        final updatedAspirin = harness.medicines.firstWhere(
          (m) => m.id == aspirin.id,
        );
        expect(updatedAspirin.currentStock, 29);

        final updatedInsulin = harness.medicines.firstWhere(
          (m) => m.id == insulin.id,
        );
        expect(updatedInsulin.currentStock, 19);

        // Vitamin stock should be unchanged (skipped)
        final updatedVitamin = harness.medicines.firstWhere(
          (m) => m.id == vitamin.id,
        );
        expect(updatedVitamin.currentStock, 90);
      });
    });

    group('Complex Scheduling', () {
      test('Specific days schedule only triggers on correct days', () async {
        await harness.addMedicine(
          name: 'MWF Medicine',
          dosage: '50mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: ['08:00'],
          frequencyType: FrequencyType.specificDays,
        );

        // Manually update the schedule to have specific days
        final schedule = harness.schedules.first;
        harness.schedules[0] = Schedule(
          id: schedule.id,
          medicineId: schedule.medicineId,
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

        expect(harness.medicines, isEmpty);
        expect(harness.getScheduledDosesForDate(today), isEmpty);
        expect(harness.getLowStockMedicines(), isEmpty);
        expect(
          harness.calculateAdherenceRate(
            today,
            today.add(const Duration(days: 1)),
          ),
          0.0,
        );
      });

      test('Handles medicine with no schedules', () async {
        await harness.addMedicine(
          name: 'PRN Only',
          dosage: '25mg',
          currentStock: 30,
          lowStockThreshold: 5,
          scheduleTimes: [], // No schedules
        );

        expect(harness.medicines.length, 1);
        expect(harness.schedules, isEmpty);

        final doses = harness.getScheduledDosesForDate(DateTime.now());
        expect(doses, isEmpty);
      });
    });
  });
}
