import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/schedule.dart';

void main() {
  group('Schedule Model', () {
    group('Constructor and Properties', () {
      test('creates schedule with required fields', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        expect(schedule.medicineId, 1);
        expect(schedule.timeOfDay, '08:00');
        expect(schedule.frequencyType, FrequencyType.daily);
        expect(schedule.id, isNull);
        expect(schedule.frequencyDays, isNull);
        expect(schedule.intervalDays, isNull);
        expect(schedule.startDate, isNull);
        expect(schedule.endDate, isNull);
      });

      test('creates schedule with all fields', () {
        final schedule = Schedule(
          id: 1,
          medicineId: 2,
          timeOfDay: '14:30',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5',
          intervalDays: 3,
          startDate: '2026-01-01',
          endDate: '2026-12-31',
        );

        expect(schedule.id, 1);
        expect(schedule.medicineId, 2);
        expect(schedule.timeOfDay, '14:30');
        expect(schedule.frequencyType, FrequencyType.specificDays);
        expect(schedule.frequencyDays, '1,3,5');
        expect(schedule.intervalDays, 3);
        expect(schedule.startDate, '2026-01-01');
        expect(schedule.endDate, '2026-12-31');
      });
    });

    group('daysList', () {
      test('parses frequency days string correctly', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5',
        );

        expect(schedule.daysList, [1, 3, 5]);
      });

      test('returns empty list when frequencyDays is null', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        expect(schedule.daysList, isEmpty);
      });

      test('returns empty list when frequencyDays is empty', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '',
        );

        expect(schedule.daysList, isEmpty);
      });

      test('handles spaces in frequency days', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1, 3, 5',
        );

        expect(schedule.daysList, [1, 3, 5]);
      });
    });

    group('shouldTriggerOnDate - Daily', () {
      test('triggers every day', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        // Test various days
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)),
          isTrue,
        ); // Monday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 3)),
          isTrue,
        ); // Tuesday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)),
          isTrue,
        ); // Saturday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 8)),
          isTrue,
        ); // Sunday
      });

      test('respects start date', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
          startDate: '2026-02-05',
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 4)), isFalse);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 6)), isTrue);
      });

      test('respects end date', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
          endDate: '2026-02-10',
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 9)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 10)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 11)), isFalse);
      });

      test('respects both start and end date', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
          startDate: '2026-02-05',
          endDate: '2026-02-10',
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 4)), isFalse);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 10)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 11)), isFalse);
      });
    });

    group('shouldTriggerOnDate - Specific Days', () {
      test('triggers only on configured weekdays', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5', // Mon, Wed, Fri
        );

        // Feb 2026: Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=7, Sun=8
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)),
          isTrue,
        ); // Monday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 3)),
          isFalse,
        ); // Tuesday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 4)),
          isTrue,
        ); // Wednesday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)),
          isFalse,
        ); // Thursday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 6)),
          isTrue,
        ); // Friday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)),
          isFalse,
        ); // Saturday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 8)),
          isFalse,
        ); // Sunday
      });

      test('triggers on weekends only', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '6,7', // Sat, Sun
        );

        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 6)),
          isFalse,
        ); // Friday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)),
          isTrue,
        ); // Saturday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 8)),
          isTrue,
        ); // Sunday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 9)),
          isFalse,
        ); // Monday
      });

      test('handles single day', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '5', // Friday only
        );

        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)),
          isFalse,
        ); // Thursday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 6)),
          isTrue,
        ); // Friday
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)),
          isFalse,
        ); // Saturday
      });
    });

    group('shouldTriggerOnDate - Interval', () {
      test('triggers every N days from start date', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.interval,
          intervalDays: 3,
          startDate: '2026-02-01',
        );

        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 1)),
          isTrue,
        ); // Day 0
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)),
          isFalse,
        ); // Day 1
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 3)),
          isFalse,
        ); // Day 2
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 4)),
          isTrue,
        ); // Day 3
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)),
          isFalse,
        ); // Day 4
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 6)),
          isFalse,
        ); // Day 5
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 7)),
          isTrue,
        ); // Day 6
      });

      test('every 2 days', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.interval,
          intervalDays: 2,
          startDate: '2026-02-01',
        );

        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 1)),
          isTrue,
        ); // Day 0
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)),
          isFalse,
        ); // Day 1
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 3)),
          isTrue,
        ); // Day 2
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 4)),
          isFalse,
        ); // Day 3
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 5)),
          isTrue,
        ); // Day 4
      });

      test('returns true when interval or start date is null', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.interval,
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 1)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)), isTrue);
      });
    });

    group('shouldTriggerOnDate - AsNeeded', () {
      test('always returns true', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.asNeeded,
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 1)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 2, 2)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2026, 12, 31)), isTrue);
      });
    });

    group('shouldTriggerOnDate - Edge Cases', () {
      test('handles leap year', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        // 2028 is a leap year
        expect(schedule.shouldTriggerOnDate(DateTime(2028, 2, 29)), isTrue);
      });

      test('handles year boundary', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '23:59',
          frequencyType: FrequencyType.daily,
        );

        expect(schedule.shouldTriggerOnDate(DateTime(2026, 12, 31)), isTrue);
        expect(schedule.shouldTriggerOnDate(DateTime(2027, 1, 1)), isTrue);
      });

      test('ignores time component in date check', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        // Same day, different times should all return true
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2, 0, 0)),
          isTrue,
        );
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2, 12, 30)),
          isTrue,
        );
        expect(
          schedule.shouldTriggerOnDate(DateTime(2026, 2, 2, 23, 59)),
          isTrue,
        );
      });
    });

    group('frequencyDescription', () {
      test('returns "Every day" for daily', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        expect(schedule.frequencyDescription, 'Every day');
      });

      test('returns day names for specific days', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5',
        );

        expect(schedule.frequencyDescription, 'Mon, Wed, Fri');
      });

      test('returns "Every X days" for interval', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.interval,
          intervalDays: 3,
        );

        expect(schedule.frequencyDescription, 'Every 3 days');
      });

      test('returns "As needed" for asNeeded', () {
        final schedule = Schedule(
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.asNeeded,
        );

        expect(schedule.frequencyDescription, 'As needed (PRN)');
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final schedule = Schedule(
          id: 1,
          medicineId: 2,
          timeOfDay: '14:30',
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,3,5',
          intervalDays: 3,
          startDate: '2026-01-01',
          endDate: '2026-12-31',
        );

        final map = schedule.toMap();

        expect(map['id'], 1);
        expect(map['medicine_id'], 2);
        expect(map['time_of_day'], '14:30');
        expect(map['frequency_type'], 'specificDays');
        expect(map['frequency_days'], '1,3,5');
        expect(map['interval_days'], 3);
        expect(map['start_date'], '2026-01-01');
        expect(map['end_date'], '2026-12-31');
      });

      test('fromMap creates correct Schedule', () {
        final map = {
          'id': 1,
          'medicine_id': 2,
          'time_of_day': '14:30',
          'frequency_type': 'specificDays',
          'frequency_days': '1,3,5',
          'interval_days': 3,
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
        };

        final schedule = Schedule.fromMap(map);

        expect(schedule.id, 1);
        expect(schedule.medicineId, 2);
        expect(schedule.timeOfDay, '14:30');
        expect(schedule.frequencyType, FrequencyType.specificDays);
        expect(schedule.frequencyDays, '1,3,5');
        expect(schedule.intervalDays, 3);
        expect(schedule.startDate, '2026-01-01');
        expect(schedule.endDate, '2026-12-31');
      });

      test('toMap and fromMap are reversible', () {
        final original = Schedule(
          id: 1,
          medicineId: 2,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.interval,
          intervalDays: 5,
          startDate: '2026-02-01',
        );

        final restored = Schedule.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.medicineId, original.medicineId);
        expect(restored.timeOfDay, original.timeOfDay);
        expect(restored.frequencyType, original.frequencyType);
        expect(restored.intervalDays, original.intervalDays);
        expect(restored.startDate, original.startDate);
      });

      test('fromMap defaults to daily for unknown frequency type', () {
        final map = {
          'medicine_id': 1,
          'time_of_day': '08:00',
          'frequency_type': 'unknown',
        };

        final schedule = Schedule.fromMap(map);

        expect(schedule.frequencyType, FrequencyType.daily);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = Schedule(
          id: 1,
          medicineId: 2,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        final copy = original.copyWith(
          timeOfDay: '14:00',
          frequencyType: FrequencyType.interval,
        );

        expect(copy.id, 1); // unchanged
        expect(copy.medicineId, 2); // unchanged
        expect(copy.timeOfDay, '14:00');
        expect(copy.frequencyType, FrequencyType.interval);
      });
    });

    group('Equality', () {
      test('schedules with same id are equal', () {
        final schedule1 = Schedule(
          id: 1,
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );
        final schedule2 = Schedule(
          id: 1,
          medicineId: 2,
          timeOfDay: '09:00',
          frequencyType: FrequencyType.interval,
        );

        expect(schedule1 == schedule2, isTrue);
      });

      test('schedules with different ids are not equal', () {
        final schedule1 = Schedule(
          id: 1,
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );
        final schedule2 = Schedule(
          id: 2,
          medicineId: 1,
          timeOfDay: '08:00',
          frequencyType: FrequencyType.daily,
        );

        expect(schedule1 == schedule2, isFalse);
      });
    });
  });
}
