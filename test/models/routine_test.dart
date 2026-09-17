import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_time/models/routine.dart';

void main() {
  group('Routine Model', () {
    group('Constructor and Properties', () {
      test('creates routine with required fields', () {
        final routine = Routine(name: 'Read');

        expect(routine.name, 'Read');
        expect(routine.id, isNull);
        expect(routine.dosage, '');
        expect(routine.typeIcon, 1);
        expect(routine.color, 0xFF2196F3);
      });

      test('creates routine with all fields', () {
        final routine = Routine(
          id: 1,
          name: 'Walk',
          dosage: '20 min',
          typeIcon: 3,
          color: 0xFFFF5722,
        );

        expect(routine.id, 1);
        expect(routine.name, 'Walk');
        expect(routine.dosage, '20 min');
        expect(routine.typeIcon, 3);
        expect(routine.color, 0xFFFF5722);
      });
    });

    group('icon', () {
      test('returns water_drop icon for type 1 (Water)', () {
        final routine = Routine(name: 'Test', typeIcon: 1);
        expect(routine.icon, Icons.water_drop_rounded);
      });

      test('returns menu_book icon for type 2 (Read)', () {
        final routine = Routine(name: 'Test', typeIcon: 2);
        expect(routine.icon, Icons.menu_book_rounded);
      });

      test('returns directions_walk icon for type 3 (Walk)', () {
        final routine = Routine(name: 'Test', typeIcon: 3);
        expect(routine.icon, Icons.directions_walk_rounded);
      });

      test('returns spa icon for type 4 (Care)', () {
        final routine = Routine(name: 'Test', typeIcon: 4);
        expect(routine.icon, Icons.spa_rounded);
      });

      test('defaults to task_alt icon for unknown types', () {
        final routine = Routine(name: 'Test', typeIcon: 99);
        expect(routine.icon, Icons.task_alt_rounded);
      });
    });

    group('iconAssetPath', () {
      test('returns correct path for tablet type', () {
        final routine = Routine(name: 'Test', typeIcon: 1);
        expect(routine.iconAssetPath, 'assets/icons/routine/3d/tablet.png');
      });

      test('returns correct path for liquid type', () {
        final routine = Routine(name: 'Test', typeIcon: 2);
        expect(routine.iconAssetPath, 'assets/icons/routine/3d/liquid.png');
      });

      test('returns correct path for injection type', () {
        final routine = Routine(name: 'Test', typeIcon: 3);
        expect(
          routine.iconAssetPath,
          'assets/icons/routine/3d/injection.png',
        );
      });

      test('returns correct path for drop type', () {
        final routine = Routine(name: 'Test', typeIcon: 4);
        expect(routine.iconAssetPath, 'assets/icons/routine/3d/drop.png');
      });

      test('defaults to tablet for unknown type', () {
        final routine = Routine(name: 'Test', typeIcon: 99);
        expect(routine.iconAssetPath, 'assets/icons/routine/3d/tablet.png');
      });
    });

    group('colorValue', () {
      test('returns Color object from int value', () {
        final routine = Routine(name: 'Test', color: 0xFFFF0000);
        expect(routine.colorValue, const Color(0xFFFF0000));
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final routine = Routine(
          id: 1,
          name: 'Read',
          dosage: '20 min',
          typeIcon: 2,
          color: 0xFF2196F3,
        );

        final map = routine.toMap();

        expect(map['id'], 1);
        expect(map['name'], 'Read');
        expect(map['dosage'], '20 min');
        expect(map['type_icon'], 2);
        expect(map['color'], 0xFF2196F3);
      });

      test('fromMap creates correct Routine', () {
        final map = {
          'id': 1,
          'name': 'Read',
          'dosage': '20 min',
          'type_icon': 2,
          'color': 0xFF2196F3,
        };

        final routine = Routine.fromMap(map);

        expect(routine.id, 1);
        expect(routine.name, 'Read');
        expect(routine.dosage, '20 min');
        expect(routine.typeIcon, 2);
        expect(routine.color, 0xFF2196F3);
      });

      test('toMap and fromMap are reversible', () {
        final original = Routine(
          id: 1,
          name: 'Test',
          dosage: '50mg',
          typeIcon: 2,
          color: 0xFF00FF00,
        );

        final restored = Routine.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.dosage, original.dosage);
        expect(restored.typeIcon, original.typeIcon);
        expect(restored.color, original.color);
      });

      test('fromMap handles null optional fields', () {
        final map = {'name': 'Simple Routine'};

        final routine = Routine.fromMap(map);

        expect(routine.name, 'Simple Routine');
        expect(routine.dosage, '');
        expect(routine.typeIcon, 1);
        expect(routine.color, 0xFF2196F3);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = Routine(
          id: 1,
          name: 'Original',
          dosage: '20 min',
        );

        final copy = original.copyWith(name: 'Modified');

        expect(copy.id, 1); // unchanged
        expect(copy.name, 'Modified');
        expect(copy.dosage, '20 min'); // unchanged
      });

      test('preserves all fields when none specified', () {
        final original = Routine(
          id: 1,
          name: 'Test',
          dosage: '50mg',
          typeIcon: 3,
          color: 0xFFAABBCC,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.dosage, original.dosage);
        expect(copy.typeIcon, original.typeIcon);
        expect(copy.color, original.color);
      });
    });

    group('Equality', () {
      test('routines with same id are equal', () {
        final routine1 = Routine(id: 1, name: 'Routine A');
        final routine2 = Routine(id: 1, name: 'Routine B');

        expect(routine1 == routine2, isTrue);
      });

      test('routines with different ids are not equal', () {
        final routine1 = Routine(id: 1, name: 'Routine A');
        final routine2 = Routine(id: 2, name: 'Routine A');

        expect(routine1 == routine2, isFalse);
      });

      test('identical references are equal', () {
        final routine = Routine(id: 1, name: 'Routine');

        expect(routine == routine, isTrue);
      });

      test('hashCode is based on id', () {
        final routine1 = Routine(id: 1, name: 'Routine A');
        final routine2 = Routine(id: 1, name: 'Routine B');

        expect(routine1.hashCode, routine2.hashCode);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final routine = Routine(id: 1, name: 'Read', dosage: '20 min');

        expect(
          routine.toString(),
          'Routine(id: 1, name: Read, dosage: 20 min)',
        );
      });
    });
  });
}
