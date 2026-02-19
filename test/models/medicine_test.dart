import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/medicine.dart';

void main() {
  group('Medicine Model', () {
    group('Constructor and Properties', () {
      test('creates medicine with required fields', () {
        final medicine = Medicine(name: 'Aspirin');

        expect(medicine.name, 'Aspirin');
        expect(medicine.id, isNull);
        expect(medicine.dosage, '');
        expect(medicine.typeIcon, 1);
        expect(medicine.currentStock, 0);
        expect(medicine.lowStockThreshold, 5);
        expect(medicine.color, 0xFF2196F3);
      });

      test('creates medicine with all fields', () {
        final medicine = Medicine(
          id: 1,
          name: 'Ibuprofen',
          dosage: '200mg',
          typeIcon: 2,
          currentStock: 50,
          lowStockThreshold: 10,
          color: 0xFFFF5722,
          imagePath: '/path/to/image.png',
          pharmacyName: 'Test Pharmacy',
          pharmacyPhone: '+1234567890',
          rxcui: 'RX12345',
        );

        expect(medicine.id, 1);
        expect(medicine.name, 'Ibuprofen');
        expect(medicine.dosage, '200mg');
        expect(medicine.typeIcon, 2);
        expect(medicine.currentStock, 50);
        expect(medicine.lowStockThreshold, 10);
        expect(medicine.color, 0xFFFF5722);
        expect(medicine.imagePath, '/path/to/image.png');
        expect(medicine.pharmacyName, 'Test Pharmacy');
        expect(medicine.pharmacyPhone, '+1234567890');
        expect(medicine.rxcui, 'RX12345');
      });
    });

    group('isLowStock', () {
      test('returns true when stock is below threshold', () {
        final medicine = Medicine(
          name: 'Test',
          currentStock: 3,
          lowStockThreshold: 5,
        );

        expect(medicine.isLowStock, isTrue);
      });

      test('returns true when stock equals threshold', () {
        final medicine = Medicine(
          name: 'Test',
          currentStock: 5,
          lowStockThreshold: 5,
        );

        expect(medicine.isLowStock, isTrue);
      });

      test('returns false when stock is above threshold', () {
        final medicine = Medicine(
          name: 'Test',
          currentStock: 10,
          lowStockThreshold: 5,
        );

        expect(medicine.isLowStock, isFalse);
      });

      test('handles zero stock', () {
        final medicine = Medicine(
          name: 'Test',
          currentStock: 0,
          lowStockThreshold: 5,
        );

        expect(medicine.isLowStock, isTrue);
      });
    });

    group('getDaysRemaining', () {
      test('calculates days correctly with daily doses', () {
        final medicine = Medicine(name: 'Test', currentStock: 30);

        expect(medicine.getDaysRemaining(1), 30);
        expect(medicine.getDaysRemaining(2), 15);
        expect(medicine.getDaysRemaining(3), 10);
      });

      test('returns 365 when daily doses is zero', () {
        final medicine = Medicine(name: 'Test', currentStock: 30);

        expect(medicine.getDaysRemaining(0), 365);
      });

      test('returns 365 when daily doses is negative', () {
        final medicine = Medicine(name: 'Test', currentStock: 30);

        expect(medicine.getDaysRemaining(-1), 365);
      });

      test('floors the result for non-even divisions', () {
        final medicine = Medicine(name: 'Test', currentStock: 10);

        expect(medicine.getDaysRemaining(3), 3); // 10/3 = 3.33 -> 3
      });

      test('handles zero stock', () {
        final medicine = Medicine(name: 'Test', currentStock: 0);

        expect(medicine.getDaysRemaining(1), 0);
      });
    });

    group('getEstimatedRefillDate', () {
      test('calculates refill date correctly', () {
        final medicine = Medicine(name: 'Test', currentStock: 10);

        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final expectedDate = todayOnly.add(const Duration(days: 10));

        final refillDate = medicine.getEstimatedRefillDate(1);

        expect(refillDate.year, expectedDate.year);
        expect(refillDate.month, expectedDate.month);
        expect(refillDate.day, expectedDate.day);
      });
    });

    group('icon', () {
      test('returns medication icon for type 1 (Pill)', () {
        final medicine = Medicine(name: 'Test', typeIcon: 1);
        expect(medicine.icon, Icons.medication);
      });

      test('returns local_drink icon for type 2 (Syrup)', () {
        final medicine = Medicine(name: 'Test', typeIcon: 2);
        expect(medicine.icon, Icons.local_drink);
      });

      test('returns vaccines icon for type 3 (Injection)', () {
        final medicine = Medicine(name: 'Test', typeIcon: 3);
        expect(medicine.icon, Icons.vaccines);
      });

      test('returns water_drop icon for type 4 (Drops)', () {
        final medicine = Medicine(name: 'Test', typeIcon: 4);
        expect(medicine.icon, Icons.water_drop);
      });

      test('defaults to medication icon for unknown types', () {
        final medicine = Medicine(name: 'Test', typeIcon: 99);
        expect(medicine.icon, Icons.medication);
      });
    });

    group('iconAssetPath', () {
      test('returns correct path for pill type', () {
        final medicine = Medicine(name: 'Test', typeIcon: 1);
        expect(medicine.iconAssetPath, 'assets/icons/medicine/3d/tablet.png');
      });

      test('returns correct path for syrup type', () {
        final medicine = Medicine(name: 'Test', typeIcon: 2);
        expect(medicine.iconAssetPath, 'assets/icons/medicine/3d/liquid.png');
      });

      test('returns correct path for injection type', () {
        final medicine = Medicine(name: 'Test', typeIcon: 3);
        expect(
          medicine.iconAssetPath,
          'assets/icons/medicine/3d/injection.png',
        );
      });

      test('returns correct path for drops type', () {
        final medicine = Medicine(name: 'Test', typeIcon: 4);
        expect(medicine.iconAssetPath, 'assets/icons/medicine/3d/drop.png');
      });

      test('defaults to tablet for unknown type', () {
        final medicine = Medicine(name: 'Test', typeIcon: 99);
        expect(medicine.iconAssetPath, 'assets/icons/medicine/3d/tablet.png');
      });
    });

    group('colorValue', () {
      test('returns Color object from int value', () {
        final medicine = Medicine(name: 'Test', color: 0xFFFF0000);
        expect(medicine.colorValue, const Color(0xFFFF0000));
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final medicine = Medicine(
          id: 1,
          name: 'Aspirin',
          dosage: '100mg',
          typeIcon: 1,
          currentStock: 30,
          lowStockThreshold: 5,
          color: 0xFF2196F3,
          imagePath: '/path.png',
          pharmacyName: 'Pharmacy',
          pharmacyPhone: '123',
          rxcui: 'RX1',
        );

        final map = medicine.toMap();

        expect(map['id'], 1);
        expect(map['name'], 'Aspirin');
        expect(map['dosage'], '100mg');
        expect(map['type_icon'], 1);
        expect(map['current_stock'], 30);
        expect(map['low_stock_threshold'], 5);
        expect(map['color'], 0xFF2196F3);
        expect(map['image_path'], '/path.png');
        expect(map['pharmacy_name'], 'Pharmacy');
        expect(map['pharmacy_phone'], '123');
        expect(map['rxcui'], 'RX1');
      });

      test('fromMap creates correct Medicine', () {
        final map = {
          'id': 1,
          'name': 'Aspirin',
          'dosage': '100mg',
          'type_icon': 1,
          'current_stock': 30,
          'low_stock_threshold': 5,
          'color': 0xFF2196F3,
          'image_path': '/path.png',
          'pharmacy_name': 'Pharmacy',
          'pharmacy_phone': '123',
          'rxcui': 'RX1',
        };

        final medicine = Medicine.fromMap(map);

        expect(medicine.id, 1);
        expect(medicine.name, 'Aspirin');
        expect(medicine.dosage, '100mg');
        expect(medicine.typeIcon, 1);
        expect(medicine.currentStock, 30);
        expect(medicine.lowStockThreshold, 5);
        expect(medicine.color, 0xFF2196F3);
        expect(medicine.imagePath, '/path.png');
        expect(medicine.pharmacyName, 'Pharmacy');
        expect(medicine.pharmacyPhone, '123');
        expect(medicine.rxcui, 'RX1');
      });

      test('toMap and fromMap are reversible', () {
        final original = Medicine(
          id: 1,
          name: 'Test',
          dosage: '50mg',
          typeIcon: 2,
          currentStock: 20,
          lowStockThreshold: 3,
          color: 0xFF00FF00,
          rxcui: 'RX123',
        );

        final restored = Medicine.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.dosage, original.dosage);
        expect(restored.typeIcon, original.typeIcon);
        expect(restored.currentStock, original.currentStock);
        expect(restored.lowStockThreshold, original.lowStockThreshold);
        expect(restored.color, original.color);
        expect(restored.rxcui, original.rxcui);
      });

      test('fromMap handles null optional fields', () {
        final map = {'name': 'Simple Med'};

        final medicine = Medicine.fromMap(map);

        expect(medicine.name, 'Simple Med');
        expect(medicine.dosage, '');
        expect(medicine.typeIcon, 1);
        expect(medicine.currentStock, 0);
        expect(medicine.lowStockThreshold, 5);
        expect(medicine.color, 0xFF2196F3);
        expect(medicine.imagePath, isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = Medicine(
          id: 1,
          name: 'Original',
          dosage: '100mg',
          currentStock: 30,
        );

        final copy = original.copyWith(name: 'Modified', currentStock: 20);

        expect(copy.id, 1); // unchanged
        expect(copy.name, 'Modified');
        expect(copy.dosage, '100mg'); // unchanged
        expect(copy.currentStock, 20);
      });

      test('preserves all fields when none specified', () {
        final original = Medicine(
          id: 1,
          name: 'Test',
          dosage: '50mg',
          typeIcon: 3,
          currentStock: 25,
          lowStockThreshold: 7,
          color: 0xFFAABBCC,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.dosage, original.dosage);
        expect(copy.typeIcon, original.typeIcon);
        expect(copy.currentStock, original.currentStock);
        expect(copy.lowStockThreshold, original.lowStockThreshold);
        expect(copy.color, original.color);
      });
    });

    group('Equality', () {
      test('medicines with same id are equal', () {
        final medicine1 = Medicine(id: 1, name: 'Med A');
        final medicine2 = Medicine(id: 1, name: 'Med B');

        expect(medicine1 == medicine2, isTrue);
      });

      test('medicines with different ids are not equal', () {
        final medicine1 = Medicine(id: 1, name: 'Med A');
        final medicine2 = Medicine(id: 2, name: 'Med A');

        expect(medicine1 == medicine2, isFalse);
      });

      test('identical references are equal', () {
        final medicine = Medicine(id: 1, name: 'Med');

        expect(medicine == medicine, isTrue);
      });

      test('hashCode is based on id', () {
        final medicine1 = Medicine(id: 1, name: 'Med A');
        final medicine2 = Medicine(id: 1, name: 'Med B');

        expect(medicine1.hashCode, medicine2.hashCode);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final medicine = Medicine(
          id: 1,
          name: 'Aspirin',
          dosage: '100mg',
          currentStock: 30,
        );

        expect(
          medicine.toString(),
          'Medicine(id: 1, name: Aspirin, dosage: 100mg, stock: 30)',
        );
      });
    });
  });
}
