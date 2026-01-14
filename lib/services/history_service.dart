import '../models/log.dart';
import '../services/database_helper.dart';

class AdherenceData {
  final DateTime date;
  final int taken;
  final int total;

  AdherenceData(this.date, this.taken, this.total);
  
  double get rate => total > 0 ? (taken / total) * 100 : 0.0;
}

class HistoryService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Get daily adherence for the last 7 days
  Future<List<AdherenceData>> getLast7DaysAdherence() async {
    final now = DateTime.now();
    final List<AdherenceData> stats = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));
      
      final logs = await _db.getLogsByDateRange(date, nextDay);
      final takenCount = logs.where((l) => l.status == LogStatus.take).length;
      final totalCount = logs.length;

      stats.add(AdherenceData(date, takenCount, totalCount));
    }

    return stats;
  }

  /// Get overall adherence percentage
  Future<double> getOverallAdherence() async {
    final now = DateTime.now();
    final startOfTime = DateTime(2000); // Far past
    final stats = await _db.getAdherenceStats(startOfTime, now.add(const Duration(days: 1)));
    return double.tryParse(stats['adherence_rate'].toString()) ?? 0.0;
  }

  /// Get current streak (days with 100% adherence)
  Future<int> getCurrentStreak() async {
    int streak = 0;
    final now = DateTime.now();
    
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));
      
      final logs = await _db.getLogsByDateRange(date, nextDay);
      if (logs.isEmpty) {
        if (i == 0) continue; // Skip today if no meds scheduled yet
        break; 
      }

      final allTaken = logs.every((l) => l.status == LogStatus.take);
      if (allTaken) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }
}
