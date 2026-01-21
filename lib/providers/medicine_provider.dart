import 'package:flutter/foundation.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/schedule.dart';
import '../services/auth_service.dart';
import '../services/caregiver_notification_service.dart';

/// Provider for managing medicines
class MedicineProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<Medicine> _medicines = [];
  bool _isLoading = false;

  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading;

  /// Get low stock medicines
  List<Medicine> get lowStockMedicines =>
      _medicines.where((m) => m.isLowStock).toList();

  /// Load all medicines from database
  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();

    try {
      _medicines = await _db.getAllMedicines();
    } catch (e) {
      debugPrint('Error loading medicines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new medicine
  Future<Medicine?> addMedicine(Medicine medicine) async {
    try {
      final newMedicine = await _db.createMedicine(medicine);
      _medicines.add(newMedicine);
      await _updateRefillReminder(newMedicine);
      notifyListeners();
      return newMedicine;
    } catch (e) {
      debugPrint('Error adding medicine: $e');
      return null;
    }
  }

  /// Update an existing medicine
  Future<bool> updateMedicine(Medicine medicine) async {
    try {
      await _db.updateMedicine(medicine);
      final index = _medicines.indexWhere((m) => m.id == medicine.id);
      if (index != -1) {
        _medicines[index] = medicine;
        await _updateRefillReminder(medicine);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating medicine: $e');
      return false;
    }
  }

  /// Delete a medicine
  Future<bool> deleteMedicine(int id) async {
    try {
      await _db.deleteMedicine(id);
      _medicines.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
      return false;
    }
  }

  /// Decrement stock when medicine is taken
  Future<void> decrementStock(int medicineId) async {
    try {
      await _db.decrementStock(medicineId);
      
      // Update local list
      final index = _medicines.indexWhere((m) => m.id == medicineId);
      if (index != -1) {
        final medicine = _medicines[index];
        final updatedMedicine = medicine.copyWith(
          currentStock: medicine.currentStock - 1,
        );
        _medicines[index] = updatedMedicine;

        // Check if stock is now low and show alert
        if (updatedMedicine.isLowStock) {
          // Local Alert
          await _notifications.showLowStockAlert(
            medicineId: medicineId,
            medicineName: updatedMedicine.name,
            currentStock: updatedMedicine.currentStock,
          );

          // Remote Alert (Caregivers)
          try {
             final authService = AuthService();
             final profile = await authService.getCurrentUserProfile();
             if (profile != null && profile.shareEnabled && profile.linkedCaregiverIds.isNotEmpty) {
               await CaregiverNotificationService().sendLowStockAlert(
                 patientName: profile.displayName ?? 'Patient',
                 medicineName: updatedMedicine.name,
                 remainingCount: updatedMedicine.currentStock,
                 caregiverIds: profile.linkedCaregiverIds,
               );
             }
          } catch (e) {
            debugPrint('Error sending remote low stock alert: $e');
          }
        }

        await _updateRefillReminder(updatedMedicine);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error decrementing stock: $e');
    }
  }

  /// Get medicine by ID
  Medicine? getMedicineById(int id) {
    try {
      return _medicines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refresh medicines from database
  Future<void> refresh() async {
    await loadMedicines();
  }

  /// Update refill reminder based on current stock and schedule
  Future<void> _updateRefillReminder(Medicine medicine) async {
    if (medicine.id == null) return;

    final schedules = await _db.getSchedulesForMedicine(medicine.id!);
    if (schedules.isEmpty) return;

    // Calculate daily doses
    int dailyDoses = 0;
    for (final s in schedules) {
      if (s.frequencyType == FrequencyType.daily) {
        dailyDoses += 1;
      } else if (s.frequencyType == FrequencyType.specificDays) {
        // Average doses per day
        dailyDoses += 1; // Simplified: check if triggers today or just count as potential
      } else if (s.frequencyType == FrequencyType.interval) {
        // Approximate
        dailyDoses += 1;
      }
    }

    if (dailyDoses > 0) {
      final refillDate = medicine.getEstimatedRefillDate(dailyDoses);
      await _notifications.scheduleRefillReminder(
        medicineId: medicine.id!,
        medicineName: medicine.name,
        refillDate: refillDate,
      );
    }
  }
}
