import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/caregiver.dart';
import 'dart:convert';

void main() {
  group('Caregiver Model', () {
    group('Constructor', () {
      test('creates caregiver with required fields', () {
        final caregiver = Caregiver(
          name: 'John Doe',
          phoneNumber: '+1234567890',
        );

        expect(caregiver.name, 'John Doe');
        expect(caregiver.phoneNumber, '+1234567890');
        expect(caregiver.notifyOnMissedDose, isTrue); // default
        expect(caregiver.notifyOnLowStock, isTrue); // default
      });

      test('creates caregiver with all fields', () {
        final caregiver = Caregiver(
          name: 'Jane Smith',
          phoneNumber: '+0987654321',
          notifyOnMissedDose: false,
          notifyOnLowStock: false,
        );

        expect(caregiver.name, 'Jane Smith');
        expect(caregiver.phoneNumber, '+0987654321');
        expect(caregiver.notifyOnMissedDose, isFalse);
        expect(caregiver.notifyOnLowStock, isFalse);
      });

      test('defaults notifications to true', () {
        final caregiver = Caregiver(name: 'Test', phoneNumber: '123');

        expect(caregiver.notifyOnMissedDose, isTrue);
        expect(caregiver.notifyOnLowStock, isTrue);
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final caregiver = Caregiver(
          name: 'Bob Wilson',
          phoneNumber: '+5556667777',
          notifyOnMissedDose: true,
          notifyOnLowStock: false,
        );

        final map = caregiver.toMap();

        expect(map['name'], 'Bob Wilson');
        expect(map['phoneNumber'], '+5556667777');
        expect(map['notifyOnMissedDose'], isTrue);
        expect(map['notifyOnLowStock'], isFalse);
      });

      test('fromMap creates correct Caregiver', () {
        final map = {
          'name': 'Alice Brown',
          'phoneNumber': '+1112223333',
          'notifyOnMissedDose': false,
          'notifyOnLowStock': true,
        };

        final caregiver = Caregiver.fromMap(map);

        expect(caregiver.name, 'Alice Brown');
        expect(caregiver.phoneNumber, '+1112223333');
        expect(caregiver.notifyOnMissedDose, isFalse);
        expect(caregiver.notifyOnLowStock, isTrue);
      });

      test('fromMap handles missing fields with defaults', () {
        final map = <String, dynamic>{};

        final caregiver = Caregiver.fromMap(map);

        expect(caregiver.name, '');
        expect(caregiver.phoneNumber, '');
        expect(caregiver.notifyOnMissedDose, isTrue);
        expect(caregiver.notifyOnLowStock, isTrue);
      });

      test('toMap and fromMap are reversible', () {
        final original = Caregiver(
          name: 'Test Caregiver',
          phoneNumber: '+9998887777',
          notifyOnMissedDose: true,
          notifyOnLowStock: false,
        );

        final restored = Caregiver.fromMap(original.toMap());

        expect(restored.name, original.name);
        expect(restored.phoneNumber, original.phoneNumber);
        expect(restored.notifyOnMissedDose, original.notifyOnMissedDose);
        expect(restored.notifyOnLowStock, original.notifyOnLowStock);
      });
    });

    group('JSON Serialization', () {
      test('toJson creates valid JSON string', () {
        final caregiver = Caregiver(
          name: 'John Doe',
          phoneNumber: '+1234567890',
          notifyOnMissedDose: true,
          notifyOnLowStock: true,
        );

        final jsonString = caregiver.toJson();

        // Should be valid JSON
        expect(() => jsonDecode(jsonString), returnsNormally);

        final decoded = jsonDecode(jsonString);
        expect(decoded['name'], 'John Doe');
        expect(decoded['phoneNumber'], '+1234567890');
      });

      test('fromJson creates correct Caregiver', () {
        final jsonString =
            '{"name":"Jane Smith","phoneNumber":"+0987654321","notifyOnMissedDose":false,"notifyOnLowStock":true}';

        final caregiver = Caregiver.fromJson(jsonString);

        expect(caregiver.name, 'Jane Smith');
        expect(caregiver.phoneNumber, '+0987654321');
        expect(caregiver.notifyOnMissedDose, isFalse);
        expect(caregiver.notifyOnLowStock, isTrue);
      });

      test('toJson and fromJson are reversible', () {
        final original = Caregiver(
          name: 'Roundtrip Test',
          phoneNumber: '+1111111111',
          notifyOnMissedDose: false,
          notifyOnLowStock: false,
        );

        final restored = Caregiver.fromJson(original.toJson());

        expect(restored.name, original.name);
        expect(restored.phoneNumber, original.phoneNumber);
        expect(restored.notifyOnMissedDose, original.notifyOnMissedDose);
        expect(restored.notifyOnLowStock, original.notifyOnLowStock);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = Caregiver(
          name: 'Original Name',
          phoneNumber: '+1234567890',
          notifyOnMissedDose: true,
          notifyOnLowStock: true,
        );

        final copy = original.copyWith(
          name: 'New Name',
          notifyOnLowStock: false,
        );

        expect(copy.name, 'New Name');
        expect(copy.phoneNumber, '+1234567890'); // unchanged
        expect(copy.notifyOnMissedDose, isTrue); // unchanged
        expect(copy.notifyOnLowStock, isFalse);
      });

      test('preserves all fields when none specified', () {
        final original = Caregiver(
          name: 'Test',
          phoneNumber: '+0000000000',
          notifyOnMissedDose: false,
          notifyOnLowStock: false,
        );

        final copy = original.copyWith();

        expect(copy.name, original.name);
        expect(copy.phoneNumber, original.phoneNumber);
        expect(copy.notifyOnMissedDose, original.notifyOnMissedDose);
        expect(copy.notifyOnLowStock, original.notifyOnLowStock);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final caregiver = Caregiver(
          name: 'Test Person',
          phoneNumber: '+1234567890',
          notifyOnMissedDose: true,
          notifyOnLowStock: false,
        );

        final str = caregiver.toString();

        expect(str.contains('Caregiver'), isTrue);
        expect(str.contains('name: Test Person'), isTrue);
        expect(str.contains('phone: +1234567890'), isTrue);
        expect(str.contains('missed: true'), isTrue);
        expect(str.contains('stock: false'), isTrue);
      });
    });

    group('Phone Number Handling', () {
      test('accepts international phone formats', () {
        final formats = [
          '+1 (555) 123-4567',
          '+44 20 7123 4567',
          '+91 98765 43210',
          '555-123-4567',
          '(555) 123-4567',
        ];

        for (final format in formats) {
          final caregiver = Caregiver(name: 'Test', phoneNumber: format);
          expect(caregiver.phoneNumber, format);
        }
      });
    });
  });
}
