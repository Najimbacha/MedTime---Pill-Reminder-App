import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an invite for linking patient and caregiver
class CaregiverInvite {
  final String code;
  final String patientId;
  final String? patientName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status; // 'pending', 'accepted', 'expired', 'cancelled'

  CaregiverInvite({
    required this.code,
    required this.patientId,
    this.patientName,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.status = 'pending',
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == 'pending' && !isExpired;
  bool get isAccepted => status == 'accepted';

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status,
    };
  }

  factory CaregiverInvite.fromMap(String code, Map<String, dynamic> map) {
    return CaregiverInvite(
      code: code,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }

  factory CaregiverInvite.fromFirestore(DocumentSnapshot doc) {
    return CaregiverInvite.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  CaregiverInvite copyWith({
    String? code,
    String? patientId,
    String? patientName,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
  }) {
    return CaregiverInvite(
      code: code ?? this.code,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'CaregiverInvite(code: $code, patientId: $patientId, status: $status)';
  }
}
