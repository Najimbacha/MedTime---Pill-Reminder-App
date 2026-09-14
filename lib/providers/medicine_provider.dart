import 'package:flutter/foundation.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../models/schedule.dart';
import '../models/medicine_deletion_snapshot.dart';
import '../services/auth_service.dart';
import '../services/caregiver_notification_service.dart';
import 'subscription_provider.dart';

/// Exception thrown when a free user tries to add more than the allowed routines.
class PremiumLimitException implements Exception {
  final String message;
  PremiumLimitException([this.message = 'Free limit reached']);
}

/// Provider for managing routines.
class MedicineProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  // Injected SubscriptionProvider to check limit
  SubscriptionProvider? _subscriptionProvider;

  List<Medicine> _medicines = [];
  bool _isLoading = false;

  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading;

  /// Legacy stock support is disabled in the simplified RoutineTime UI.
  List<Medicine> get lowStockMedicines =>
      _medicines.where((m) => m.isLowStock).toList();

  MedicineProvider({SubscriptionProvider? subscriptionProvider})
    : _subscriptionProvider = subscriptionProvider;

  void updateSubscription(SubscriptionProvider? subscription) {
    _subscriptionProvider = subscription;
  }

  /// Load all routines from database.
  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();

    try {
      _medicines = await _db.getAllMedicines();
    } catch (e) {
      debugPrint('Error loading routines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new routine.
  Future<Medicine?> addMedicine(Medicine medicine) async {
    // 1. Check Limits
    final isPremium = _subscriptionProvider?.isPremium ?? false;
    if (!isPremium && _medicines.length >= 3) {
      throw PremiumLimitException(
        "You have reached the free limit of 3 routines.",
      );
    }

    try {
      final newMedicine = await _db.createMedicine(medicine);
      _medicines.add(newMedicine);
      await _updateRefillReminder(newMedicine);
      notifyListeners();
      return newMedicine;
    } catch (e) {
      debugPrint('Error adding routine: $e');
      return null;
    }
  }

  /// Update an existing routine.
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
      debugPrint('Error updating routine: $e');
      return false;
    }
  }

  /// Delete a routine.
  Future<bool> deleteMedicine(int id) async {
    try {
      await _db.deleteMedicine(id);
      _medicines.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting routine: $e');
      return false;
    }
  }

  /// Delete a routine and return snapshot for undo.
  Future<MedicineDeletionSnapshot?> deleteMedicineWithSnapshot(
    int medicineId,
  ) async {
    try {
      final medicine = await _db.getMedicine(medicineId);
      if (medicine == null) return null;

      final schedules = await _db.getSchedulesForMedicine(medicineId);
      final logs = await _db.getLogsForMedicine(medicineId);
      final snoozedDoses = await _db.getSnoozedDosesForMedicine(medicineId);

      final snapshot = MedicineDeletionSnapshot(
        medicine: medicine,
        schedules: schedules,
        logs: logs,
        snoozedDoses: snoozedDoses,
      );

      await _notifications.cancelNotificationsForMedicine(
        medicineId: medicineId,
        scheduleIds: schedules.map((s) => s.id).whereType<int>().toList(),
      );

      await _db.deleteMedicineGraph(medicineId);
      _medicines.removeWhere((m) => m.id == medicineId);
      notifyListeners();

      return snapshot;
    } catch (e) {
      debugPrint('Error deleting routine with snapshot: $e');
      return null;
    }
  }

  /// Restore previously deleted routine data graph.
  Future<bool> restoreDeletedMedicine(MedicineDeletionSnapshot snapshot) async {
    try {
      await _db.restoreMedicineGraph(snapshot);
      await loadMedicines();

      await _rescheduleSnapshotSchedules(snapshot);
      await _updateRefillReminder(snapshot.medicine);

      return true;
    } catch (e) {
      debugPrint('Error restoring deleted routine: $e');
      return false;
    }
  }

  /// Legacy inventory hook. The simplified RoutineTime flow does not call this.
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
            if (profile != null &&
                profile.shareEnabled &&
                profile.linkedCaregiverIds.isNotEmpty) {
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

  /// Increment stock (Undo Take)
  Future<void> incrementStock(int medicineId) async {
    try {
      await _db.incrementStock(medicineId);

      final index = _medicines.indexWhere((m) => m.id == medicineId);
      if (index != -1) {
        final medicine = _medicines[index];
        final updatedMedicine = medicine.copyWith(
          currentStock: medicine.currentStock + 1,
        );
        _medicines[index] = updatedMedicine;
        await _updateRefillReminder(updatedMedicine);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error incrementing stock: $e');
    }
  }

  /// Get routine by ID.
  Medicine? getMedicineById(int id) {
    try {
      return _medicines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refresh routines from database.
  Future<void> refresh() async {
    await loadMedicines();
  }

  /// Refill reminders are intentionally disabled for routines.
  Future<void> _updateRefillReminder(Medicine _) async {
    return;
  }

  Future<void> _rescheduleSnapshotSchedules(
    MedicineDeletionSnapshot snapshot,
  ) async {
    final medicineId = snapshot.medicine.id;
    if (medicineId == null) return;

    for (final schedule in snapshot.schedules) {
      final scheduleId = schedule.id;
      if (scheduleId == null) continue;

      if (schedule.frequencyType == FrequencyType.specificDays &&
          schedule.daysList.isNotEmpty) {
        for (final weekday in schedule.daysList) {
          final nextTime = _nextSpecificWeekdayTime(schedule, weekday);
          if (nextTime == null) continue;

          await _notifications.scheduleMedicineReminder(
            notificationId: NotificationService.specificDayNotificationId(
              scheduleId,
              weekday,
            ),
            medicineId: medicineId,
            medicineName: snapshot.medicine.name,
            dosage: snapshot.medicine.dosage,
            scheduledTime: nextTime,
            frequencyType: FrequencyType.specificDays,
          );
        }
        continue;
      }

      final nextTime = schedule.getNextScheduledTime();
      if (nextTime == null) continue;

      await _notifications.scheduleMedicineReminder(
        notificationId: scheduleId,
        medicineId: medicineId,
        medicineName: snapshot.medicine.name,
        dosage: snapshot.medicine.dosage,
        scheduledTime: nextTime,
        frequencyType: schedule.frequencyType,
      );
    }
  }

  DateTime? _nextSpecificWeekdayTime(Schedule schedule, int weekday) {
    final now = DateTime.now();
    final parts = schedule.timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    for (var i = 0; i <= 370; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: i));
      if (date.weekday != weekday) continue;

      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (!candidate.isAfter(now)) continue;
      if (!schedule.shouldTriggerOnDate(candidate)) continue;
      return candidate;
    }
    return null;
  }
}
