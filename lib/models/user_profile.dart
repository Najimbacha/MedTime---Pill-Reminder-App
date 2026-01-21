import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile stored in Firestore
/// Can be either a patient or a caregiver (or both)
class UserProfile {
  final String id; // Firebase Auth UID
  final String? displayName;
  final String? email;
  final String role; // 'patient', 'caregiver', or 'both'
  final List<String> linkedPatientIds; // For caregivers
  final List<String> linkedCaregiverIds; // For patients
  final String? fcmToken; // For push notifications
  final bool shareEnabled; // Master toggle for sharing
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.email,
    this.role = 'patient',
    this.linkedPatientIds = const [],
    this.linkedCaregiverIds = const [],
    this.fcmToken,
    this.shareEnabled = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? role,
    List<String>? linkedPatientIds,
    List<String>? linkedCaregiverIds,
    String? fcmToken,
    bool? shareEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      linkedPatientIds: linkedPatientIds ?? this.linkedPatientIds,
      linkedCaregiverIds: linkedCaregiverIds ?? this.linkedCaregiverIds,
      fcmToken: fcmToken ?? this.fcmToken,
      shareEnabled: shareEnabled ?? this.shareEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'role': role,
      'linkedPatientIds': linkedPatientIds,
      'linkedCaregiverIds': linkedCaregiverIds,
      'fcmToken': fcmToken,
      'shareEnabled': shareEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      displayName: map['displayName'],
      email: map['email'],
      role: map['role'] ?? 'patient',
      linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? []),
      linkedCaregiverIds: List<String>.from(map['linkedCaregiverIds'] ?? []),
      fcmToken: map['fcmToken'],
      shareEnabled: map['shareEnabled'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    return UserProfile.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  bool get isPatient => role == 'patient' || role == 'both';
  bool get isCaregiver => role == 'caregiver' || role == 'both';
  bool get hasLinkedCaregivers => linkedCaregiverIds.isNotEmpty;
  bool get hasLinkedPatients => linkedPatientIds.isNotEmpty;

  @override
  String toString() {
    return 'UserProfile(id: $id, displayName: $displayName, role: $role, shareEnabled: $shareEnabled)';
  }
}
