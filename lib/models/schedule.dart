/// Frequency types for medicine schedules
enum FrequencyType {
  daily,
  specificDays,
  interval,
  asNeeded,
}

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

  /// Check if schedule should trigger today
  bool shouldTriggerToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = now.weekday; // 1=Monday, 7=Sunday

    // Check date range if provided
    if (startDate != null) {
      final start = DateTime.parse(startDate!);
      if (today.isBefore(start)) return false;
    }
    if (endDate != null) {
      final end = DateTime.parse(endDate!);
      if (today.isAfter(end)) return false;
    }

    switch (frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.specificDays:
        return daysList.contains(weekday);
      case FrequencyType.interval:
        if (intervalDays == null || startDate == null) return true;
        final start = DateTime.parse(startDate!);
        final diff = now.difference(start).inDays;
        return diff % intervalDays! == 0;
      case FrequencyType.asNeeded:
        return true;
    }
  }

  /// Get next scheduled DateTime for today
  DateTime? getNextScheduledTime() {
    if (!shouldTriggerToday()) return null;

    final now = DateTime.now();
    final parts = timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, return null
    if (scheduledTime.isBefore(now)) return null;

    return scheduledTime;
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
