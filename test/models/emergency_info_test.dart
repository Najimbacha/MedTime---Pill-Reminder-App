import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/models/emergency_info.dart';
import 'dart:convert';

void main() {
  group('EmergencyInfo Model', () {
    group('Constructor', () {
      test('creates empty emergency info by default', () {
        final info = EmergencyInfo();

        expect(info.bloodGroup, '');
        expect(info.allergies, '');
        expect(info.chronicConditions, '');
        expect(info.medications, '');
        expect(info.emergencyContactName, '');
        expect(info.emergencyContactPhone, '');
      });

      test('creates emergency info with all fields', () {
        final info = EmergencyInfo(
          bloodGroup: 'O+',
          allergies: 'Penicillin',
          chronicConditions: 'Diabetes',
          medications: 'Metformin 500mg',
          emergencyContactName: 'John Doe',
          emergencyContactPhone: '+1234567890',
        );

        expect(info.bloodGroup, 'O+');
        expect(info.allergies, 'Penicillin');
        expect(info.chronicConditions, 'Diabetes');
        expect(info.medications, 'Metformin 500mg');
        expect(info.emergencyContactName, 'John Doe');
        expect(info.emergencyContactPhone, '+1234567890');
      });
    });

    group('toJsonString', () {
      test('converts to valid JSON string', () {
        final info = EmergencyInfo(
          bloodGroup: 'A-',
          allergies: 'Nuts',
          chronicConditions: 'Hypertension',
          medications: 'Lisinopril',
          emergencyContactName: 'Jane Doe',
          emergencyContactPhone: '+0987654321',
        );

        final jsonString = info.toJsonString();

        // Should be valid JSON
        expect(() => jsonDecode(jsonString), returnsNormally);

        final decoded = jsonDecode(jsonString);
        expect(decoded['blood_group'], 'A-');
        expect(decoded['allergies'], 'Nuts');
        expect(decoded['chronic_conditions'], 'Hypertension');
        expect(decoded['medications'], 'Lisinopril');
        expect(decoded['contact_name'], 'Jane Doe');
        expect(decoded['contact_phone'], '+0987654321');
      });

      test('handles empty fields', () {
        final info = EmergencyInfo();

        final jsonString = info.toJsonString();
        final decoded = jsonDecode(jsonString);

        expect(decoded['blood_group'], '');
        expect(decoded['allergies'], '');
      });
    });

    group('Serialization', () {
      test('toMap creates correct map', () {
        final info = EmergencyInfo(
          bloodGroup: 'B+',
          allergies: 'Shellfish',
          chronicConditions: 'Asthma',
          medications: 'Albuterol',
          emergencyContactName: 'Bob Smith',
          emergencyContactPhone: '+1112223333',
        );

        final map = info.toMap();

        expect(map['blood_group'], 'B+');
        expect(map['allergies'], 'Shellfish');
        expect(map['chronic_conditions'], 'Asthma');
        expect(map['medications'], 'Albuterol');
        expect(map['contact_name'], 'Bob Smith');
        expect(map['contact_phone'], '+1112223333');
      });

      test('fromMap creates correct EmergencyInfo', () {
        final map = {
          'blood_group': 'AB+',
          'allergies': 'Latex',
          'chronic_conditions': 'Heart Disease',
          'medications': 'Aspirin',
          'contact_name': 'Alice Johnson',
          'contact_phone': '+4445556666',
        };

        final info = EmergencyInfo.fromMap(map);

        expect(info.bloodGroup, 'AB+');
        expect(info.allergies, 'Latex');
        expect(info.chronicConditions, 'Heart Disease');
        expect(info.medications, 'Aspirin');
        expect(info.emergencyContactName, 'Alice Johnson');
        expect(info.emergencyContactPhone, '+4445556666');
      });

      test('fromMap handles null values', () {
        final map = <String, dynamic>{};

        final info = EmergencyInfo.fromMap(map);

        expect(info.bloodGroup, '');
        expect(info.allergies, '');
        expect(info.chronicConditions, '');
        expect(info.medications, '');
        expect(info.emergencyContactName, '');
        expect(info.emergencyContactPhone, '');
      });

      test('toMap and fromMap are reversible', () {
        final original = EmergencyInfo(
          bloodGroup: 'O-',
          allergies: 'Dairy',
          chronicConditions: 'Arthritis',
          medications: 'Ibuprofen',
          emergencyContactName: 'Chris Brown',
          emergencyContactPhone: '+7778889999',
        );

        final restored = EmergencyInfo.fromMap(original.toMap());

        expect(restored.bloodGroup, original.bloodGroup);
        expect(restored.allergies, original.allergies);
        expect(restored.chronicConditions, original.chronicConditions);
        expect(restored.medications, original.medications);
        expect(restored.emergencyContactName, original.emergencyContactName);
        expect(restored.emergencyContactPhone, original.emergencyContactPhone);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = EmergencyInfo(
          bloodGroup: 'A+',
          allergies: 'None',
          emergencyContactName: 'Original Contact',
        );

        final copy = original.copyWith(bloodGroup: 'B+', allergies: 'Pollen');

        expect(copy.bloodGroup, 'B+');
        expect(copy.allergies, 'Pollen');
        expect(copy.emergencyContactName, 'Original Contact'); // unchanged
      });

      test('preserves all fields when none specified', () {
        final original = EmergencyInfo(
          bloodGroup: 'O+',
          allergies: 'Bees',
          chronicConditions: 'None',
          medications: 'None',
          emergencyContactName: 'Test Contact',
          emergencyContactPhone: '+0000000000',
        );

        final copy = original.copyWith();

        expect(copy.bloodGroup, original.bloodGroup);
        expect(copy.allergies, original.allergies);
        expect(copy.chronicConditions, original.chronicConditions);
        expect(copy.medications, original.medications);
        expect(copy.emergencyContactName, original.emergencyContactName);
        expect(copy.emergencyContactPhone, original.emergencyContactPhone);
      });
    });

    group('Blood Group Validation', () {
      test('accepts all valid blood types', () {
        final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

        for (final bloodType in bloodTypes) {
          final info = EmergencyInfo(bloodGroup: bloodType);
          expect(info.bloodGroup, bloodType);
        }
      });
    });
  });
}
