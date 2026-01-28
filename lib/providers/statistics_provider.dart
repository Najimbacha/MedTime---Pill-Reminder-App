import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';
import '../models/log.dart';

class StatisticsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  double _overallAdherence = 0.0;
  int _currentStreak = 0;
  List<double> _weeklyAdherence = List.filled(7, 0.0); // Mon-Sun
  bool _isLoading = false;

  double get overallAdherence => _overallAdherence;
  int get currentStreak => _currentStreak;
  List<double> get weeklyAdherence => _weeklyAdherence;
  bool get isLoading => _isLoading;

  Future<void> loadStatistics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      
      // 1. Overall Adherence (Last 30 days)
      final start30 = now.subtract(const Duration(days: 30));
      final logs30 = await _db.getLogsByDateRange(start30, now);
      _overallAdherence = _calculateAdherence(logs30);

      // 2. Weekly Adherence (Last 7 days relative to Monday start or just last 7 days?)
      // Let's do last 7 days for the chart, ending Today.
      List<double> weekly = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        final dailyLogs = await _db.getLogsByDateRange(start, end);
        weekly.add(_calculateAdherence(dailyLogs));
      }
      _weeklyAdherence = weekly;

      // 3. Current Streak
      // We need to check day by day backwards. 
      // A "streak day" is a day where ALL scheduled meds were TAKEN.
      // If a day had NO scheduled meds, it maintains the streak? Or ignores it?
      // Usually "perfect adherence" implies (taken / total) == 1.0 for that day.
      int streak = 0;
      // Check up to 365 days back
      for (int i = 0; i < 365; i++) {
        // Start from yesterday? Or today? 
        // If today is incomplete, we don't count it yet? Or current streak includes today if finished?
        // Safety: Start checking from Yesterday. If Today is 100%, add 1.
        // Simplified: Check from Today backwards.
        final date = now.subtract(Duration(days: i));
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        
        final dailyLogs = await _db.getLogsByDateRange(start, end);
        
        if (dailyLogs.isEmpty) {
          // No meds scheduled this day. Continue streak? Or break?
          // Typically break or skip. Let's assume if you have NO meds, you are "good".
          // But consecutive days usually implies action.
          // Let's stop if no logs found to avoid infinite streaks for new users.
          if (streak == 0 && i == 0) continue; // If today has no logs, just skip today
           break; // Stop if we hit a day with no data (registration day)
        }

        bool allTaken = true;
        bool hasScheduled = false;
        
        for (var log in dailyLogs) {
           // Only count scheduled events that are not skipped/missed
           // If any is missed/skipped, streak breaks.
           if (log.status != LogStatus.take) {
             allTaken = false;
             break;
           }
           hasScheduled = true;
        }

        if (hasScheduled && allTaken) {
          streak++;
        } else {
          // If we are checking Today (i=0) and it's not perfect YET this doesn't break streak,
          // just means streak doesn't increment for today.
          if (i == 0) continue; 
          break;
        }
      }
      _currentStreak = streak;

    } catch (e) {
      debugPrint('Error loading statistics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double _calculateAdherence(List<Log> logs) {
    if (logs.isEmpty) return 0.0;
    // status: take, skip, missed. 
    // Taken / (Taken + Missed + Skipped)
    // Sometimes 'Skip' is excluded from denominator? Let's include everything as "Scheduled".
    int taken = logs.where((l) => l.status == LogStatus.take).length;
    return (taken / logs.length) * 100;
  }
}
