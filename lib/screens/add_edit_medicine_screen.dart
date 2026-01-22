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
import '../utils/sound_helper.dart';
import '../utils/haptic_helper.dart';
import '../utils/common_medicines.dart';

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
  late TextEditingController _dosageAmountController;

  // Dosage unit
  String _dosageUnit = 'mg';
  final List<String> _dosageUnits = ['mg', 'ml', 'tablet', 'capsule', 'drops'];

  // Schedule times
  List<TimeOfDay> _reminderTimes = [];

  // Frequency
  FrequencyType _frequencyType = FrequencyType.daily;
  Set<int> _selectedDays = {};
  int _intervalDays = 2;
  DateTime _startDate = DateTime.now();

  // Additional info (collapsed by default)
  bool _showAdditionalInfo = false;
  int _selectedIcon = 1;
  int _selectedColor = 0xFF2196F3;
  String _selectedMedicineType = 'tablet';
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _pharmacyNameController;
  late TextEditingController _pharmacyPhoneController;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  List<InteractionWarning> _warnings = [];
  final InteractionService _interactionService = InteractionService();
  bool _isSaving = false;

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
    _dosageAmountController = TextEditingController();

    // Initialize additional controllers first
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

    // Parse existing dosage if editing
    if (widget.medicine != null) {
      _parseDosage(widget.medicine!.dosage);
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
            final timeParts = s.timeOfDay.split(':');
            _reminderTimes = [
              TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              ),
            ];
            if (s.frequencyType == FrequencyType.specificDays) {
              _selectedDays = s.daysList.toSet();
            } else if (s.frequencyType == FrequencyType.interval) {
              _intervalDays = s.intervalDays ?? 2;
              if (s.startDate != null) {
                _startDate = DateTime.parse(s.startDate!);
              }
            }
          });
        }
      });
    }

    _nameController.addListener(_checkForInteractions);
  }

  void _parseDosage(String dosage) {
    final regex = RegExp(r'(\d+\.?\d*)\s*([a-zA-Z]+)');
    final match = regex.firstMatch(dosage);
    if (match != null) {
      _dosageAmountController.text = match.group(1) ?? '';
      final unit = match.group(2)?.toLowerCase() ?? 'mg';
      if (_dosageUnits.contains(unit)) {
        _dosageUnit = unit;
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkForInteractions);
    _nameController.dispose();
    _dosageAmountController.dispose();
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

  bool _isFormValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_dosageAmountController.text.trim().isEmpty) return false;
    final amount = double.tryParse(_dosageAmountController.text);
    if (amount == null || amount <= 0) return false;

    if (_frequencyType == FrequencyType.specificDays && _selectedDays.isEmpty) {
      return false;
    }

    if (_frequencyType == FrequencyType.interval &&
        (_intervalDays < 2 || _intervalDays > 30)) {
      return false;
    }

    if (_frequencyType != FrequencyType.asNeeded && _reminderTimes.isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicine != null;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
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
      body: Stack(
        children: [
          SafeArea(
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

                    // Medicine Section
                    _SectionLabel(label: 'MEDICINE', isDark: isDark),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return CommonMedicines.names.where((String option) {
                              return option.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  );
                            });
                          },
                          onSelected: (String selection) {
                            _nameController.text = selection;
                            final defaultMed = CommonMedicines.find(selection);
                            if (defaultMed != null) {
                              setState(() {
                                _selectedIcon = defaultMed.typeIcon;
                                _selectedColor = defaultMed.color;
                                // Also try to guess type string
                                _selectedMedicineType = _iconToMedicineType[_selectedIcon] ?? 'tablet';
                              });
                              HapticHelper.medium();
                            }
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            // Sync internal controller with our form controller
                            if (controller.text != _nameController.text) {
                               controller.text = _nameController.text;
                            }
                            // Listen to changes to update our controller (for form validation)
                            // Actually, better to just use the one controller.
                            // But Autocomplete wants its own. 
                            // Let's attach our listener to the passed controller to sync back.
                            return _MinimalTextField(
                              label: '',
                              hint: 'e.g., Aspirin',
                              controller: controller, // Use Autocomplete's controller
                              focusNode: focusNode,
                              isDark: isDark,
                              onChanged: (val) {
                                  _nameController.text = val;
                                  _checkForInteractions(); // Trigger interaction check
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(16),
                                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                child: Container(
                                  width: constraints.maxWidth,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                     borderRadius: BorderRadius.circular(16),
                                     color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(
                                            option,
                                            style: TextStyle(color: isDark ? Colors.white : Colors.black)
                                        ),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
                    const SizedBox(height: 24),

                    // Dosage Section (structured)
                    _SectionLabel(label: 'DOSAGE', isDark: isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _MinimalTextField(
                            label: '',
                            hint: '500',
                            controller: _dosageAmountController,
                            isDark: isDark,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildDosageUnitDropdown(isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Example: 500 mg',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Schedule Section
                    _SectionLabel(label: 'SCHEDULE', isDark: isDark),
                    const SizedBox(height: 12),

                    if (_frequencyType != FrequencyType.asNeeded) ...[
                      // Time chips (existing reminder times)
                      if (_reminderTimes.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _reminderTimes.map((time) {
                            return _TimeChip(
                              time: time,
                              isDark: isDark,
                              onRemove: _reminderTimes.length > 1
                                  ? () {
                                      setState(() {
                                        _reminderTimes.remove(time);
                                      });
                                      HapticHelper.light();
                                    }
                                  : null,
                              onTap: () => _editTime(time),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      if (_reminderTimes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Quickly tap one of the chips below or add a time to set a reminder.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),

                      // Quick time chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _QuickTimeChip(
                              label: 'Morning',
                              time: const TimeOfDay(hour: 8, minute: 0),
                              isDark: isDark,
                              onTap: (time) => _addQuickTime(time),
                            ),
                            const SizedBox(width: 8),
                            _QuickTimeChip(
                              label: 'Noon',
                              time: const TimeOfDay(hour: 12, minute: 0),
                              isDark: isDark,
                              onTap: (time) => _addQuickTime(time),
                            ),
                            const SizedBox(width: 8),
                            _QuickTimeChip(
                              label: 'Evening',
                              time: const TimeOfDay(hour: 18, minute: 0),
                              isDark: isDark,
                              onTap: (time) => _addQuickTime(time),
                            ),
                            const SizedBox(width: 8),
                            _QuickTimeChip(
                              label: 'Night',
                              time: const TimeOfDay(hour: 22, minute: 0),
                              isDark: isDark,
                              onTap: (time) => _addQuickTime(time),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Add another time button
                      TextButton.icon(
                        onPressed: _addCustomTime,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add another time'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Frequency Section
                    _SectionLabel(label: 'FREQUENCY', isDark: isDark),
                    const SizedBox(height: 12),
                    _buildFrequencySegmentedControl(isDark),
                    const SizedBox(height: 16),

                    // Progressive disclosure based on frequency
                    _buildFrequencyDetails(isDark),

                    const SizedBox(height: 24),

                    // Reminder Preview
                    _buildReminderPreview(isDark),

                    const SizedBox(height: 24),

                    // Additional Information (collapsed)
                    _buildAdditionalInfo(isDark),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomBar(isEditing, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDosageUnitDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _dosageUnit,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          items: _dosageUnits.map((unit) {
            return DropdownMenuItem(value: unit, child: Text(unit));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _dosageUnit = value);
              HapticHelper.light();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFrequencySegmentedControl(bool isDark) {
    final options = [
      {'type': FrequencyType.daily, 'label': 'Daily'},
      {'type': FrequencyType.specificDays, 'label': 'Days'},
      {'type': FrequencyType.interval, 'label': 'Interval'},
      {'type': FrequencyType.asNeeded, 'label': 'PRN'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = _frequencyType == option['type'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _frequencyType = option['type'] as FrequencyType;
                  if (_frequencyType == FrequencyType.asNeeded) {
                    _reminderTimes.clear();
                  } else if (_reminderTimes.isEmpty) {
                    _reminderTimes.add(const TimeOfDay(hour: 9, minute: 0));
                  }
                });
                HapticHelper.selection();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF6366F1) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFrequencyDetails(bool isDark) {
    switch (_frequencyType) {
      case FrequencyType.daily:
        return const SizedBox.shrink();

      case FrequencyType.specificDays:
        return _buildWeekdayChips(isDark);

      case FrequencyType.interval:
        return _buildIntervalInput(isDark);

      case FrequencyType.asNeeded:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1A1A).withOpacity(0.5)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'As needed (no scheduled reminders)',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildWeekdayChips(bool isDark) {
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
            HapticHelper.selection();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE5E5E5)),
              ),
            ),
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
        );
      }),
    );
  }

  Widget _buildIntervalInput(bool isDark) {
    return Row(
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
          width: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            ),
          ),
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
              isDense: true,
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed >= 2 && parsed <= 30) {
                setState(() => _intervalDays = parsed);
              }
            },
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
    );
  }

  Widget _buildReminderPreview(bool isDark) {
    final preview = _generateReminderPreview();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              preview,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateReminderPreview() {
    if (_frequencyType == FrequencyType.asNeeded) {
      return 'No scheduled reminders. You can log doses anytime.';
    }

    if (_reminderTimes.isEmpty) {
      return 'Please add at least one reminder time.';
    }

    final times = _reminderTimes.map((t) => t.format(context)).toList()..sort();
    final timeStr = _formatTimesList(times);

    switch (_frequencyType) {
      case FrequencyType.daily:
        return 'Reminds you every day at $timeStr.';

      case FrequencyType.specificDays:
        if (_selectedDays.isEmpty) {
          return 'Please select at least one day.';
        }
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final selectedDayNames = _selectedDays.toList()..sort();
        final daysStr = selectedDayNames
            .map((d) => dayNames[d - 1])
            .toList()
            .join(', ')
            .replaceAll(RegExp(r', ([^,]+)$'), r' and $1');
        return 'Reminds you $daysStr at $timeStr.';

      case FrequencyType.interval:
        return 'Reminds you every $_intervalDays days at $timeStr (starting today).';

      default:
        return '';
    }
  }

  String _formatTimesList(List<String> times) {
    if (times.isEmpty) return '';
    if (times.length == 1) return times[0];
    if (times.length == 2) return '${times[0]} and ${times[1]}';

    final allButLast = times.sublist(0, times.length - 1).join(', ');
    return '$allButLast and ${times.last}';
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Row(
                children: [
                  Text(
                    _showAdditionalInfo ? 'Hide' : 'Show',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showAdditionalInfo ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showAdditionalInfo) ...[
          const SizedBox(height: 16),
          _buildPhotoSection(isDark),
          const SizedBox(height: 16),
          _buildMedicineTypeSelector(isDark),
          const SizedBox(height: 16),
          _buildColorSelector(isDark),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MinimalTextField(
                  label: 'Stock',
                  controller: _stockController,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MinimalTextField(
                  label: 'Alert at',
                  controller: _thresholdController,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
      ],
    );
  }

  Widget _buildPhotoSection(bool isDark) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                  size: 32,
                  color: isDark ? Colors.white24 : Colors.black26,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageButton(
              label: 'Camera',
              icon: Icons.camera_alt,
              onPressed: () => _pickImage(ImageSource.camera),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
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
      {'label': 'Tablet', 'value': 'tablet', 'iconPath': _medicineTypeIconPaths['tablet']},
      {'label': 'Liquid', 'value': 'liquid', 'iconPath': _medicineTypeIconPaths['liquid']},
      {'label': 'Injection', 'value': 'injection', 'iconPath': _medicineTypeIconPaths['injection']},
      {'label': 'Drop', 'value': 'drop', 'iconPath': _medicineTypeIconPaths['drop']},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types.map((type) {
        final isSelected = _selectedMedicineType == type['value'];
        final primaryColor = Color(_selectedColor);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMedicineType = type['value'] as String;
              _selectedIcon = _iconFromType(type['value'] as String);
            });
            HapticHelper.selection();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 70) / 4,
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.1))
                  : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (type['iconPath'] != null)
                  Image.asset(
                    type['iconPath'] as String,
                    width: 36,
                    height: 36,
                    color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                  )
                else
                  Icon(
                    Icons.medication_outlined,
                    color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                    size: 32,
                  ),
                const SizedBox(height: 8),
                Text(
                  type['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(bool isDark) {
    return Container(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppColors.medicineColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final color = AppColors.medicineColors[index];
          final isSelected = _selectedColor == color.value;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedColor = color.value);
              HapticHelper.selection();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
                    )
                  : null,
            ),
          );
        },
      ),
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

  Widget _buildStickyBottomBar(bool isEditing, bool isDark) {
    final isValid = _isFormValid();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark 
              ? [const Color(0xFF121212).withOpacity(0.95), const Color(0xFF121212)]
              : [Colors.white.withOpacity(0.95), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: (_isSaving || !isValid) ? null : _saveMedicine,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: isValid
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                          ? [Colors.white, const Color(0xFFE8E8E8)]
                          : [const Color(0xFF2A2A2A), Colors.black],
                    )
                  : null,
              color: isValid ? null : (isDark ? Colors.white12 : Colors.black12),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isValid
                  ? [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: _isSaving
                ? Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEditing ? Icons.check_rounded : Icons.add_rounded,
                        size: 22,
                        color: isValid
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Save Changes' : 'Add Medicine',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isValid
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white38 : Colors.black38),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }


  String _typeFromIcon(int icon) => _iconToMedicineType[icon] ?? 'tablet';
  int _iconFromType(String type) => _medicineTypeIcons[type] ?? 1;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (image != null) setState(() => _imagePath = image.path);
  }

  Future<void> _addCustomTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && !_reminderTimes.contains(picked)) {
      setState(() {
        _reminderTimes.add(picked);
        _reminderTimes.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      });
      HapticHelper.selection();
    }
  }

  void _addQuickTime(TimeOfDay time) {
    if (!_reminderTimes.contains(time)) {
      setState(() {
        _reminderTimes.add(time);
        _reminderTimes.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      });
      HapticHelper.selection();
    }
  }

  Future<void> _editTime(TimeOfDay oldTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: oldTime,
    );
    if (picked != null && picked != oldTime) {
      setState(() {
        final index = _reminderTimes.indexOf(oldTime);
        _reminderTimes[index] = picked;
        _reminderTimes.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      });
      HapticHelper.selection();
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate() || !_isFormValid()) return;

    setState(() => _isSaving = true);

    final dosageText = '${_dosageAmountController.text} $_dosageUnit';

    final medicine = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text.trim(),
      dosage: dosageText,
      typeIcon: _selectedIcon,
      currentStock: int.tryParse(_stockController.text) ?? 10,
      lowStockThreshold: int.tryParse(_thresholdController.text) ?? 5,
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
      if (_frequencyType != FrequencyType.asNeeded &&
          _reminderTimes.isNotEmpty) {
        final primaryTime = _reminderTimes.first;
        final frequencyDays = _frequencyType == FrequencyType.specificDays
            ? (_selectedDays.toList()..sort())
            : null;

        final schedule = Schedule(
          medicineId: savedMedicine.id!,
          timeOfDay:
              '${primaryTime.hour.toString().padLeft(2, '0')}:${primaryTime.minute.toString().padLeft(2, '0')}',
          frequencyType: _frequencyType,
          frequencyDays: frequencyDays?.join(','),
          intervalDays: _frequencyType == FrequencyType.interval
              ? _intervalDays
              : null,
          startDate: _frequencyType == FrequencyType.interval
              ? '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'
              : null,
        );

        await scheduleProvider.addSchedule(schedule, savedMedicine);
      }

      if (mounted) {
        await HapticHelper.success();
        setState(() => _isSaving = false);
        Navigator.pop(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.medicine == null
                      ? 'Medicine added successfully'
                      : 'Medicine updated successfully',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            elevation: 8,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const _MinimalTextField({
    required this.label,
    this.hint,
    required this.controller,
    required this.isDark,
    this.validator,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12, // Slightly larger
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black54, // Softer label
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            validator: validator,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final TimeOfDay time;
  final bool isDark;
  final VoidCallback? onRemove;
  final VoidCallback onTap;

  const _TimeChip({
    required this.time,
    required this.isDark,
    this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [Colors.white, const Color(0xFFE8E8E8)]
                : [const Color(0xFF2A2A2A), Colors.black],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: isDark ? Colors.black54 : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              time.format(context),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final bool isDark;
  final Function(TimeOfDay) onTap;

  const _QuickTimeChip({
    required this.label,
    required this.time,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF1E1E2E), const Color(0xFF181825)]
                : [Colors.white, const Color(0xFFF5F5F5)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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
