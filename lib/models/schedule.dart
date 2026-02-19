/// Frequency types for medicine schedules
enum FrequencyType { daily, specificDays, interval, asNeeded }

/// Represents a schedule for taking a medicine
class Schedule {
  final int? id;
  final int medicineId;
  final String timeOfDay; // Format: "HH:mm" (24-hour)
  final FrequencyType frequencyType;
  final String? frequencyDays; // Comma-separated days: "1,3,5" (Mon, Wed, Fri)
  final int? intervalDays; // For "Every X days"
  final String? startDate; // Start date for interval calculation: "YYYY-MM-DD"
  final String? endDate; // End date for course completion: "YYYY-MM-DD"

  Schedule({
    this.id,
    required this.medicineId,
    required this.timeOfDay,
    required this.frequencyType,
    this.frequencyDays,
    this.intervalDays,
    this.startDate,
    this.endDate,
  });

  /// Parse frequency days string into list of integers
  List<int> get daysList {
    if (frequencyDays == null || frequencyDays!.isEmpty) return [];
    return frequencyDays!.split(',').map((e) => int.parse(e.trim())).toList();
  }

  /// Check if schedule should trigger on a specific date
  bool shouldTriggerOnDate(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    final weekday = checkDate.weekday; // 1=Monday, 7=Sunday

    // Check date range if provided
    if (startDate != null) {
      final start = DateTime.parse(startDate!);
      final startDateOnly = DateTime(start.year, start.month, start.day);
      if (checkDate.isBefore(startDateOnly)) return false;
    }
    if (endDate != null) {
      final end = DateTime.parse(endDate!);
      final endDateOnly = DateTime(end.year, end.month, end.day);
      if (checkDate.isAfter(endDateOnly)) return false;
    }

    switch (frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.specificDays:
        return daysList.contains(weekday);
      case FrequencyType.interval:
        if (intervalDays == null || startDate == null) return true;
        final start = DateTime.parse(startDate!);
        final startDateOnly = DateTime(start.year, start.month, start.day);
        final diff = checkDate.difference(startDateOnly).inDays;
        return diff % intervalDays! == 0;
      case FrequencyType.asNeeded:
        return true;
    }
  }

  /// Check if schedule should trigger today
  bool shouldTriggerToday() => shouldTriggerOnDate(DateTime.now());

  /// Get next scheduled DateTime (today or next valid day)
  DateTime? getNextScheduledTime() {
    final now = DateTime.now();
    final parts = timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Start with today's scheduled time
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, check for next valid day
    if (scheduledTime.isBefore(now)) {
      switch (frequencyType) {
        case FrequencyType.daily:
          // For daily, next is tomorrow
          scheduledTime = scheduledTime.add(const Duration(days: 1));
          break;
        case FrequencyType.specificDays:
          // Find next valid weekday
          scheduledTime = _getNextSpecificDay(scheduledTime);
          break;
        case FrequencyType.interval:
          // Find next interval day
          scheduledTime = _getNextIntervalDay(scheduledTime);
          break;
        case FrequencyType.asNeeded:
          // As needed schedules don't auto-schedule
          return null;
      }
    } else {
      // Time hasn't passed today - check if today is a valid day
      if (!shouldTriggerToday()) {
        switch (frequencyType) {
          case FrequencyType.specificDays:
            scheduledTime = _getNextSpecificDay(scheduledTime);
            break;
          case FrequencyType.interval:
            scheduledTime = _getNextIntervalDay(scheduledTime);
            break;
          default:
            break;
        }
      }
    }

    // Check if scheduled time is within date range
    if (endDate != null) {
      final end = DateTime.parse(endDate!);
      if (scheduledTime.isAfter(end)) return null;
    }

    return scheduledTime;
  }

  /// Get next specific weekday for scheduling
  DateTime _getNextSpecificDay(DateTime from) {
    final days = daysList;
    if (days.isEmpty) return from;

    DateTime next = from;
    for (int i = 0; i < 7; i++) {
      next = from.add(Duration(days: i + 1));
      if (days.contains(next.weekday)) {
        return DateTime(
          next.year,
          next.month,
          next.day,
          int.parse(timeOfDay.split(':')[0]),
          int.parse(timeOfDay.split(':')[1]),
        );
      }
    }
    return from; // Fallback
  }

  /// Get next interval day for scheduling
  DateTime _getNextIntervalDay(DateTime from) {
    if (intervalDays == null || startDate == null) return from;

    final start = DateTime.parse(startDate!);
    final daysSinceStart = from.difference(start).inDays;
    final daysUntilNext = intervalDays! - (daysSinceStart % intervalDays!);

    final next = from.add(Duration(days: daysUntilNext));
    return DateTime(
      next.year,
      next.month,
      next.day,
      int.parse(timeOfDay.split(':')[0]),
      int.parse(timeOfDay.split(':')[1]),
    );
  }

  /// Get human-readable frequency description
  String get frequencyDescription {
    switch (frequencyType) {
      case FrequencyType.daily:
        return 'Every day';
      case FrequencyType.specificDays:
        final days = daysList.map((d) => _getDayName(d)).join(', ');
        return days;
      case FrequencyType.interval:
        return 'Every $intervalDays days';
      case FrequencyType.asNeeded:
        return 'As needed (PRN)';
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'time_of_day': timeOfDay,
      'frequency_type': frequencyType.name,
      'frequency_days': frequencyDays,
      'interval_days': intervalDays,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  /// Create from database map
  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      timeOfDay: map['time_of_day'] as String,
      frequencyType: FrequencyType.values.firstWhere(
        (e) => e.name == map['frequency_type'],
        orElse: () => FrequencyType.daily,
      ),
      frequencyDays: map['frequency_days'] as String?,
      intervalDays: map['interval_days'] as int?,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
    );
  }

  /// Create a copy with modified fields
  Schedule copyWith({
    int? id,
    int? medicineId,
    String? timeOfDay,
    FrequencyType? frequencyType,
    String? frequencyDays,
    int? intervalDays,
    String? startDate,
    String? endDate,
  }) {
    return Schedule(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      intervalDays: intervalDays ?? this.intervalDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() {
    return 'Schedule(id: $id, medicineId: $medicineId, time: $timeOfDay, frequency: ${frequencyType.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Schedule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
