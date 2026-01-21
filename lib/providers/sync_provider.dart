import 'package:flutter/foundation.dart';
import '../models/shared_adherence_data.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

/// State management for sync operations and caregiver data
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();

  List<UserProfile> _linkedPatients = [];
  Map<String, List<SharedAdherenceData>> _patientTodayLogs = {};
  Map<String, Map<String, dynamic>> _patientStats = {};
  bool _isLoading = false;

  // Getters
  List<UserProfile> get linkedPatients => _linkedPatients;
  bool get isLoading => _isLoading;
  bool get isSyncing => _syncService.isSyncing;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;

  /// Load linked patients (for caregiver mode)
  Future<void> loadLinkedPatients() async {
    _isLoading = true;
    notifyListeners();

    try {
      _linkedPatients = await _authService.getLinkedPatients();
    } catch (e) {
      debugPrint('Error loading linked patients: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get today's logs for a patient
  Stream<List<SharedAdherenceData>> getTodayLogsStream(String patientId) {
    return _syncService.getPatientTodayLogs(patientId);
  }

  /// Get all logs stream for a patient
  Stream<List<SharedAdherenceData>> getLogsStream(String patientId) {
    return _syncService.getPatientAdherenceLogs(patientId);
  }

  /// Load adherence stats for a patient
  Future<Map<String, dynamic>> loadPatientStats(String patientId) async {
    try {
      final stats = await _syncService.getPatientAdherenceStats(patientId);
      _patientStats[patientId] = stats;
      notifyListeners();
      return stats;
    } catch (e) {
      debugPrint('Error loading patient stats: $e');
      return {};
    }
  }

  /// Get cached stats for a patient
  Map<String, dynamic>? getCachedStats(String patientId) {
    return _patientStats[patientId];
  }

  /// Sync today's logs for current user
  Future<void> syncTodayLogs() async {
    await _syncService.syncTodayLogs();
    notifyListeners();
  }

  /// Retry pending uploads
  Future<void> retryPendingUploads() async {
    await _syncService.retryPendingUploads();
    notifyListeners();
  }
}
