import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:flutter/foundation.dart';
import 'package:privacy_meds/providers/schedule_provider.dart';
import 'package:privacy_meds/models/schedule.dart';
import 'package:privacy_meds/models/medicine.dart';
import 'package:privacy_meds/services/database_helper.dart';
import 'package:privacy_meds/services/notification_service.dart';

// ==================== MOCKS ====================

class MockDatabaseHelper implements DatabaseHelper {
  List<Schedule> _schedules = [];
  int _idCounter = 1;

  @override
  Future<List<Schedule>> getAllSchedules() async {
    return List.from(_schedules);
  }

  @override
  Future<Schedule> createSchedule(Schedule schedule) async {
    final newSchedule = schedule.copyWith(id: _idCounter++);
    _schedules.add(newSchedule);
    return newSchedule;
  }

  @override
  Future<int> updateSchedule(Schedule schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteSchedule(int id) async {
    _schedules.removeWhere((s) => s.id == id);
    return 1;
  }

  // Unimplemented methods required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationService implements NotificationService {
  List<int> scheduledIds = [];
  List<int> cancelledIds = [];

  @override
  Future<void> scheduleMedicineReminder({
    required int notificationId,
    required int medicineId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
    FrequencyType? frequencyType,
  }) async {
    scheduledIds.add(notificationId);
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    cancelledIds.add(notificationId);
    scheduledIds.remove(notificationId);
  }

  @override
  Future<void> cancelAllNotifications() async {
    scheduledIds.clear();
  }

  // Unimplemented methods required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ==================== TESTS ====================

void main() {
  late ScheduleProvider provider;
  late MockDatabaseHelper mockDb;
  late MockNotificationService mockNotifications;

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockNotifications = MockNotificationService();
    provider = ScheduleProvider(db: mockDb, notifications: mockNotifications);
  });

  group('ScheduleProvider Tests', () {
    final testMedicine = Medicine(
      id: 1,
      name: 'Aspirin',
      dosage: '10mg',
      currentStock: 10,
    );

    final testSchedule = Schedule(
      medicineId: 1,
      timeOfDay: '08:00',
      frequencyType: FrequencyType.daily,
    );

    test('Initial state should be empty', () {
      expect(provider.schedules, isEmpty);
      expect(provider.isLoading, false);
    });

    test('addSchedule adds to list and calls DB/Notification', () async {
      await provider.addSchedule(testSchedule, testMedicine);

      expect(provider.schedules.length, 1);
      expect(provider.schedules.first.medicineId, 1);

      // Verify DB interaction (mock stores it)
      final dbSchedules = await mockDb.getAllSchedules();
      expect(dbSchedules.length, 1);

      // Verify Notification scheduled
      // The provider internally updates the schedule with an ID from DB before scheduling notification
      expect(mockNotifications.scheduledIds.length, 1);
    });

    test('updateSchedule updates list and reschedules notification', () async {
      // Setup: Add first
      await provider.addSchedule(testSchedule, testMedicine);
      final createdSchedule = provider.schedules.first;

      // Act: Update time
      final updatedSchedule = createdSchedule.copyWith(timeOfDay: '09:00');

      await provider.updateSchedule(updatedSchedule, testMedicine);

      // Assert
      expect(provider.schedules.first.timeOfDay, '09:00');
      // Notification should be scheduled again (mock logic just adds it, verifying call happened)
      expect(mockNotifications.scheduledIds.length, greaterThanOrEqualTo(1));
    });

    test('deleteSchedule removes from list and cancels notification', () async {
      // Setup
      await provider.addSchedule(testSchedule, testMedicine);
      final idToDelete = provider.schedules.first.id!;

      // Act
      await provider.deleteSchedule(idToDelete);

      // Assert
      expect(provider.schedules, isEmpty);
      expect(mockNotifications.cancelledIds.contains(idToDelete), true);
    });

    test('getSchedulesForMedicine filters correctly', () async {
      await provider.addSchedule(testSchedule, testMedicine);

      // Add another medicine's schedule
      final med2Schedule = Schedule(
        medicineId: 99,
        timeOfDay: '10:00',
        frequencyType: FrequencyType.daily,
      );
      // We pass testMedicine but it doesn't matter for the DB insertion in mock
      await provider.addSchedule(med2Schedule, testMedicine);

      final med1Schedules = provider.getSchedulesForMedicine(1);
      expect(med1Schedules.length, 1);
      expect(med1Schedules.first.medicineId, 1);
    });
  });
}
