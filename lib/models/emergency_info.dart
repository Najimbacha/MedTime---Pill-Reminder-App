import 'dart:convert';

/// Represents critical emergency information for the user
class EmergencyInfo {
  final String bloodGroup;
  final String allergies;
  final String chronicConditions;
  final String medications;
  final String emergencyContactName;
  final String emergencyContactPhone;

  EmergencyInfo({
    this.bloodGroup = '',
    this.allergies = '',
    this.chronicConditions = '',
    this.medications = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
  });

  /// Convert to JSON for QR code
  String toJsonString() {
    return jsonEncode(toMap());
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'blood_group': bloodGroup,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'medications': medications,
      'contact_name': emergencyContactName,
      'contact_phone': emergencyContactPhone,
    };
  }

  /// Create from map
  factory EmergencyInfo.fromMap(Map<String, dynamic> map) {
    return EmergencyInfo(
      bloodGroup: map['blood_group'] ?? '',
      allergies: map['allergies'] ?? '',
      chronicConditions: map['chronic_conditions'] ?? '',
      medications: map['medications'] ?? '',
      emergencyContactName: map['contact_name'] ?? '',
      emergencyContactPhone: map['contact_phone'] ?? '',
    );
  }

  /// Create a copy with modified fields
  EmergencyInfo copyWith({
    String? bloodGroup,
    String? allergies,
    String? chronicConditions,
    String? medications,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return EmergencyInfo(
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medications: medications ?? this.medications,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }
}
