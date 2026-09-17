import 'package:flutter_test/flutter_test.dart';
import 'package:routine_time/providers/schedule_provider.dart';
import 'package:routine_time/models/schedule.dart';
import 'package:routine_time/models/routine.dart';
import 'package:routine_time/services/database_helper.dart';
import 'package:routine_time/services/notification_service.dart';

// ==================== MOCKS ====================

class MockDatabaseHelper implements DatabaseHelper {
  final List<Schedule> _schedules = [];
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
  Future<void> scheduleRoutineReminder({
    required int notificationId,
    required int routineId,
    required String routineName,
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

  @override
  Future<void> cancelScheduleNotifications({
    required int baseNotificationId,
    FrequencyType? frequencyType,
    List<int> specificDays = const [],
  }) async {
    cancelledIds.add(baseNotificationId);
    scheduledIds.remove(baseNotificationId);

    if (frequencyType == FrequencyType.specificDays) {
      for (final day in specificDays) {
        final derivedId = NotificationService.specificDayNotificationId(
          baseNotificationId,
          day,
        );
        cancelledIds.add(derivedId);
        scheduledIds.remove(derivedId);
      }
    }
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
    final testRoutine = Routine(
      id: 1,
      name: 'Read',
      dosage: '20 min',
    );

    final testSchedule = Schedule(
      routineId: 1,
      timeOfDay: '08:00',
      frequencyType: FrequencyType.daily,
    );

    test('Initial state should be empty', () {
      expect(provider.schedules, isEmpty);
      expect(provider.isLoading, false);
    });

    test('addSchedule adds to list and calls DB/Notification', () async {
      await provider.addSchedule(testSchedule, testRoutine);

      expect(provider.schedules.length, 1);
      expect(provider.schedules.first.routineId, 1);

      // Verify DB interaction (mock stores it)
      final dbSchedules = await mockDb.getAllSchedules();
      expect(dbSchedules.length, 1);

      // Verify Notification scheduled
      // The provider internally updates the schedule with an ID from DB before scheduling notification
      expect(mockNotifications.scheduledIds.length, 1);
    });

    test('updateSchedule updates list and reschedules notification', () async {
      // Setup: Add first
      await provider.addSchedule(testSchedule, testRoutine);
      final createdSchedule = provider.schedules.first;

      // Act: Update time
      final updatedSchedule = createdSchedule.copyWith(timeOfDay: '09:00');

      await provider.updateSchedule(updatedSchedule, testRoutine);

      // Assert
      expect(provider.schedules.first.timeOfDay, '09:00');
      // Notification should be scheduled again (mock logic just adds it, verifying call happened)
      expect(mockNotifications.scheduledIds.length, greaterThanOrEqualTo(1));
    });

    test('deleteSchedule removes from list and cancels notification', () async {
      // Setup
      await provider.addSchedule(testSchedule, testRoutine);
      final idToDelete = provider.schedules.first.id!;

      // Act
      await provider.deleteSchedule(idToDelete);

      // Assert
      expect(provider.schedules, isEmpty);
      expect(mockNotifications.cancelledIds.contains(idToDelete), true);
    });

    test('getSchedulesForRoutine filters correctly', () async {
      await provider.addSchedule(testSchedule, testRoutine);

      // Add another routine's schedule
      final med2Schedule = Schedule(
        routineId: 99,
        timeOfDay: '10:00',
        frequencyType: FrequencyType.daily,
      );
      // We pass testRoutine but it doesn't matter for the DB insertion in mock
      await provider.addSchedule(med2Schedule, testRoutine);

      final med1Schedules = provider.getSchedulesForRoutine(1);
      expect(med1Schedules.length, 1);
      expect(med1Schedules.first.routineId, 1);
    });

    test(
      'specific-days schedule creates one reminder per selected weekday',
      () async {
        final specificDaysSchedule = Schedule(
          routineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5',
        );

        await provider.addSchedule(specificDaysSchedule, testRoutine);
        final created = provider.schedules.first;

        expect(mockNotifications.scheduledIds.length, 3);
        expect(
          mockNotifications.scheduledIds,
          containsAll([
            NotificationService.specificDayNotificationId(created.id!, 1),
            NotificationService.specificDayNotificationId(created.id!, 3),
            NotificationService.specificDayNotificationId(created.id!, 5),
          ]),
        );
      },
    );

    test(
      'deleting specific-days schedule cancels all derived notifications',
      () async {
        final specificDaysSchedule = Schedule(
          routineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '2,4',
        );

        await provider.addSchedule(specificDaysSchedule, testRoutine);
        final created = provider.schedules.first;

        await provider.deleteSchedule(created.id!);

        expect(
          mockNotifications.cancelledIds,
          containsAll([
            created.id!,
            NotificationService.specificDayNotificationId(created.id!, 2),
            NotificationService.specificDayNotificationId(created.id!, 4),
          ]),
        );
      },
    );
  });
}
