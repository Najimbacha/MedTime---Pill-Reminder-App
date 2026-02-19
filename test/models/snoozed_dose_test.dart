import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/snoozed_dose.dart';

void main() {
  group('SnoozedDose Model', () {
    group('Constructor', () {
      test('creates snoozed dose with required fields', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);
        final snoozedUntil = DateTime(2026, 2, 2, 8, 10);

        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: originalTime,
          snoozedUntil: snoozedUntil,
        );

        expect(dose.medicineId, 1);
        expect(dose.originalScheduledTime, originalTime);
        expect(dose.snoozedUntil, snoozedUntil);
        expect(dose.id, isNull);
        expect(dose.createdAt, isNotNull);
      });

      test('creates snoozed dose with all fields', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);
        final snoozedUntil = DateTime(2026, 2, 2, 8, 10);
        final createdAt = DateTime(2026, 2, 2, 8, 0);

        final dose = SnoozedDose(
          id: 1,
          medicineId: 2,
          originalScheduledTime: originalTime,
          snoozedUntil: snoozedUntil,
          createdAt: createdAt,
        );

        expect(dose.id, 1);
        expect(dose.medicineId, 2);
        expect(dose.originalScheduledTime, originalTime);
        expect(dose.snoozedUntil, snoozedUntil);
        expect(dose.createdAt, createdAt);
      });

      test('defaults createdAt to now when not provided', () {
        final before = DateTime.now();

        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        );

        final after = DateTime.now();

        expect(
          dose.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          dose.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });
    });

    group('isExpired', () {
      test('returns true when snoozed time has passed', () {
        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime.now().subtract(
            const Duration(hours: 1),
          ),
          snoozedUntil: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        expect(dose.isExpired, isTrue);
      });

      test('returns false when snoozed time is in the future', () {
        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        );

        expect(dose.isExpired, isFalse);
      });
    });

    group('remainingTime', () {
      test('returns zero duration when expired', () {
        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime.now().subtract(
            const Duration(hours: 1),
          ),
          snoozedUntil: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        expect(dose.remainingTime, Duration.zero);
      });

      test('returns positive duration when not expired', () {
        final snoozedUntil = DateTime.now().add(const Duration(minutes: 10));
        final dose = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime.now(),
          snoozedUntil: snoozedUntil,
        );

        final remaining = dose.remainingTime;

        // Should be approximately 10 minutes (allow 5 second margin)
        expect(remaining.inMinutes, greaterThanOrEqualTo(9));
        expect(remaining.inMinutes, lessThanOrEqualTo(10));
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);
        final snoozedUntil = DateTime(2026, 2, 2, 8, 10);
        final createdAt = DateTime(2026, 2, 2, 8, 0);

        final dose = SnoozedDose(
          id: 1,
          medicineId: 2,
          originalScheduledTime: originalTime,
          snoozedUntil: snoozedUntil,
          createdAt: createdAt,
        );

        final map = dose.toMap();

        expect(map['id'], 1);
        expect(map['medicine_id'], 2);
        expect(map['original_scheduled_time'], originalTime.toIso8601String());
        expect(map['snoozed_until'], snoozedUntil.toIso8601String());
        expect(map['created_at'], createdAt.toIso8601String());
      });

      test('fromMap creates correct SnoozedDose', () {
        final map = {
          'id': 1,
          'medicine_id': 2,
          'original_scheduled_time': '2026-02-02T08:00:00.000',
          'snoozed_until': '2026-02-02T08:10:00.000',
          'created_at': '2026-02-02T08:00:00.000',
        };

        final dose = SnoozedDose.fromMap(map);

        expect(dose.id, 1);
        expect(dose.medicineId, 2);
        expect(dose.originalScheduledTime, DateTime(2026, 2, 2, 8, 0));
        expect(dose.snoozedUntil, DateTime(2026, 2, 2, 8, 10));
        expect(dose.createdAt, DateTime(2026, 2, 2, 8, 0));
      });

      test('toMap and fromMap are reversible', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);
        final snoozedUntil = DateTime(2026, 2, 2, 8, 10);
        final createdAt = DateTime(2026, 2, 2, 8, 0);

        final original = SnoozedDose(
          id: 1,
          medicineId: 2,
          originalScheduledTime: originalTime,
          snoozedUntil: snoozedUntil,
          createdAt: createdAt,
        );

        final restored = SnoozedDose.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.medicineId, original.medicineId);
        expect(restored.originalScheduledTime, original.originalScheduledTime);
        expect(restored.snoozedUntil, original.snoozedUntil);
        expect(restored.createdAt, original.createdAt);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);
        final snoozedUntil = DateTime(2026, 2, 2, 8, 10);

        final original = SnoozedDose(
          id: 1,
          medicineId: 2,
          originalScheduledTime: originalTime,
          snoozedUntil: snoozedUntil,
        );

        final newSnoozedUntil = DateTime(2026, 2, 2, 8, 20);
        final copy = original.copyWith(snoozedUntil: newSnoozedUntil);

        expect(copy.id, 1); // unchanged
        expect(copy.medicineId, 2); // unchanged
        expect(copy.originalScheduledTime, originalTime); // unchanged
        expect(copy.snoozedUntil, newSnoozedUntil);
      });
    });

    group('Equality', () {
      test(
        'doses with same medicineId and originalScheduledTime are equal',
        () {
          final originalTime = DateTime(2026, 2, 2, 8, 0);

          final dose1 = SnoozedDose(
            id: 1,
            medicineId: 1,
            originalScheduledTime: originalTime,
            snoozedUntil: DateTime(2026, 2, 2, 8, 10),
          );
          final dose2 = SnoozedDose(
            id: 2,
            medicineId: 1,
            originalScheduledTime: originalTime,
            snoozedUntil: DateTime(2026, 2, 2, 8, 20),
          );

          expect(dose1 == dose2, isTrue);
        },
      );

      test('doses with different medicineId are not equal', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);

        final dose1 = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: originalTime,
          snoozedUntil: DateTime(2026, 2, 2, 8, 10),
        );
        final dose2 = SnoozedDose(
          medicineId: 2,
          originalScheduledTime: originalTime,
          snoozedUntil: DateTime(2026, 2, 2, 8, 10),
        );

        expect(dose1 == dose2, isFalse);
      });

      test('doses with different originalScheduledTime are not equal', () {
        final dose1 = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime(2026, 2, 2, 8, 0),
          snoozedUntil: DateTime(2026, 2, 2, 8, 10),
        );
        final dose2 = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: DateTime(2026, 2, 2, 9, 0),
          snoozedUntil: DateTime(2026, 2, 2, 9, 10),
        );

        expect(dose1 == dose2, isFalse);
      });

      test('hashCode is based on medicineId and originalScheduledTime', () {
        final originalTime = DateTime(2026, 2, 2, 8, 0);

        final dose1 = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: originalTime,
          snoozedUntil: DateTime(2026, 2, 2, 8, 10),
        );
        final dose2 = SnoozedDose(
          medicineId: 1,
          originalScheduledTime: originalTime,
          snoozedUntil: DateTime(2026, 2, 2, 8, 20),
        );

        expect(dose1.hashCode, dose2.hashCode);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final dose = SnoozedDose(
          id: 1,
          medicineId: 2,
          originalScheduledTime: DateTime(2026, 2, 2, 8, 0),
          snoozedUntil: DateTime(2026, 2, 2, 8, 10),
        );

        final str = dose.toString();
        expect(str.contains('SnoozedDose'), isTrue);
        expect(str.contains('id: 1'), isTrue);
        expect(str.contains('medicineId: 2'), isTrue);
      });
    });
  });
}
