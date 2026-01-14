import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_info.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';

/// Screen for managing emergency info and QR code generation
class EmergencyInfoScreen extends StatefulWidget {
  const EmergencyInfoScreen({super.key});

  @override
  State<EmergencyInfoScreen> createState() => _EmergencyInfoScreenState();
}

class _EmergencyInfoScreenState extends State<EmergencyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _screenshotController = ScreenshotController();
  
  late TextEditingController _bloodController;
  late TextEditingController _allergiesController;
  late TextEditingController _conditionsController;
  late TextEditingController _medsController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;

  EmergencyInfo _info = EmergencyInfo();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bloodController = TextEditingController();
    _allergiesController = TextEditingController();
    _conditionsController = TextEditingController();
    _medsController = TextEditingController();
    _contactNameController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _loadEmergencyInfo();
  }

  @override
  void dispose() {
    _bloodController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('emergency_info');
    if (data != null) {
      setState(() {
        _info = EmergencyInfo.fromMap(jsonDecode(data));
        _bloodController.text = _info.bloodGroup;
        _allergiesController.text = _info.allergies;
        _conditionsController.text = _info.chronicConditions;
        _medsController.text = _info.medications;
        _contactNameController.text = _info.emergencyContactName;
        _contactPhoneController.text = _info.emergencyContactPhone;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEmergencyInfo() async {
    if (!_formKey.currentState!.validate()) return;

    await HapticHelper.medium();
    await SoundHelper.playClick();

    final newInfo = EmergencyInfo(
      bloodGroup: _bloodController.text,
      allergies: _allergiesController.text,
      chronicConditions: _conditionsController.text,
      medications: _medsController.text,
      emergencyContactName: _contactNameController.text,
      emergencyContactPhone: _contactPhoneController.text,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_info', jsonEncode(newInfo.toMap()));

    setState(() {
      _info = newInfo;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Emergency information saved', style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveAsWallpaper() async {
    await HapticHelper.success();
    await SoundHelper.playSuccess();

    try {
      final image = await _screenshotController.captureFromWidget(
        _buildWallpaperWidget(),
        delay: const Duration(milliseconds: 10),
      );

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/emergency_qr_wallpaper.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Wallpaper Saved'),
            content: Text('The emergency QR code has been saved to:\n\n$imagePath\n\nYou can now set it as your lock screen wallpaper from your gallery.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving wallpaper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWallpaperWidget() {
    return Container(
      width: 1080,
      height: 1920,
      padding: const EdgeInsets.all(50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emergency, size: 100, color: Colors.red),
          const SizedBox(height: 40),
          const Text(
            'EMERGENCY MEDICAL INFO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 60,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: QrImageView(
              data: _info.toJsonString(),
              version: QrVersions.auto,
              size: 600,
            ),
          ),
          const SizedBox(height: 60),
          const Text(
            'SCAN FOR CRITICAL INFORMATION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 100),
          _buildWallpaperField('NAME', _info.emergencyContactName),
          _buildWallpaperField('BLOOD', _info.bloodGroup),
        ],
      ),
    );
  }

  Widget _buildWallpaperField(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency QR Code'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                color: Colors.redAccent,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.white, size: 32),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'This information will be encoded into a QR code that paramedics can scan during an emergency.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildField(_bloodController, 'Blood Group', Icons.bloodtype, 'e.g. A+'),
              _buildField(_allergiesController, 'Allergies', Icons.warning_amber, 'e.g. Penicillin, Peanuts'),
              _buildField(_conditionsController, 'Chronic Conditions', Icons.history, 'e.g. Diabetes, Asthma'),
              _buildField(_medsController, 'Current Medications', Icons.medication, 'e.g. Insulin, Aspirin'),
              const Divider(height: 48),
              const Text(
                'Emergency Contact',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildField(_contactNameController, 'Contact Name', Icons.person),
              _buildField(_contactPhoneController, 'Contact Phone', Icons.phone, null, TextInputType.phone),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveEmergencyInfo,
                icon: const Icon(Icons.save),
                label: const Text('Save Information', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (_info.bloodGroup.isNotEmpty || _info.emergencyContactPhone.isNotEmpty) ...[
                const Divider(height: 48),
                const Text(
                  'Generated QR Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _info.toJsonString(),
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveAsWallpaper,
                  icon: const Icon(Icons.wallpaper),
                  label: const Text('Save as Wallpaper', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: Set this image as your lock screen wallpaper so paramedics can scan it without unlocking your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, [
    String? hint,
    TextInputType type = TextInputType.text,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        keyboardType: type,
      ),
    );
  }
}
