import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/caregiver.dart';

class CaregiverHelper {
  static Future<void> sendMissedDoseAlert(Caregiver caregiver, String medicineName, String time) async {
    final message = 'Hi ${caregiver.name}, just letting you know I missed my dose of $medicineName at $time. - Sent from MedTime app';
    await _sendSms(caregiver.phoneNumber, message);
  }

  static Future<void> sendLowStockAlert(Caregiver caregiver, String medicineName, int remaining) async {
    final message = 'Hi ${caregiver.name}, my $medicineName is running low (only $remaining left). Can you help me refill it? - Sent from MedTime app';
    await _sendSms(caregiver.phoneNumber, message);
  }

  static Future<void> _sendSms(String phone, String message) async {
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else {
        // Fallback or error handling if needed, but usually canLaunchUrl checks enough
        debugPrint('Could not launch SMS');
      }
    } catch (e) {
      debugPrint('Error launching SMS: $e');
    }
  }
}
