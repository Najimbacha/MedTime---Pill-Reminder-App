import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/caregiver.dart';
import '../services/settings_service.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() => _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _notifyOnMissedDose = true;
  bool _notifyOnLowStock = true;

  @override
  void initState() {
    super.initState();
    final currentCaregiver = context.read<SettingsService>().caregiver;
    _nameController = TextEditingController(text: currentCaregiver?.name);
    _phoneController = TextEditingController(text: currentCaregiver?.phoneNumber);
    if (currentCaregiver != null) {
      _notifyOnMissedDose = currentCaregiver.notifyOnMissedDose;
      _notifyOnLowStock = currentCaregiver.notifyOnLowStock;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      await HapticHelper.error();
      return;
    }

    await HapticHelper.success();
    await SoundHelper.playClick();

    final caregiver = Caregiver(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      notifyOnMissedDose: _notifyOnMissedDose,
      notifyOnLowStock: _notifyOnLowStock,
    );

    if (mounted) {
      await context.read<SettingsService>().saveCaregiver(caregiver);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Caregiver Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, 
                        color: Theme.of(context).colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Your privacy is protected. Alerts are NOT sent automatically. You will review and send every message.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: 'e.g. +1234567890',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              Text(
                'Notification Preferences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Missed Dose Alert'),
                      subtitle: const Text('Prompt to notify when a dose is missed'),
                      value: _notifyOnMissedDose,
                      onChanged: (value) {
                        HapticHelper.selection();
                        setState(() => _notifyOnMissedDose = value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Low Stock Alert'),
                      subtitle: const Text('Prompt to ask for a refill'),
                      value: _notifyOnLowStock,
                      onChanged: (value) {
                        HapticHelper.selection();
                        setState(() => _notifyOnLowStock = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Caregiver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
