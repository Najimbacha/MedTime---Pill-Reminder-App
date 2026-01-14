import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';
import 'settings_service.dart';
import '../models/caregiver.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../models/log.dart';

class BackupService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SettingsService _settings = SettingsService.instance;

  // Use a reliable key generation strategy in real app, here we use a fixed key for simplicity in MVP
  // WARN: In production, user should provide a password to derive this key
  static final _key = enc.Key.fromUtf8('MedTimeSecureBackupKey2026!!!!');
  static final _iv = enc.IV.fromLength(16);

  Future<void> createEncryptedBackup() async {
    try {
      final data = await _collectAllData();
      final jsonString = json.encode(data);
      
      final encrypted = _encrypt(jsonString);
      
      final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'medtime_backup_$now.meds';
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(encrypted);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'MedTime Encrypted Backup',
      );
    } catch (e) {
      debugPrint('Backup failed: $e');
      rethrow;
    }
  }

  Future<void> restoreFromBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = File(result.files.single.path!);
      final encryptedContent = await file.readAsString();
      
      final decryptedJson = _decrypt(encryptedContent);
      final data = json.decode(decryptedJson);

      await _restoreData(data);
    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _collectAllData() async {
    final medicines = await _db.getAllMedicines();
    final schedules = await _db.getAllSchedules();
    final logs = await _db.getLogsByDateRange(DateTime(2000), DateTime(2100)); // Get all logs
    
    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'logs': logs.map((l) => l.toMap()).toList(),
      'settings': {
        'caregiver': _settings.caregiver?.toMap(),
      }
    };
  }

  Future<void> _restoreData(Map<String, dynamic> data) async {
    // Clear existing data
    await _db.resetAllData();

    // Restore Medicines
    final medicines = (data['medicines'] as List).map((m) => Medicine.fromMap(m)).toList();
    for (var m in medicines) {
      await _db.createMedicine(m);
    }

    // Restore Schedules
    final schedules = (data['schedules'] as List).map((s) => Schedule.fromMap(s)).toList();
    for (var s in schedules) {
      await _db.createSchedule(s);
    }

    // Restore Logs
    final logs = (data['logs'] as List).map((l) => Log.fromMap(l)).toList();
    for (var l in logs) {
      await _db.createLog(l);
    }

    // Restore Settings
    if (data['settings'] != null && data['settings']['caregiver'] != null) {
      final caregiver = Caregiver.fromMap(data['settings']['caregiver']);
      await _settings.saveCaregiver(caregiver);
    }
  }

  String _encrypt(String plainText) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  String _decrypt(String encryptedBase64) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedBase64), iv: _iv);
  }
}
