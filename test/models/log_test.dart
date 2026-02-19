import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/log.dart';

void main() {
  group('Log Model', () {
    group('LogStatus Enum', () {
      test('has expected values', () {
        expect(LogStatus.values.length, 3);
        expect(LogStatus.values.contains(LogStatus.take), isTrue);
        expect(LogStatus.values.contains(LogStatus.skip), isTrue);
        expect(LogStatus.values.contains(LogStatus.missed), isTrue);
      });
    });

    group('Constructor', () {
      test('creates log with required fields', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log.medicineId, 1);
        expect(log.scheduledTime, scheduledTime);
        expect(log.status, LogStatus.take);
        expect(log.id, isNull);
        expect(log.actualTime, isNull);
      });

      test('creates log with all fields', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 15);
        final log = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.id, 1);
        expect(log.medicineId, 2);
        expect(log.scheduledTime, scheduledTime);
        expect(log.actualTime, actualTime);
        expect(log.status, LogStatus.take);
      });
    });

    group('takenOnTime', () {
      test('returns true when taken within 30 minutes', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 15);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isTrue);
      });

      test('returns true when taken exactly at scheduled time', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isTrue);
      });

      test('returns true when taken exactly 30 minutes late', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 30);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isTrue);
      });

      test('returns false when taken more than 30 minutes late', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 31);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isFalse);
      });

      test('returns true when taken 30 minutes early', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 7, 30);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isTrue);
      });

      test('returns false when status is not take', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: scheduledTime,
          status: LogStatus.skip,
        );

        expect(log.takenOnTime, isFalse);
      });

      test('returns false when actualTime is null', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log.takenOnTime, isFalse);
      });
    });

    group('minutesDifference', () {
      test('returns 0 when actualTime is null', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log.minutesDifference, 0);
      });

      test('returns positive difference when taken late', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 15);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.minutesDifference, 15);
      });

      test('returns negative difference when taken early', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 7, 45);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        expect(log.minutesDifference, -15);
      });

      test('returns 0 when taken exactly on time', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          actualTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log.minutesDifference, 0);
      });
    });

    group('statusText', () {
      test('returns "Taken" for take status', () {
        final log = Log(
          medicineId: 1,
          scheduledTime: DateTime.now(),
          status: LogStatus.take,
        );

        expect(log.statusText, 'Taken');
      });

      test('returns "Skipped" for skip status', () {
        final log = Log(
          medicineId: 1,
          scheduledTime: DateTime.now(),
          status: LogStatus.skip,
        );

        expect(log.statusText, 'Skipped');
      });

      test('returns "Missed" for missed status', () {
        final log = Log(
          medicineId: 1,
          scheduledTime: DateTime.now(),
          status: LogStatus.missed,
        );

        expect(log.statusText, 'Missed');
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 15);
        final log = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        final map = log.toMap();

        expect(map['id'], 1);
        expect(map['medicine_id'], 2);
        expect(map['scheduled_time'], scheduledTime.toIso8601String());
        expect(map['actual_time'], actualTime.toIso8601String());
        expect(map['status'], 'take');
      });

      test('toMap handles null actualTime', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.missed,
        );

        final map = log.toMap();

        expect(map['actual_time'], isNull);
      });

      test('fromMap creates correct Log', () {
        final map = {
          'id': 1,
          'medicine_id': 2,
          'scheduled_time': '2026-02-02T08:00:00.000',
          'actual_time': '2026-02-02T08:15:00.000',
          'status': 'take',
        };

        final log = Log.fromMap(map);

        expect(log.id, 1);
        expect(log.medicineId, 2);
        expect(log.scheduledTime, DateTime(2026, 2, 2, 8, 0));
        expect(log.actualTime, DateTime(2026, 2, 2, 8, 15));
        expect(log.status, LogStatus.take);
      });

      test('fromMap handles null actualTime', () {
        final map = {
          'id': 1,
          'medicine_id': 2,
          'scheduled_time': '2026-02-02T08:00:00.000',
          'actual_time': null,
          'status': 'missed',
        };

        final log = Log.fromMap(map);

        expect(log.actualTime, isNull);
      });

      test('fromMap defaults to missed for unknown status', () {
        final map = {
          'medicine_id': 1,
          'scheduled_time': '2026-02-02T08:00:00.000',
          'status': 'unknown',
        };

        final log = Log.fromMap(map);

        expect(log.status, LogStatus.missed);
      });

      test('toMap and fromMap are reversible', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 15);
        final original = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        final restored = Log.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.medicineId, original.medicineId);
        expect(restored.scheduledTime, original.scheduledTime);
        expect(restored.actualTime, original.actualTime);
        expect(restored.status, original.status);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final original = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        final newActualTime = DateTime(2026, 2, 2, 8, 30);
        final copy = original.copyWith(
          actualTime: newActualTime,
          status: LogStatus.skip,
        );

        expect(copy.id, 1); // unchanged
        expect(copy.medicineId, 2); // unchanged
        expect(copy.scheduledTime, scheduledTime); // unchanged
        expect(copy.actualTime, newActualTime);
        expect(copy.status, LogStatus.skip);
      });

      test('preserves all fields when none specified', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final actualTime = DateTime(2026, 2, 2, 8, 5);
        final original = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          actualTime: actualTime,
          status: LogStatus.take,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.medicineId, original.medicineId);
        expect(copy.scheduledTime, original.scheduledTime);
        expect(copy.actualTime, original.actualTime);
        expect(copy.status, original.status);
      });
    });

    group('Equality', () {
      test('logs with same id are equal', () {
        final log1 = Log(
          id: 1,
          medicineId: 1,
          scheduledTime: DateTime(2026, 2, 2, 8, 0),
          status: LogStatus.take,
        );
        final log2 = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: DateTime(2026, 2, 3, 9, 0),
          status: LogStatus.skip,
        );

        expect(log1 == log2, isTrue);
      });

      test('logs with different ids are not equal', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log1 = Log(
          id: 1,
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );
        final log2 = Log(
          id: 2,
          medicineId: 1,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        expect(log1 == log2, isFalse);
      });

      test('hashCode is based on id', () {
        final log1 = Log(
          id: 1,
          medicineId: 1,
          scheduledTime: DateTime.now(),
          status: LogStatus.take,
        );
        final log2 = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: DateTime.now(),
          status: LogStatus.skip,
        );

        expect(log1.hashCode, log2.hashCode);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final scheduledTime = DateTime(2026, 2, 2, 8, 0);
        final log = Log(
          id: 1,
          medicineId: 2,
          scheduledTime: scheduledTime,
          status: LogStatus.take,
        );

        final str = log.toString();
        expect(str.contains('Log'), isTrue);
        expect(str.contains('id: 1'), isTrue);
        expect(str.contains('medicineId: 2'), isTrue);
        expect(str.contains('take'), isTrue);
      });
    });
  });
}
