import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/medicine.dart';
import '../mocks/mock_services.dart';
import '../fixtures/test_fixtures.dart';

/// A testable version of MedicineProvider that accepts injected dependencies
/// This allows us to test the provider logic without actual DB/notification calls
class TestableMedicineProvider {
  final MockDatabaseHelper db;
  final MockNotificationService notifications;
  MockSubscriptionProvider? _subscriptionProvider;

  List<Medicine> _medicines = [];
  bool _isLoading = false;

  TestableMedicineProvider({
    required this.db,
    required this.notifications,
    MockSubscriptionProvider? subscriptionProvider,
  }) : _subscriptionProvider = subscriptionProvider;

  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading;
  List<Medicine> get lowStockMedicines =>
      _medicines.where((m) => m.isLowStock).toList();

  void updateSubscription(MockSubscriptionProvider? subscription) {
    _subscriptionProvider = subscription;
  }

  Future<void> loadMedicines() async {
    _isLoading = true;
    try {
      _medicines = await db.getAllMedicines();
    } finally {
      _isLoading = false;
    }
  }

  Future<Medicine?> addMedicine(Medicine medicine) async {
    // Check limits
    final isPremium = _subscriptionProvider?.isPremium ?? false;
    if (!isPremium && _medicines.length >= 3) {
      throw PremiumLimitException(
        "You have reached the free limit of 3 medicines.",
      );
    }

    final newMedicine = await db.createMedicine(medicine);
    _medicines.add(newMedicine);
    return newMedicine;
  }

  Future<bool> updateMedicine(Medicine medicine) async {
    await db.updateMedicine(medicine);
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index != -1) {
      _medicines[index] = medicine;
    }
    return true;
  }

  Future<bool> deleteMedicine(int id) async {
    await db.deleteMedicine(id);
    _medicines.removeWhere((m) => m.id == id);
    return true;
  }

  Future<void> decrementStock(int medicineId) async {
    await db.decrementStock(medicineId);

    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      final medicine = _medicines[index];
      final updatedMedicine = medicine.copyWith(
        currentStock: medicine.currentStock - 1,
      );
      _medicines[index] = updatedMedicine;

      // Show low stock alert if needed
      if (updatedMedicine.isLowStock) {
        await notifications.showLowStockAlert(
          medicineId: medicineId,
          medicineName: updatedMedicine.name,
          currentStock: updatedMedicine.currentStock,
        );
      }
    }
  }

  Future<void> incrementStock(int medicineId) async {
    await db.incrementStock(medicineId);

    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      final medicine = _medicines[index];
      final updatedMedicine = medicine.copyWith(
        currentStock: medicine.currentStock + 1,
      );
      _medicines[index] = updatedMedicine;
    }
  }

  Medicine? getMedicineById(int id) {
    try {
      return _medicines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Mock subscription provider for testing premium limits
class MockSubscriptionProvider {
  bool isPremium;
  MockSubscriptionProvider({this.isPremium = false});
}

/// Exception for premium limit reached
class PremiumLimitException implements Exception {
  final String message;
  PremiumLimitException([this.message = 'Free limit reached']);

  @override
  String toString() => message;
}

void main() {
  late TestableMedicineProvider provider;
  late MockDatabaseHelper mockDb;
  late MockNotificationService mockNotifications;

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockNotifications = MockNotificationService();
    provider = TestableMedicineProvider(
      db: mockDb,
      notifications: mockNotifications,
    );
  });

  tearDown(() {
    mockDb.reset();
    mockNotifications.reset();
  });

  group('MedicineProvider Tests', () {
    group('Initial State', () {
      test('starts with empty list', () {
        expect(provider.medicines, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.lowStockMedicines, isEmpty);
      });
    });

    group('loadMedicines', () {
      test('loads medicines from database', () async {
        // Arrange: Pre-populate database
        await mockDb.createMedicine(MedicineFixtures.create(name: 'Med 1'));
        await mockDb.createMedicine(MedicineFixtures.create(name: 'Med 2'));

        // Act
        await provider.loadMedicines();

        // Assert
        expect(provider.medicines.length, 2);
        expect(provider.medicines[0].name, 'Med 1');
        expect(provider.medicines[1].name, 'Med 2');
      });

      test('updates loading state', () async {
        expect(provider.isLoading, isFalse);

        // We can't easily test the intermediate state without more complexity
        await provider.loadMedicines();

        expect(provider.isLoading, isFalse);
      });
    });

    group('addMedicine', () {
      test('adds medicine to database and list', () async {
        final medicine = MedicineFixtures.create(name: 'New Medicine');

        final result = await provider.addMedicine(medicine);

        expect(result, isNotNull);
        expect(result!.id, isNotNull);
        expect(result.name, 'New Medicine');
        expect(provider.medicines.length, 1);
      });

      test('allows up to 3 medicines for free users', () async {
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 1'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 2'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 3'));

        expect(provider.medicines.length, 3);
      });

      test(
        'throws PremiumLimitException when free user tries to add 4th medicine',
        () async {
          await provider.addMedicine(MedicineFixtures.create(name: 'Med 1'));
          await provider.addMedicine(MedicineFixtures.create(name: 'Med 2'));
          await provider.addMedicine(MedicineFixtures.create(name: 'Med 3'));

          expect(
            () => provider.addMedicine(MedicineFixtures.create(name: 'Med 4')),
            throwsA(isA<PremiumLimitException>()),
          );
        },
      );

      test('premium users can add more than 3 medicines', () async {
        provider.updateSubscription(MockSubscriptionProvider(isPremium: true));

        await provider.addMedicine(MedicineFixtures.create(name: 'Med 1'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 2'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 3'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 4'));
        await provider.addMedicine(MedicineFixtures.create(name: 'Med 5'));

        expect(provider.medicines.length, 5);
      });
    });

    group('updateMedicine', () {
      test('updates medicine in database and list', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'Original Name'),
        );

        final updated = medicine!.copyWith(name: 'Updated Name');
        await provider.updateMedicine(updated);

        expect(provider.medicines.first.name, 'Updated Name');
      });

      test('does nothing if medicine not found', () async {
        final medicine = MedicineFixtures.create(id: 999, name: 'Not Found');

        await provider.updateMedicine(medicine);

        expect(provider.medicines, isEmpty);
      });
    });

    group('deleteMedicine', () {
      test('removes medicine from database and list', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'To Delete'),
        );

        await provider.deleteMedicine(medicine!.id!);

        expect(provider.medicines, isEmpty);
      });

      test('does nothing if medicine not found', () async {
        await provider.addMedicine(MedicineFixtures.create(name: 'Keep'));

        await provider.deleteMedicine(999);

        expect(provider.medicines.length, 1);
      });
    });

    group('decrementStock', () {
      test('decrements stock by 1', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'Test', currentStock: 10),
        );

        await provider.decrementStock(medicine!.id!);

        expect(provider.medicines.first.currentStock, 9);
      });

      test('triggers low stock alert when threshold reached', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(
            name: 'Low Stock Test',
            currentStock: 6, // Will become 5 (threshold)
            lowStockThreshold: 5,
          ),
        );

        await provider.decrementStock(medicine!.id!);

        expect(mockNotifications.lowStockAlertIds, contains(medicine.id));
      });

      test('does not trigger alert when above threshold', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(
            name: 'High Stock',
            currentStock: 20,
            lowStockThreshold: 5,
          ),
        );

        await provider.decrementStock(medicine!.id!);

        expect(mockNotifications.lowStockAlertIds, isEmpty);
      });
    });

    group('incrementStock', () {
      test('increments stock by 1', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'Test', currentStock: 10),
        );

        await provider.incrementStock(medicine!.id!);

        expect(provider.medicines.first.currentStock, 11);
      });

      test('increments from zero', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'Empty', currentStock: 0),
        );

        await provider.incrementStock(medicine!.id!);

        expect(provider.medicines.first.currentStock, 1);
      });
    });

    group('getMedicineById', () {
      test('returns medicine when found', () async {
        final medicine = await provider.addMedicine(
          MedicineFixtures.create(name: 'Find Me'),
        );

        final found = provider.getMedicineById(medicine!.id!);

        expect(found, isNotNull);
        expect(found!.name, 'Find Me');
      });

      test('returns null when not found', () {
        final found = provider.getMedicineById(999);

        expect(found, isNull);
      });
    });

    group('lowStockMedicines', () {
      test('returns only medicines with low stock', () async {
        // Need premium to add more than 3 medicines
        provider.updateSubscription(MockSubscriptionProvider(isPremium: true));

        await provider.addMedicine(MedicineFixtures.lowStock(name: 'Low 1'));
        await provider.addMedicine(MedicineFixtures.highStock(name: 'High'));
        await provider.addMedicine(MedicineFixtures.lowStock(name: 'Low 2'));
        await provider.addMedicine(
          MedicineFixtures.atThreshold(name: 'At Threshold'),
        );

        final lowStock = provider.lowStockMedicines;

        expect(lowStock.length, 3); // Low 1, Low 2, At Threshold
        expect(
          lowStock.map((m) => m.name),
          containsAll(['Low 1', 'Low 2', 'At Threshold']),
        );
      });

      test('returns empty list when no low stock', () async {
        await provider.addMedicine(MedicineFixtures.highStock(name: 'Plenty'));

        expect(provider.lowStockMedicines, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles empty database', () async {
        await provider.loadMedicines();

        expect(provider.medicines, isEmpty);
      });

      test('handles rapid successive operations', () async {
        final med1 = await provider.addMedicine(
          MedicineFixtures.create(name: 'Med 1'),
        );
        final med2 = await provider.addMedicine(
          MedicineFixtures.create(name: 'Med 2'),
        );

        await provider.decrementStock(med1!.id!);
        await provider.incrementStock(med2!.id!);
        await provider.deleteMedicine(med1.id!);

        expect(provider.medicines.length, 1);
        expect(provider.medicines.first.currentStock, 31); // 30 + 1
      });
    });
  });
}
