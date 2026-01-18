import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/components/app_button.dart';
import '../core/components/app_text_field.dart';
import '../core/components/medicine_type_selector.dart';
import '../core/components/section_header.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/interaction_service.dart';

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
  late TextEditingController _instructionsController;

  int _selectedIcon = 1;
  int _selectedColor = 0xFF2196F3;
  String _selectedMedicineType = 'tablet';
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
  bool _isSaving = false;
  bool _showAdditionalInfo = false;

  static const Map<String, int> _medicineTypeIcons = {
    'tablet': 1,
    'liquid': 2,
    'injection': 3,
    'drop': 4,
  };

  static const Map<int, String> _iconToMedicineType = {
    1: 'tablet',
    2: 'liquid',
    3: 'injection',
    4: 'drop',
  };

  static const Map<String, String> _medicineTypeIconPaths = {
    'tablet': 'assets/icons/medicine/pill_capsule.png',
    'liquid': 'assets/icons/medicine/bottle.png',
    'injection': 'assets/icons/medicine/injection.png',
    'drop': 'assets/icons/medicine/syrup.png',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine?.name ?? '');
    _dosageController = TextEditingController(
      text: widget.medicine?.dosage ?? '',
    );
    _stockController = TextEditingController(
      text: widget.medicine?.currentStock.toString() ?? '10',
    );
    _thresholdController = TextEditingController(
      text: widget.medicine?.lowStockThreshold.toString() ?? '5',
    );
    _pharmacyNameController = TextEditingController(
      text: widget.medicine?.pharmacyName ?? '',
    );
    _pharmacyPhoneController = TextEditingController(
      text: widget.medicine?.pharmacyPhone ?? '',
    );
    _instructionsController = TextEditingController();

    _nameController.addListener(_checkForInteractions);

    if (widget.medicine != null) {
      _selectedIcon = widget.medicine!.typeIcon;
      _selectedColor = widget.medicine!.color;
      _selectedMedicineType = _typeFromIcon(_selectedIcon);
      _imagePath = widget.medicine!.imagePath;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scheduleProvider = context.read<ScheduleProvider>();
        final schedules = scheduleProvider.getSchedulesForMedicine(
          widget.medicine!.id!,
        );
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
    _instructionsController.dispose();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFFAFAFA),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_warnings.isNotEmpty) ...[
                  _buildInteractionWarnings(isDark),
                  const SizedBox(height: 16),
                ],

                _MinimalTextField(
                  label: 'Medicine Name',
                  hint: 'e.g., Aspirin',
                  controller: _nameController,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                _MinimalTextField(
                  label: 'Dosage',
                  hint: 'e.g., 500mg',
                  controller: _dosageController,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter dosage';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                _SectionLabel(label: 'Schedule', isDark: isDark),
                const SizedBox(height: 12),
                _buildTimeSelector(isDark),
                const SizedBox(height: 16),
                _buildFrequencyOptions(isDark),

                if (_frequencyType == FrequencyType.specificDays) ...[
                  const SizedBox(height: 16),
                  _buildDaySelector(isDark),
                ],

                if (_frequencyType == FrequencyType.interval) ...[
                  const SizedBox(height: 16),
                  _buildIntervalSelector(isDark),
                ],

                const SizedBox(height: 24),
                _buildAdditionalInfo(isDark),
                const SizedBox(height: 32),
                _buildActionButtons(isEditing, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(bool isDark) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            ),
            image: _imagePath != null
                ? DecorationImage(
                    image: FileImage(File(_imagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _imagePath == null
              ? Icon(
                  Icons.medication_outlined,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                )
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ImageButton(
              label: 'Camera',
              icon: Icons.camera_alt,
              onPressed: () => _pickImage(ImageSource.camera),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _ImageButton(
              label: 'Gallery',
              icon: Icons.photo_library,
              onPressed: () => _pickImage(ImageSource.gallery),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMedicineTypeSelector(bool isDark) {
    final types = [
      {
        'label': 'Tablet',
        'value': 'tablet',
        'iconPath': _medicineTypeIconPaths['tablet'],
      },
      {
        'label': 'Liquid',
        'value': 'liquid',
        'iconPath': _medicineTypeIconPaths['liquid'],
      },
      {
        'label': 'Injection',
        'value': 'injection',
        'iconPath': _medicineTypeIconPaths['injection'],
      },
      {
        'label': 'Drop',
        'value': 'drop',
        'iconPath': _medicineTypeIconPaths['drop'],
      },
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedMedicineType == type['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMedicineType = type['value'] as String;
                  _selectedIcon = _iconFromType(type['value'] as String);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE5E5E5)),
                  ),
                ),
                child: Column(
                  children: [
                    if (type['iconPath'] != null)
                      Image.asset(
                        type['iconPath'] as String,
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      )
                    else
                      Icon(
                        Icons.medication_outlined,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white60 : Colors.black54),
                        size: 24,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AppColors.medicineColors.map((color) {
        final isSelected = _selectedColor == color.value;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color.value),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdditionalInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _showAdditionalInfo = !_showAdditionalInfo),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Row(
                children: [
                  Text(
                    _showAdditionalInfo ? 'Hide' : 'Show more',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showAdditionalInfo ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoSection(isDark),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Type', isDark: isDark),
              const SizedBox(height: 12),
              _buildMedicineTypeSelector(isDark),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Color', isDark: isDark),
              const SizedBox(height: 12),
              _buildColorSelector(isDark),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MinimalTextField(
                      label: 'Stock',
                      controller: _stockController,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MinimalTextField(
                      label: 'Alert at',
                      controller: _thresholdController,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildPharmacySection(isDark),
              const SizedBox(height: 24),
              _MinimalTextField(
                label: 'Instructions',
                hint: 'e.g., Take with food',
                controller: _instructionsController,
                isDark: isDark,
              ),
            ],
          ),
          crossFadeState: _showAdditionalInfo
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(bool isDark) {
    return GestureDetector(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedTime.format(context),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOptions(bool isDark) {
    final options = [
      {'type': FrequencyType.daily, 'label': 'Daily'},
      {'type': FrequencyType.specificDays, 'label': 'Specific Days'},
      {'type': FrequencyType.interval, 'label': 'Every X days'},
      {'type': FrequencyType.asNeeded, 'label': 'As Needed'},
    ];

    return Column(
      children: options.map((option) {
        final isSelected = _frequencyType == option['type'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(
              () => _frequencyType = option['type'] as FrequencyType,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03))
                    : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFE5E5E5)),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white38 : Colors.black38),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: isDark ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option['label'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final dayNum = index + 1;
        final isSelected = _selectedDays.contains(dayNum);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(dayNum);
              } else {
                _selectedDays.add(dayNum);
              }
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE5E5E5)),
              ),
            ),
            child: Center(
              child: Text(
                days[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildIntervalSelector(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Every',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 60,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE5E5E5),
                ),
              ),
              child: Center(
                child: TextFormField(
                  initialValue: _intervalDays.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _intervalDays = int.tryParse(value) ?? 2;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'days',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _endDate ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _endDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  color: isDark ? Colors.white60 : Colors.black54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'End date (optional)',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPharmacySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Pharmacy (Optional)', isDark: isDark),
        const SizedBox(height: 12),
        _MinimalTextField(
          label: 'Pharmacy Name',
          controller: _pharmacyNameController,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _MinimalTextField(
          label: 'Pharmacy Phone',
          controller: _pharmacyPhoneController,
          isDark: isDark,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildInteractionWarnings(bool isDark) {
    return Column(
      children: _warnings.map((warning) {
        final isCritical = warning.severity == InteractionSeverity.CRITICAL;
        final color = isCritical ? Colors.red : Colors.orange;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCritical ? Icons.report : Icons.warning_amber,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interacts with: ${warning.drugB}',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      warning.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(bool isEditing, bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveMedicine,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  )
                : Text(
                    isEditing ? 'Update Medicine' : 'Add Medicine',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  String _typeFromIcon(int icon) {
    return _iconToMedicineType[icon] ?? 'tablet';
  }

  int _iconFromType(String type) {
    return _medicineTypeIcons[type] ?? 1;
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

    if (_frequencyType == FrequencyType.specificDays && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one day'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final medicine = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text,
      dosage: _dosageController.text,
      typeIcon: _selectedIcon,
      currentStock: int.parse(_stockController.text),
      lowStockThreshold: int.parse(_thresholdController.text),
      color: _selectedColor,
      imagePath: _imagePath,
      pharmacyName: _pharmacyNameController.text.isNotEmpty
          ? _pharmacyNameController.text
          : null,
      pharmacyPhone: _pharmacyPhoneController.text.isNotEmpty
          ? _pharmacyPhoneController.text
          : null,
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
      final frequencyDays = _frequencyType == FrequencyType.specificDays
          ? (_selectedDays.toList()..sort())
          : null;

      final schedule = Schedule(
        medicineId: savedMedicine.id!,
        timeOfDay:
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        frequencyType: _frequencyType,
        frequencyDays: frequencyDays?.join(','),
        intervalDays: _frequencyType == FrequencyType.interval
            ? _intervalDays
            : null,
        startDate: _frequencyType == FrequencyType.interval
            ? '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'
            : null,
        endDate: _endDate != null
            ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
            : null,
      );

      await scheduleProvider.addSchedule(schedule, savedMedicine);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.medicine == null
                  ? '✓ Medicine added successfully'
                  : '✓ Medicine updated successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white60 : Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _MinimalTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool isDark;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _MinimalTextField({
    required this.label,
    this.hint,
    required this.controller,
    required this.isDark,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

class _ImageButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _ImageButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
