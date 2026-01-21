import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight adherence data synced to cloud for caregivers
/// Only contains necessary info to respect privacy
class SharedAdherenceData {
  final String id;
  final String odMedicineId; // Original device medicine ID
  final String medicineName;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final String status; // 'taken', 'missed', 'skipped'
  final DateTime syncedAt;

  SharedAdherenceData({
    required this.id,
    required this.odMedicineId,
    required this.medicineName,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();

  SharedAdherenceData copyWith({
    String? id,
    String? odMedicineId,
    String? medicineName,
    DateTime? scheduledTime,
    DateTime? actualTime,
    String? status,
    DateTime? syncedAt,
  }) {
    return SharedAdherenceData(
      id: id ?? this.id,
      odMedicineId: odMedicineId ?? this.odMedicineId,
      medicineName: medicineName ?? this.medicineName,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actualTime: actualTime ?? this.actualTime,
      status: status ?? this.status,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'odMedicineId': odMedicineId,
      'medicineName': medicineName,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'actualTime': actualTime != null ? Timestamp.fromDate(actualTime!) : null,
      'status': status,
      'syncedAt': Timestamp.fromDate(syncedAt),
    };
  }

  factory SharedAdherenceData.fromMap(String id, Map<String, dynamic> map) {
    String rawStatus = map['status'] ?? 'taken';
    // Normalize legacy/incorrect status strings
    if (rawStatus == 'take') rawStatus = 'taken';
    if (rawStatus == 'skip') rawStatus = 'skipped';

    return SharedAdherenceData(
      id: id,
      odMedicineId: map['odMedicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      scheduledTime: (map['scheduledTime'] as Timestamp).toDate(),
      actualTime: (map['actualTime'] as Timestamp?)?.toDate(),
      status: rawStatus,
      syncedAt: (map['syncedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory SharedAdherenceData.fromFirestore(DocumentSnapshot doc) {
    return SharedAdherenceData.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
  bool get isSkipped => status == 'skipped';

  @override
  String toString() {
    return 'SharedAdherenceData(medicineName: $medicineName, status: $status, scheduledTime: $scheduledTime)';
  }
}
