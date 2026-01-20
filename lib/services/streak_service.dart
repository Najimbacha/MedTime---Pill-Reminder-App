import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../models/log.dart';

/// Service for tracking user streaks and achievements
class StreakService {
  static final StreakService instance = StreakService._init();
  StreakService._init();

  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _lastPerfectDateKey = 'last_perfect_date';
  static const String _totalPerfectDaysKey = 'total_perfect_days';
  static const String _achievementsKey = 'achievements_unlocked';

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalPerfectDays = 0;
  Set<String> _unlockedAchievements = {};

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalPerfectDays => _totalPerfectDays;
  Set<String> get unlockedAchievements => _unlockedAchievements;

  /// Initialize the streak service from shared preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
    _longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    _totalPerfectDays = prefs.getInt(_totalPerfectDaysKey) ?? 0;
    
    final achievementsList = prefs.getStringList(_achievementsKey) ?? [];
    _unlockedAchievements = achievementsList.toSet();

    // Check if we need to update streak based on yesterday's performance
    await _checkAndUpdateStreak();
    
    debugPrint('✅ StreakService initialized: $_currentStreak day streak');
  }

  /// Check yesterday's logs and update streak accordingly
  Future<void> _checkAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPerfectDateStr = prefs.getString(_lastPerfectDateKey);
    final today = DateTime.now();
    final todayStr = _dateToString(today);
    
    if (lastPerfectDateStr == null) {
      // First time - check if today is perfect so far
      return;
    }

    final lastPerfectDate = DateTime.parse(lastPerfectDateStr);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = _dateToString(yesterday);

    // If last perfect date was not yesterday and not today, reset streak
    if (lastPerfectDateStr != yesterdayStr && lastPerfectDateStr != todayStr) {
      // Check how many days since last perfect
      final daysSincePerfect = today.difference(lastPerfectDate).inDays;
      if (daysSincePerfect > 1) {
        _currentStreak = 0;
        await _savePrefs();
      }
    }
  }

  /// Call this when user takes a medicine - checks if day is now perfect
  Future<bool> onMedicineTaken() async {
    final isPerfectDay = await _checkIfTodayIsPerfect();
    if (isPerfectDay) {
      await _markDayAsPerfect();
      return true;
    }
    return false;
  }

  /// Check if all scheduled medicines for today have been taken
  Future<bool> _checkIfTodayIsPerfect() async {
    final db = DatabaseHelper.instance;
    final logs = await db.getAllLogs();
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Get today's logs
    final todayLogs = logs.where((log) {
      final logTime = log.scheduledTime;
      return logTime.isAfter(todayStart) && logTime.isBefore(todayEnd);
    }).toList();

    if (todayLogs.isEmpty) return false;

    // Check if all are taken
    final allTaken = todayLogs.every((log) => log.status == LogStatus.take);
    return allTaken;
  }

  /// Mark today as a perfect day
  Future<List<Achievement>> _markDayAsPerfect() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = _dateToString(today);
    
    final lastPerfectDateStr = prefs.getString(_lastPerfectDateKey);
    
    // Only update if today isn't already marked
    if (lastPerfectDateStr == todayStr) {
      return []; // Already marked today
    }

    // Check if yesterday was perfect
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = _dateToString(yesterday);
    
    if (lastPerfectDateStr == yesterdayStr) {
      _currentStreak++;
    } else {
      _currentStreak = 1;
    }

    _totalPerfectDays++;
    
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    await prefs.setString(_lastPerfectDateKey, todayStr);
    await _savePrefs();

    // Check for new achievements
    return _checkForNewAchievements();
  }

  /// Check and unlock any new achievements
  List<Achievement> _checkForNewAchievements() {
    final newAchievements = <Achievement>[];

    for (final achievement in allAchievements) {
      if (!_unlockedAchievements.contains(achievement.id)) {
        if (achievement.checkUnlocked(this)) {
          _unlockedAchievements.add(achievement.id);
          newAchievements.add(achievement);
        }
      }
    }

    if (newAchievements.isNotEmpty) {
      _saveAchievements();
    }

    return newAchievements;
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, _currentStreak);
    await prefs.setInt(_longestStreakKey, _longestStreak);
    await prefs.setInt(_totalPerfectDaysKey, _totalPerfectDays);
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_achievementsKey, _unlockedAchievements.toList());
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool Function(StreakService) checkUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.checkUnlocked,
  });
}

/// All available achievements
final List<Achievement> allAchievements = [
  Achievement(
    id: 'first_dose',
    title: 'First Step',
    description: 'Take your first medicine',
    emoji: '🌱',
    checkUnlocked: (s) => s.totalPerfectDays >= 1,
  ),
  Achievement(
    id: 'streak_3',
    title: 'Getting Started',
    description: '3-day streak',
    emoji: '🔥',
    checkUnlocked: (s) => s.currentStreak >= 3,
  ),
  Achievement(
    id: 'streak_7',
    title: 'Week Warrior',
    description: '7-day streak',
    emoji: '⭐',
    checkUnlocked: (s) => s.currentStreak >= 7,
  ),
  Achievement(
    id: 'streak_14',
    title: 'Fortnight Focus',
    description: '14-day streak',
    emoji: '🏆',
    checkUnlocked: (s) => s.currentStreak >= 14,
  ),
  Achievement(
    id: 'streak_30',
    title: 'Month Master',
    description: '30-day streak',
    emoji: '💎',
    checkUnlocked: (s) => s.currentStreak >= 30,
  ),
  Achievement(
    id: 'streak_90',
    title: 'Champion',
    description: '90-day streak',
    emoji: '👑',
    checkUnlocked: (s) => s.currentStreak >= 90,
  ),
  Achievement(
    id: 'perfect_10',
    title: 'Dedicated',
    description: '10 perfect days total',
    emoji: '💪',
    checkUnlocked: (s) => s.totalPerfectDays >= 10,
  ),
  Achievement(
    id: 'perfect_50',
    title: 'Committed',
    description: '50 perfect days total',
    emoji: '🎯',
    checkUnlocked: (s) => s.totalPerfectDays >= 50,
  ),
  Achievement(
    id: 'perfect_100',
    title: 'Legend',
    description: '100 perfect days total',
    emoji: '🌟',
    checkUnlocked: (s) => s.totalPerfectDays >= 100,
  ),
];
