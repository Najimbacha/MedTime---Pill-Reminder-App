import 'package:flutter/foundation.dart';
import '../models/log.dart';
import '../models/schedule.dart'; // Added import for Schedule
import '../services/database_helper.dart';

/// Provider for managing adherence logs
class LogProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

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
      return log.scheduledTime.isAfter(startOfDay) &&
          log.scheduledTime.isBefore(endOfDay);
    }).toList();
  }

  /// Get logs for a specific medicine
  List<Log> getLogsForMedicine(int medicineId) {
    return _logs.where((log) => log.medicineId == medicineId).toList();
  }

  /// Load all logs from database
  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load last 30 days of logs
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      _logs = await _db.getLogsByDateRange(startDate, endDate);
    } catch (e) {
      debugPrint('Error loading logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new log entry
  Future<Log?> addLog(Log log) async {
    try {
      final newLog = await _db.createLog(log);
      _logs.insert(0, newLog); // Add to beginning for chronological order
      notifyListeners();
      return newLog;
    } catch (e) {
      debugPrint('Error adding log: $e');
      return null;
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

  /// Mark medicine as taken
  Future<void> markAsTaken(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.take,
    );
    await addLog(log);
  }

  /// Mark medicine as skipped
  Future<void> markAsSkipped(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: DateTime.now(),
      status: LogStatus.skip,
    );
    await addLog(log);
  }

  /// Mark medicine as missed
  Future<void> markAsMissed(int medicineId, DateTime scheduledTime) async {
    final log = Log(
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actualTime: null,
      status: LogStatus.missed,
    );
    await addLog(log);
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
