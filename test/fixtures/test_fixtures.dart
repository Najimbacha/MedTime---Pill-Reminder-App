/// Test fixtures for creating test data
/// Provides factory methods for creating Medicine, Schedule, Log, and other models

import 'package:privacy_meds/models/medicine.dart';
import 'package:privacy_meds/models/schedule.dart';
import 'package:privacy_meds/models/log.dart';
import 'package:privacy_meds/models/snoozed_dose.dart';
import 'package:privacy_meds/models/emergency_info.dart';
import 'package:privacy_meds/models/caregiver.dart';

/// Factory for creating test Medicine objects
class MedicineFixtures {
  /// Creates a default test medicine
  static Medicine create({
    int? id,
    String name = 'Test Medicine',
    String dosage = '100mg',
    int typeIcon = 1,
    int currentStock = 30,
    int lowStockThreshold = 5,
    int color = 0xFF2196F3,
    String? imagePath,
    String? pharmacyName,
    String? pharmacyPhone,
    String? rxcui,
  }) {
    return Medicine(
      id: id,
      name: name,
      dosage: dosage,
      typeIcon: typeIcon,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
      color: color,
      imagePath: imagePath,
      pharmacyName: pharmacyName,
      pharmacyPhone: pharmacyPhone,
      rxcui: rxcui,
    );
  }

  /// Creates a medicine with low stock
  static Medicine lowStock({int? id, String name = 'Low Stock Med'}) {
    return create(id: id, name: name, currentStock: 3, lowStockThreshold: 5);
  }

  /// Creates a medicine at exactly threshold
  static Medicine atThreshold({int? id, String name = 'Threshold Med'}) {
    return create(id: id, name: name, currentStock: 5, lowStockThreshold: 5);
  }

  /// Creates a medicine with plenty of stock
  static Medicine highStock({int? id, String name = 'High Stock Med'}) {
    return create(id: id, name: name, currentStock: 100, lowStockThreshold: 5);
  }

  /// Creates a list of test medicines
  static List<Medicine> createList(int count) {
    return List.generate(
      count,
      (i) => create(id: i + 1, name: 'Medicine ${i + 1}'),
    );
  }
}

/// Factory for creating test Schedule objects
class ScheduleFixtures {
  /// Creates a daily schedule
  static Schedule daily({
    int? id,
    int medicineId = 1,
    String timeOfDay = '08:00',
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.daily,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Creates a specific days schedule (MWF by default)
  static Schedule specificDays({
    int? id,
    int medicineId = 1,
    String timeOfDay = '08:00',
    String frequencyDays = '1,3,5', // Mon, Wed, Fri
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      medicineId: medicineId,
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
    int medicineId = 1,
    String timeOfDay = '08:00',
    int intervalDays = 3,
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id,
      medicineId: medicineId,
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
    int medicineId = 1,
    String timeOfDay = '08:00',
  }) {
    return Schedule(
      id: id,
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      frequencyType: FrequencyType.asNeeded,
    );
  }
}

/// Factory for creating test Log objects
class LogFixtures {
  /// Creates a "taken" log
  static Log taken({
    int? id,
    int medicineId = 1,
    DateTime? scheduledTime,
    DateTime? actualTime,
  }) {
    final scheduled = scheduledTime ?? DateTime.now();
    return Log(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduled,
      actualTime: actualTime ?? scheduled,
      status: LogStatus.take,
    );
  }

  /// Creates a "taken late" log (more than 30 mins after scheduled)
  static Log takenLate({int? id, int medicineId = 1, DateTime? scheduledTime}) {
    final scheduled = scheduledTime ?? DateTime.now();
    return Log(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduled,
      actualTime: scheduled.add(const Duration(minutes: 45)),
      status: LogStatus.take,
    );
  }

  /// Creates a "skipped" log
  static Log skipped({int? id, int medicineId = 1, DateTime? scheduledTime}) {
    return Log(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduledTime ?? DateTime.now(),
      status: LogStatus.skip,
    );
  }

  /// Creates a "missed" log
  static Log missed({int? id, int medicineId = 1, DateTime? scheduledTime}) {
    return Log(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduledTime ?? DateTime.now(),
      status: LogStatus.missed,
    );
  }
}

/// Factory for creating test SnoozedDose objects
class SnoozedDoseFixtures {
  /// Creates a snoozed dose that's still active
  static SnoozedDose active({
    int? id,
    int medicineId = 1,
    DateTime? originalScheduledTime,
    int snoozeMinutes = 10,
  }) {
    final original = originalScheduledTime ?? DateTime.now();
    return SnoozedDose(
      id: id,
      medicineId: medicineId,
      originalScheduledTime: original,
      snoozedUntil: DateTime.now().add(Duration(minutes: snoozeMinutes)),
    );
  }

  /// Creates an expired snoozed dose
  static SnoozedDose expired({int? id, int medicineId = 1}) {
    final now = DateTime.now();
    return SnoozedDose(
      id: id,
      medicineId: medicineId,
      originalScheduledTime: now.subtract(const Duration(hours: 1)),
      snoozedUntil: now.subtract(const Duration(minutes: 30)),
    );
  }
}

/// Factory for creating test EmergencyInfo objects
class EmergencyInfoFixtures {
  /// Creates a complete emergency info
  static EmergencyInfo complete() {
    return EmergencyInfo(
      bloodGroup: 'O+',
      allergies: 'Penicillin, Peanuts',
      chronicConditions: 'Diabetes Type 2',
      medications: 'Metformin 500mg',
      emergencyContactName: 'John Doe',
      emergencyContactPhone: '+1234567890',
    );
  }

  /// Creates an empty emergency info
  static EmergencyInfo empty() {
    return EmergencyInfo();
  }
}

/// Factory for creating test Caregiver objects
class CaregiverFixtures {
  /// Creates a caregiver with all notifications enabled
  static Caregiver withAllNotifications({
    String name = 'Test Caregiver',
    String phoneNumber = '+1234567890',
  }) {
    return Caregiver(
      name: name,
      phoneNumber: phoneNumber,
      notifyOnMissedDose: true,
      notifyOnLowStock: true,
    );
  }

  /// Creates a caregiver with no notifications
  static Caregiver withNoNotifications({
    String name = 'Silent Caregiver',
    String phoneNumber = '+0987654321',
  }) {
    return Caregiver(
      name: name,
      phoneNumber: phoneNumber,
      notifyOnMissedDose: false,
      notifyOnLowStock: false,
    );
  }
}
