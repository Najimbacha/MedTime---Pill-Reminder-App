/// Represents a snoozed dose for a medicine
/// Tracks the original scheduled time and the new snoozed time
class SnoozedDose {
  final int? id;
  final int medicineId;
  final DateTime originalScheduledTime;
  final DateTime snoozedUntil;
  final DateTime createdAt;

  SnoozedDose({
    this.id,
    required this.medicineId,
    required this.originalScheduledTime,
    required this.snoozedUntil,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if the snooze has expired (snoozed time has passed)
  bool get isExpired => DateTime.now().isAfter(snoozedUntil);

  /// Get remaining time until snooze fires
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(snoozedUntil)) return Duration.zero;
    return snoozedUntil.difference(now);
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'original_scheduled_time': originalScheduledTime.toIso8601String(),
      'snoozed_until': snoozedUntil.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from database map
  factory SnoozedDose.fromMap(Map<String, dynamic> map) {
    return SnoozedDose(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      originalScheduledTime: DateTime.parse(
        map['original_scheduled_time'] as String,
      ),
      snoozedUntil: DateTime.parse(map['snoozed_until'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Create a copy with modified fields
  SnoozedDose copyWith({
    int? id,
    int? medicineId,
    DateTime? originalScheduledTime,
    DateTime? snoozedUntil,
    DateTime? createdAt,
  }) {
    return SnoozedDose(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      originalScheduledTime:
          originalScheduledTime ?? this.originalScheduledTime,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SnoozedDose(id: $id, medicineId: $medicineId, original: $originalScheduledTime, snoozedUntil: $snoozedUntil)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SnoozedDose &&
        other.medicineId == medicineId &&
        other.originalScheduledTime == originalScheduledTime;
  }

  @override
  int get hashCode => Object.hash(medicineId, originalScheduledTime);
}
