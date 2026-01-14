/// Status of a medicine log entry
enum LogStatus {
  take,
  skip,
  missed,
}

/// Represents a log entry for medicine adherence tracking
class Log {
  final int? id;
  final int medicineId;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final LogStatus status;

  Log({
    this.id,
    required this.medicineId,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
  });

  /// Check if medicine was taken on time (within 30 minutes of scheduled time)
  bool get takenOnTime {
    if (status != LogStatus.take || actualTime == null) return false;
    final difference = actualTime!.difference(scheduledTime).abs();
    return difference.inMinutes <= 30;
  }

  /// Get time difference in minutes
  int get minutesDifference {
    if (actualTime == null) return 0;
    return actualTime!.difference(scheduledTime).inMinutes;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case LogStatus.take:
        return 'Taken';
      case LogStatus.skip:
        return 'Skipped';
      case LogStatus.missed:
        return 'Missed';
    }
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': actualTime?.toIso8601String(),
      'status': status.name,
    };
  }

  /// Create from database map
  factory Log.fromMap(Map<String, dynamic> map) {
    return Log(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      scheduledTime: DateTime.parse(map['scheduled_time'] as String),
      actualTime: map['actual_time'] != null
          ? DateTime.parse(map['actual_time'] as String)
          : null,
      status: LogStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LogStatus.missed,
      ),
    );
  }

  /// Create a copy with modified fields
  Log copyWith({
    int? id,
    int? medicineId,
    DateTime? scheduledTime,
    DateTime? actualTime,
    LogStatus? status,
  }) {
    return Log(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actualTime: actualTime ?? this.actualTime,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'Log(id: $id, medicineId: $medicineId, scheduled: $scheduledTime, status: ${status.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Log && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
