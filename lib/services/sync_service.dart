import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shared_adherence_data.dart';
import '../models/user_profile.dart';
import '../models/log.dart';
import '../models/medicine.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Service for syncing adherence data to Firestore
/// Enables real-time sharing with caregivers
class SyncService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;
  
  // Pending sync queue for offline support
  final List<SharedAdherenceData> _pendingUploads = [];

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get pendingCount => _pendingUploads.length;

  /// Upload adherence log to Firestore
  /// Called when a dose is taken, skipped, or missed
  /// This method is designed to never throw - all errors are caught and logged
  Future<void> uploadAdherenceLog({
    required Log log,
    required Medicine medicine,
  }) async {
    try {
      debugPrint('🔵 SyncService.uploadAdherenceLog: Starting...');
      
      final user = _authService.currentUser;
      if (user == null) {
        debugPrint('⚠️ SyncService.uploadAdherenceLog: No user signed in, skipping sync');
        return;
      }

      // Check if sharing is enabled
      UserProfile? profile;
      try {
        profile = await _authService.getCurrentUserProfile();
      } catch (e) {
        debugPrint('⚠️ SyncService.uploadAdherenceLog: Could not get profile, skipping sync: $e');
        return;
      }
      
      if (profile == null || !profile.shareEnabled) {
        debugPrint('⚠️ SyncService.uploadAdherenceLog: Sharing disabled, skipping sync');
        return;
      }

      final data = SharedAdherenceData(
        id: '',
        odMedicineId: medicine.id.toString(),
        medicineName: '${medicine.name} ${medicine.dosage ?? ''}',
        scheduledTime: log.scheduledTime,
        actualTime: log.actualTime,
        status: log.status.name,
      );

      _isSyncing = true;
      notifyListeners();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('adherenceLogs')
          .add(data.toMap());

      _lastSyncTime = DateTime.now();
      _syncError = null;
      debugPrint('✅ SyncService.uploadAdherenceLog: Successfully synced');
    } catch (e) {
      debugPrint('⚠️ SyncService.uploadAdherenceLog: Error (non-fatal): $e');
      _syncError = 'Failed to sync: $e';
      // Don't rethrow - this should never block the main operation
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Retry pending uploads
  Future<void> retryPendingUploads() async {
    if (_pendingUploads.isEmpty) return;

    final user = _authService.currentUser;
    if (user == null) return;

    _isSyncing = true;
    notifyListeners();

    final failedUploads = <SharedAdherenceData>[];

    for (final data in _pendingUploads) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('adherenceLogs')
            .add(data.toMap());
      } catch (e) {
        failedUploads.add(data);
      }
    }

    _pendingUploads.clear();
    _pendingUploads.addAll(failedUploads);
    _isSyncing = false;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  /// Get adherence logs stream for a patient (used by caregivers)
  Stream<List<SharedAdherenceData>> getPatientAdherenceLogs(String patientId) {
    return _firestore
        .collection('users')
        .doc(patientId)
        .collection('adherenceLogs')
        .orderBy('scheduledTime', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedAdherenceData.fromFirestore(doc))
            .toList());
  }

  /// Get today's adherence logs stream for a patient
  Stream<List<SharedAdherenceData>> getPatientTodayLogs(String patientId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('users')
        .doc(patientId)
        .collection('adherenceLogs')
        .where('scheduledTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedAdherenceData.fromFirestore(doc))
            .toList());
  }

  /// Get adherence stats for a patient
  Future<Map<String, dynamic>> getPatientAdherenceStats(
    String patientId, {
    int days = 7,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(patientId)
        .collection('adherenceLogs')
        .where('scheduledTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final logs = snapshot.docs
        .map((doc) => SharedAdherenceData.fromFirestore(doc))
        .toList();

    final total = logs.length;
    final taken = logs.where((l) => l.isTaken).length;
    final missed = logs.where((l) => l.isMissed).length;
    final skipped = logs.where((l) => l.isSkipped).length;

    return {
      'total': total,
      'taken': taken,
      'missed': missed,
      'skipped': skipped,
      'adherenceRate': total > 0 ? (taken / total * 100) : 0.0,
    };
  }

  /// Sync all today's logs to cloud (for initial sync or catch-up)
  Future<void> syncTodayLogs() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final profile = await _authService.getCurrentUserProfile();
    if (profile == null || !profile.shareEnabled) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final logs = await _db.getTodayLogs();
      final medicines = await _db.getAllMedicines();

      final medicineMap = {for (var m in medicines) m.id: m};

      for (final log in logs) {
        final medicine = medicineMap[log.medicineId];
        if (medicine == null) continue;

        final data = SharedAdherenceData(
          id: '',
          odMedicineId: medicine.id.toString(),
          medicineName: '${medicine.name} ${medicine.dosage ?? ''}',
          scheduledTime: log.scheduledTime,
          actualTime: log.actualTime,
          status: log.status.name,
        );

        // Check if already synced
        final existing = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('adherenceLogs')
            .where('odMedicineId', isEqualTo: data.odMedicineId)
            .where('scheduledTime',
                isEqualTo: Timestamp.fromDate(data.scheduledTime))
            .get();

        if (existing.docs.isEmpty) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('adherenceLogs')
              .add(data.toMap());
        }
      }

      _lastSyncTime = DateTime.now();
      _syncError = null;
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncError = 'Failed to sync: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Clear sync error
  void clearError() {
    _syncError = null;
    notifyListeners();
  }
}
