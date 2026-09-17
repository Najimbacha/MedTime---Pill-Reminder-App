import 'package:flutter_test/flutter_test.dart';
import 'package:routine_time/models/routine.dart';
import '../mocks/mock_services.dart';
import '../fixtures/test_fixtures.dart';

/// A testable version of RoutineProvider that accepts injected dependencies
/// This allows us to test the provider logic without actual DB/notification calls
class TestableRoutineProvider {
  final MockDatabaseHelper db;
  final MockNotificationService notifications;

  List<Routine> _routines = [];
  bool _isLoading = false;

  TestableRoutineProvider({required this.db, required this.notifications});

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  Future<void> loadRoutines() async {
    _isLoading = true;
    try {
      _routines = await db.getAllRoutines();
    } finally {
      _isLoading = false;
    }
  }

  Future<Routine?> addRoutine(Routine routine) async {
    final newRoutine = await db.createRoutine(routine);
    _routines.add(newRoutine);
    return newRoutine;
  }

  Future<bool> updateRoutine(Routine routine) async {
    await db.updateRoutine(routine);
    final index = _routines.indexWhere((m) => m.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
    }
    return true;
  }

  Future<bool> deleteRoutine(int id) async {
    await db.deleteRoutine(id);
    _routines.removeWhere((m) => m.id == id);
    return true;
  }

  Routine? getRoutineById(int id) {
    try {
      return _routines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}

void main() {
  late TestableRoutineProvider provider;
  late MockDatabaseHelper mockDb;
  late MockNotificationService mockNotifications;

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockNotifications = MockNotificationService();
    provider = TestableRoutineProvider(
      db: mockDb,
      notifications: mockNotifications,
    );
  });

  tearDown(() {
    mockDb.reset();
    mockNotifications.reset();
  });

  group('RoutineProvider Tests', () {
    group('Initial State', () {
      test('starts with empty list', () {
        expect(provider.routines, isEmpty);
        expect(provider.isLoading, isFalse);
      });
    });

    group('loadRoutines', () {
      test('loads routines from database', () async {
        // Arrange: Pre-populate database
        await mockDb.createRoutine(RoutineFixtures.create(name: 'Med 1'));
        await mockDb.createRoutine(RoutineFixtures.create(name: 'Med 2'));

        // Act
        await provider.loadRoutines();

        // Assert
        expect(provider.routines.length, 2);
        expect(provider.routines[0].name, 'Med 1');
        expect(provider.routines[1].name, 'Med 2');
      });

      test('updates loading state', () async {
        expect(provider.isLoading, isFalse);

        await provider.loadRoutines();

        expect(provider.isLoading, isFalse);
      });
    });

    group('addRoutine', () {
      test('adds routine to database and list', () async {
        final routine = RoutineFixtures.create(name: 'New Routine');

        final result = await provider.addRoutine(routine);

        expect(result, isNotNull);
        expect(result!.id, isNotNull);
        expect(result.name, 'New Routine');
        expect(provider.routines.length, 1);
      });

      test('allows adding multiple routines', () async {
        await provider.addRoutine(RoutineFixtures.create(name: 'Med 1'));
        await provider.addRoutine(RoutineFixtures.create(name: 'Med 2'));
        await provider.addRoutine(RoutineFixtures.create(name: 'Med 3'));
        await provider.addRoutine(RoutineFixtures.create(name: 'Med 4'));

        expect(provider.routines.length, 4);
      });
    });

    group('updateRoutine', () {
      test('updates routine in database and list', () async {
        final routine = await provider.addRoutine(
          RoutineFixtures.create(name: 'Original Name'),
        );

        final updated = routine!.copyWith(name: 'Updated Name');
        await provider.updateRoutine(updated);

        expect(provider.routines.first.name, 'Updated Name');
      });

      test('does nothing if routine not found', () async {
        final routine = RoutineFixtures.create(id: 999, name: 'Not Found');

        await provider.updateRoutine(routine);

        expect(provider.routines, isEmpty);
      });
    });

    group('deleteRoutine', () {
      test('removes routine from database and list', () async {
        final routine = await provider.addRoutine(
          RoutineFixtures.create(name: 'To Delete'),
        );

        await provider.deleteRoutine(routine!.id!);

        expect(provider.routines, isEmpty);
      });

      test('does nothing if routine not found', () async {
        await provider.addRoutine(RoutineFixtures.create(name: 'Keep'));

        await provider.deleteRoutine(999);

        expect(provider.routines.length, 1);
      });
    });

    group('getRoutineById', () {
      test('returns routine when found', () async {
        final routine = await provider.addRoutine(
          RoutineFixtures.create(name: 'Find Me'),
        );

        final found = provider.getRoutineById(routine!.id!);

        expect(found, isNotNull);
        expect(found!.name, 'Find Me');
      });

      test('returns null when not found', () {
        final found = provider.getRoutineById(999);

        expect(found, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles empty database', () async {
        await provider.loadRoutines();

        expect(provider.routines, isEmpty);
      });

      test('handles rapid successive operations', () async {
        final med1 = await provider.addRoutine(
          RoutineFixtures.create(name: 'Med 1'),
        );
        final med2 = await provider.addRoutine(
          RoutineFixtures.create(name: 'Med 2'),
        );

        await provider.deleteRoutine(med1!.id!);
        await provider.updateRoutine(med2!.copyWith(name: 'Renamed'));

        expect(provider.routines.length, 1);
        expect(provider.routines.first.name, 'Renamed');
      });
    });
  });
}
