import 'package:flutter/foundation.dart';
import '../models/log.dart';
import '../models/medicine.dart';
import '../models/schedule.dart'; // Added import for Schedule
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Provider for managing adherence logs
class LogProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncService _syncService = SyncService();

  List<Log> _logs = [];
  bool _isLoading = false;

  List<Log> get logs => _logs;
  bool get isLoading => _isLoading;

  /// Get today's logs
  List<Log> get todayLogs {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _logs.where((log) {
      // Use >= for start to include logs at exactly midnight
      return !log.scheduledTime.isBefore(startOfDay) &&
          log.scheduledTime.isBefore(endOfDay);
    }).toList();
  }

  /// Get logs for a specific medicine
  List<Log> getLogsForMedicine(int medicineId) {
    return _logs.where((log) => log.medicineId == medicineId).toList();
  }

  /// Get logs for a specific date (from DB)
  Future<List<Log>> getLogsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await _db.getLogsByDateRange(startOfDay, endOfDay);
  }

  /// Load all logs from database
  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load last 30 days of logs
      // IMPORTANT: Use end of today, not DateTime.now(), to include logs 
      // with scheduled times later today (e.g., 6 PM when it's currently 1 PM)
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final startDate = now.subtract(const Duration(days: 30));
      _logs = await _db.getLogsByDateRange(startDate, endOfToday);
      debugPrint('✅ LogProvider.loadLogs: Loaded ${_logs.length} logs');
    } catch (e) {
      debugPrint('❌ Error loading logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new log entry
  Future<Log?> addLog(Log log) async {
    debugPrint('🔵 LogProvider.addLog: Adding log for medicineId=${log.medicineId}, status=${log.status.name}');
    try {
      final newLog = await _db.createLog(log);
      debugPrint('✅ LogProvider.addLog: Created log with id=${newLog.id}');
      _logs.insert(0, newLog); // Add to beginning for chronological order
      debugPrint('✅ LogProvider.addLog: Added to local list, notifying listeners');
      notifyListeners();
      return newLog;
    } catch (e, stackTrace) {
      debugPrint('❌ LogProvider.addLog ERROR: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow; // Re-throw so calling code knows about the error
    }
  }

  /// Add a log and sync to cloud
  Future<Log?> addLogWithSync(Log log, Medicine medicine) async {
    debugPrint('🔵 LogProvider.addLogWithSync: Adding log for ${medicine.name} (id=${log.medicineId})');
    try {
      final newLog = await _db.createLog(log);
      debugPrint('✅ LogProvider.addLogWithSync: Created log with id=${newLog.id}');
      _logs.insert(0, newLog);
      debugPrint('✅ LogProvider.addLogWithSync: Added to local list, notifying listeners');
      notifyListeners();

      // Sync to cloud (fire and forget, don't block UI)
      debugPrint('🔵 LogProvider.addLogWithSync: Starting cloud sync (async)...');
      _syncService.uploadAdherenceLog(log: newLog, medicine: medicine).then((_) {
        debugPrint('✅ LogProvider.addLogWithSync: Cloud sync completed');
      }).catchError((e) {
        debugPrint('⚠️ LogProvider.addLogWithSync: Cloud sync failed (non-blocking): $e');
      });

      return newLog;
    } catch (e, stackTrace) {
      debugPrint('❌ LogProvider.addLogWithSync ERROR: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow; // Re-throw so calling code knows about the error
    }
  }

  /// Update an existing log
  Future<bool> updateLog(Log log) async {
    try {
      await _db.updateLog(log);
      final index = _logs.indexWhere((l) => l.id == log.id);
      if (index != -1) {
        _logs[index] = log;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating log: $e');
      return false;
    }
  }

  /// Delete a log entry (Undo)
  Future<bool> deleteLog(int id) async {
    try {
      await _db.deleteLog(id);
      _logs.removeWhere((l) => l.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting log: $e');
      return false;
    }
  }

  /// Mark medicine as taken
  Future<Log> markAsTaken(int medicineId, DateTime scheduledTime, {Medicine? medicine}) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.take,
    );
    
    if (medicine != null) {
      return await addLogWithSync(log, medicine) as Log;
    } else {
      return await addLog(log) as Log;
    }
  }

  /// Mark medicine as skipped
  Future<Log> markAsSkipped(int medicineId, DateTime scheduledTime, {Medicine? medicine}) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.skip,
    );
    
    if (medicine != null) {
      return await addLogWithSync(log, medicine) as Log;
    } else {
      return await addLog(log) as Log;
    }
  }

  /// Mark medicine as missed
  Future<Log> markAsMissed(int medicineId, DateTime scheduledTime, {Medicine? medicine}) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: null,
      status: LogStatus.missed,
    );
    
    if (medicine != null) {
      return await addLogWithSync(log, medicine) as Log;
    } else {
      return await addLog(log) as Log;
    }
  }

  /// Get adherence statistics for a date range
  Future<Map<String, dynamic>> getAdherenceStats(
      DateTime start, DateTime end) async {
    try {
      return await _db.getAdherenceStats(start, end);
    } catch (e) {
      debugPrint('Error getting adherence stats: $e');
      return {
        'total': 0,
        'taken': 0,
        'skipped': 0,
        'missed': 0,
        'adherence_rate': '0.0',
      };
    }
  }

  /// Get today's adherence rate
  Future<double> getTodayAdherenceRate() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final stats = await getAdherenceStats(startOfDay, endOfDay);
    final total = stats['total'] as int;
    final taken = stats['taken'] as int;
    
    if (total == 0) return 0.0;
    return (taken / total) * 100;
  }

  /// Calculate daily progress for Dashboard
  Map<String, dynamic> calculateDailyProgress(DateTime date, List<Schedule> schedules) {
    int total = 0;
    int taken = 0;
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Get logs for this date
    final logsForDate = _logs.where((l) => 
      l.scheduledTime.isAfter(startOfDay) && l.scheduledTime.isBefore(endOfDay)
    ).toList();
    
    for (var schedule in schedules) {
       // Skip PRN meds for progress calculation
       if (schedule.frequencyType == FrequencyType.asNeeded) continue;
       
       // Check if scheduled for this date
       bool isScheduled = _isScheduledForDate(schedule, date);
       
       if (isScheduled) {
         total++;
         
         // Check if taken
         // We match basically if there is any 'take' log for this medicine today
         // Ideally we match exact time, but for MVP/Simplicity if multiple doses exist, 
         // we might need more robust matching.
         // Let's match by medicineId and time if possible, or just count logs.
         
         // Construct expected time to match log's scheduledTime
         final parts = schedule.timeOfDay.split(':');
         final scheduledDateTime = DateTime(
           date.year, date.month, date.day, 
           int.parse(parts[0]), int.parse(parts[1])
         );
         
         final hasTakenLog = logsForDate.any((l) => 
           l.medicineId == schedule.medicineId && 
           l.status == LogStatus.take &&
           // Fuzzy match time (within a minute tolerance or exact?)
           // DateTime is precise. Let's compare minutes?
           // Actually Log.scheduledTime should match exactly how it was created from schedule.
           // But let's be safe and check if medicine ID matches and status is take.
           // But what if same med twice a day?
           // We need to match the specific slot.
           l.scheduledTime.year == scheduledDateTime.year &&
           l.scheduledTime.month == scheduledDateTime.month &&
           l.scheduledTime.day == scheduledDateTime.day &&
           l.scheduledTime.hour == scheduledDateTime.hour &&
           l.scheduledTime.minute == scheduledDateTime.minute
         );
         
         if (hasTakenLog) {
           taken++;
         }
       }
    }
    
    return {
      'total': total,
      'taken': taken,
      'percentage': total == 0 ? 0.0 : taken / total,
    };
  }

  bool _isScheduledForDate(Schedule schedule, DateTime date) {
    final dayDate = DateTime(date.year, date.month, date.day);
    
    // Check date range
    if (schedule.startDate != null) {
      final start = DateTime.parse(schedule.startDate!);
      if (dayDate.isBefore(start)) return false;
    }
    if (schedule.endDate != null) {
      final end = DateTime.parse(schedule.endDate!);
      if (dayDate.isAfter(end)) return false;
    }

    switch (schedule.frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.specificDays:
        return schedule.daysList.contains(date.weekday);
      case FrequencyType.interval:
        if (schedule.intervalDays == null || schedule.startDate == null) return true;
        final start = DateTime.parse(schedule.startDate!);
        final diff = dayDate.difference(start).inDays;
        return diff % schedule.intervalDays! == 0;
      case FrequencyType.asNeeded:
        return false; // Shouldn't happen here as we filter before
    }
  }

  /// Refresh logs from database
  Future<void> refresh() async {
    await loadLogs();
  }
}
