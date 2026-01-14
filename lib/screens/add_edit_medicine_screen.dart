import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/interaction_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';

/// Screen for adding or editing a medicine
class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicine;

  const AddEditMedicineScreen({super.key, this.medicine});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _pharmacyNameController;
  late TextEditingController _pharmacyPhoneController;

  int _selectedIcon = 1;
  int _selectedColor = 0xFF2196F3;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  FrequencyType _frequencyType = FrequencyType.daily;
  Set<int> _selectedDays = {};
  int _intervalDays = 2;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  
  List<InteractionWarning> _warnings = [];
  final InteractionService _interactionService = InteractionService();

  final List<int> _iconTypes = [1, 2, 3, 4];
  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFFF44336, // Red
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine?.name ?? '');
    _dosageController =
        TextEditingController(text: widget.medicine?.dosage ?? '');
    _stockController = TextEditingController(
        text: widget.medicine?.currentStock.toString() ?? '10');
    _thresholdController = TextEditingController(
        text: widget.medicine?.lowStockThreshold.toString() ?? '5');
    _pharmacyNameController = 
        TextEditingController(text: widget.medicine?.pharmacyName ?? '');
    _pharmacyPhoneController = 
        TextEditingController(text: widget.medicine?.pharmacyPhone ?? '');

    _nameController.addListener(_checkForInteractions);

    if (widget.medicine != null) {
      _selectedIcon = widget.medicine!.typeIcon;
      _selectedColor = widget.medicine!.color;
      _imagePath = widget.medicine!.imagePath;

      // Load schedule info
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scheduleProvider = context.read<ScheduleProvider>();
        final schedules = scheduleProvider.getSchedulesForMedicine(widget.medicine!.id!);
        if (schedules.isNotEmpty) {
          final s = schedules.first;
          setState(() {
            _frequencyType = s.frequencyType;
            _selectedTime = TimeOfDay(
              hour: int.parse(s.timeOfDay.split(':')[0]),
              minute: int.parse(s.timeOfDay.split(':')[1]),
            );
            if (s.frequencyType == FrequencyType.specificDays) {
              _selectedDays = s.daysList.toSet();
            } else if (s.frequencyType == FrequencyType.interval) {
              _intervalDays = s.intervalDays ?? 2;
              if (s.startDate != null) {
                _startDate = DateTime.parse(s.startDate!);
              }
            }
            if (s.endDate != null) {
              _endDate = DateTime.parse(s.endDate!);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkForInteractions);
    _nameController.dispose();
    _dosageController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _checkForInteractions() async {
    final String name = _nameController.text;
    if (name.length < 3) {
      if (_warnings.isNotEmpty) {
        setState(() => _warnings = []);
      }
      return;
    }

    final medicineProvider = context.read<MedicineProvider>();
    final results = await _interactionService.checkInteractions(
      name, 
      medicineProvider.medicines,
    );

    if (results.isNotEmpty || _warnings.isNotEmpty) {
      setState(() {
        _warnings = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInteractionWarnings(),
            // Medicine Name
            // Medicine Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter medicine name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Medication Photo
            const Text(
              'Medication Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: Hero(
                tag: widget.medicine != null 
                    ? 'med-icon-${widget.medicine!.id}' 
                    : 'med-icon-new',
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Color(_selectedColor).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(_selectedColor).withAlpha(76),
                          width: 2,
                        ),
                      ),
                      child: _imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                File(_imagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              _getIconData(_selectedIcon),
                              size: 60,
                              color: Color(_selectedColor),
                            ),
                    ),
                    if (_imagePath != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagePath = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dosage
            // Dosage
            TextFormField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g., 500mg)',
                prefixIcon: Icon(Icons.science_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter dosage';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Icon Selection
            const Text(
              'Medicine Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _iconTypes.map((iconType) {
                return _buildIconOption(iconType);
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color Selection
            const SizedBox(height: 24),

            // Color Selection
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _colors.map((color) {
                return _buildColorOption(color);
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Stock
            // Stock
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current Stock',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low Warning',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pharmacy Details
            const Divider(),
            const Text(
              'Pharmacy Details (Optional)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pharmacyNameController,
              decoration: const InputDecoration(
                labelText: 'Pharmacy Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pharmacyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Pharmacy Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 24),

            // Schedule Section
            const Divider(),
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Time Selection
            ListTile(
              leading: const Icon(Icons.access_time, size: 28),
              title: const Text('Time', style: TextStyle(fontSize: 18)),
              trailing: Text(
                _selectedTime.format(context),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),

            // Frequency Type
            const Text(
              'Frequency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioListTile<FrequencyType>(
              title: const Text('Daily', style: TextStyle(fontSize: 18)),
              value: FrequencyType.daily,
              groupValue: _frequencyType,
              onChanged: (value) {
                setState(() {
                  _frequencyType = value!;
                });
              },
            ),
            RadioListTile<FrequencyType>(
              title: const Text('Specific Days', style: TextStyle(fontSize: 18)),
              value: FrequencyType.specificDays,
              groupValue: _frequencyType,
              onChanged: (value) {
                setState(() {
                  _frequencyType = value!;
                });
              },
            ),
            RadioListTile<FrequencyType>(
              title: const Text('Every X days', style: TextStyle(fontSize: 18)),
              value: FrequencyType.interval,
              groupValue: _frequencyType,
              onChanged: (value) {
                setState(() {
                  _frequencyType = value!;
                });
              },
            ),
            RadioListTile<FrequencyType>(
              title: const Text('As Needed (PRN)', style: TextStyle(fontSize: 18)),
              value: FrequencyType.asNeeded,
              groupValue: _frequencyType,
              onChanged: (value) {
                setState(() {
                  _frequencyType = value!;
                });
              },
            ),

            // Day Selection (if specific days)
            if (_frequencyType == FrequencyType.specificDays) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip('Mon', 1),
                  _buildDayChip('Tue', 2),
                  _buildDayChip('Wed', 3),
                  _buildDayChip('Thu', 4),
                  _buildDayChip('Fri', 5),
                  _buildDayChip('Sat', 6),
                  _buildDayChip('Sun', 7),
                ],
              ),
            ],

            // Interval selector
            if (_frequencyType == FrequencyType.interval) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Every ', style: TextStyle(fontSize: 18)),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: _intervalDays.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (value) {
                        _intervalDays = int.tryParse(value) ?? 2;
                      },
                    ),
                  ),
                  const Text(' days', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note),
                title: const Text('End Date (Optional)', style: TextStyle(fontSize: 16)),
                subtitle: const Text('For short-term courses (e.g. antibiotics)'),
                trailing: Text(
                  _endDate != null 
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'No end date',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: _endDate != null ? Colors.blue : Colors.grey,
                  ),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _endDate = picked);
                  }
                },
              ),
              if (_endDate != null)
                TextButton.icon(
                  onPressed: () => setState(() => _endDate = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear end date'),
                ),
            ],

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveMedicine,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isEditing ? 'Update Medicine' : 'Add Medicine',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(int type) {
    switch (type) {
      case 1:
        return Icons.medication_rounded;
      case 2:
        return Icons.local_drink_rounded;
      case 3:
        return Icons.vaccines_rounded;
      case 4:
        return Icons.water_drop_rounded;
      default:
        return Icons.medication_rounded;
    }
  }

  Widget _buildIconOption(int type) {
    final isSelected = _selectedIcon == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = type),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isSelected 
              ? Color(_selectedColor).withAlpha(51) 
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(_selectedColor) : Theme.of(context).dividerColor,
            width: 2,
          ),
        ),
        child: Icon(
          _getIconData(type),
          color: isSelected ? Color(_selectedColor) : Colors.grey[600],
          size: 36,
        ),
      ),
    );
  }

  Widget _buildColorOption(int colorValue) {
    final isSelected = _selectedColor == colorValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = colorValue),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Color(colorValue).withAlpha(100),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 28) : null,
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 16)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(day);
          } else {
            _selectedDays.remove(day);
          }
        });
      },
    );
  }

  Widget _buildInteractionWarnings() {
    if (_warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _warnings.map((warning) {
        final isCritical = warning.severity == InteractionSeverity.CRITICAL;
        final color = isCritical ? Colors.red : Colors.orange;

        return Card(
          color: color.withAlpha(26),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(isCritical ? Icons.report : Icons.warning_amber, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interacts with: ${warning.drugB}',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        warning.message,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequencyType == FrequencyType.specificDays &&
        _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day', style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final medicine = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text,
      dosage: _dosageController.text,
      typeIcon: _selectedIcon,
      currentStock: int.parse(_stockController.text),
      lowStockThreshold: int.parse(_thresholdController.text),
      color: _selectedColor,
      imagePath: _imagePath,
      pharmacyName: _pharmacyNameController.text.isNotEmpty ? _pharmacyNameController.text : null,
      pharmacyPhone: _pharmacyPhoneController.text.isNotEmpty ? _pharmacyPhoneController.text : null,
    );

    final medicineProvider = context.read<MedicineProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    Medicine? savedMedicine;
    if (widget.medicine == null) {
      savedMedicine = await medicineProvider.addMedicine(medicine);
    } else {
      await medicineProvider.updateMedicine(medicine);
      savedMedicine = medicine;
    }

    if (savedMedicine != null && savedMedicine.id != null) {
      // Create schedule
      final frequencyDays = _frequencyType == FrequencyType.specificDays
          ? (_selectedDays.toList()..sort())
          : null;

      final schedule = Schedule(
        medicineId: savedMedicine.id!,
        timeOfDay: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        frequencyType: _frequencyType,
        frequencyDays: frequencyDays?.join(','),
        intervalDays: _frequencyType == FrequencyType.interval ? _intervalDays : null,
        startDate: _frequencyType == FrequencyType.interval 
            ? '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'
            : null,
        endDate: _endDate != null 
            ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
            : null,
      );

      await scheduleProvider.addSchedule(schedule, savedMedicine);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.medicine == null
                  ? '✓ Medicine added successfully'
                  : '✓ Medicine updated successfully',
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
