import 'dart:io';
import 'dart:async';
import 'dart:math' show cos, sin;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  Timer? _debounceTimer;

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
    _debounceTimer?.cancel();
    _nameController.removeListener(_checkForInteractions);
    _nameController.dispose();
    _dosageAmountController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyPhoneController.dispose();
    super.dispose();
  }

  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.add_a_photo_rounded,
                    size: 32,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
          ),
          if (_imagePath != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () {
                  setState(() => _imagePath = null);
                  HapticHelper.light();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? label,
    required bool isDark,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface1Dark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: icon != null 
              ? Icon(icon, color: isDark ? Colors.white38 : Colors.black38) 
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          isDense: true,
        ),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTypeAndColorSelector(bool isDark) {
    return Column(
      children: [
        _buildMedicineTypeSelector(isDark),
        const SizedBox(height: 16),
        _buildColorSelector(isDark),
      ],
    );
  }

  Future<void> _checkForInteractions() async {
    // Cancel previous timer
    _debounceTimer?.cancel();

    final String name = _nameController.text;
    if (name.length < 3) {
      if (_warnings.isNotEmpty) {
        setState(() => _warnings = []);
      }
      return;
    }

    // Wait 800ms before calling API
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      
      final medicineProvider = context.read<MedicineProvider>();
      final results = await _interactionService.checkInteractions(
        name,
        medicineProvider.medicines,
      );

      if (mounted && (results.isNotEmpty || _warnings.isNotEmpty)) {
        setState(() {
          _warnings = results;
        });
      }
    });
  }

  bool _isFormValid() {
    if (_nameController.text.trim().isEmpty) return false;
    // Dosage is now optional
    if (_dosageAmountController.text.trim().isNotEmpty) {
      final amount = double.tryParse(_dosageAmountController.text);
      if (amount == null || amount <= 0) return false;
    }

    if (_frequencyType == FrequencyType.specificDays && _selectedDays.isEmpty) {
      return false;
    }

    if (_frequencyType == FrequencyType.interval &&
        (_intervalDays < 2 || _intervalDays > 30)) {
      return false;
    }

    if (_reminderTimes.isEmpty) {
      return false;
    }

    return true;
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicine != null;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: CircleAvatar(
             radius: 18,
             backgroundColor: isDark ? Colors.black26 : Colors.white54,
             child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.surfaceGradientDark : AppColors.surfaceGradientLight,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Interaction Warnings
                      if (_warnings.isNotEmpty) ...[
                        _buildInteractionWarnings(isDark),
                        const SizedBox(height: 24),
                      ],

                      // ═══════════════════════════════════════════════════════════
                      // CARD 1: Medicine Info (Glassmorphism)
                      // ═══════════════════════════════════════════════════════════
                      _GlassCard(
                        isDark: isDark,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        accentColor: Color(_selectedColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name Section
                            Consumer<MedicineProvider>(
                              builder: (context, provider, child) {
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
                                        _selectedMedicineType = _iconToMedicineType[_selectedIcon] ?? 'tablet';
                                      });
                                      HapticHelper.medium();
                                    }
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    if (controller.text != _nameController.text) {
                                       controller.text = _nameController.text;
                                    }
                                    return _AppleTextField(
                                      hint: 'Medicine name',
                                      controller: controller,
                                      focusNode: focusNode,
                                      isDark: isDark,
                                      icon: Icons.medication_rounded,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (val) {
                                          _nameController.text = val;
                                          _checkForInteractions();
                                      },
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(16),
                                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                        child: Container(
                                          width: MediaQuery.of(context).size.width - 72,
                                          constraints: const BoxConstraints(maxHeight: 200),
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
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Strength Row
                            const SizedBox(height: 16),
                            
                            // Form & Color Selector (Moved from Additional Info)
                            Text(
                              'Form & Type',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildMedicineTypeSelector(isDark),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════════════════════════
                      // CARD 2: Schedule (Glassmorphism)
                      // ═══════════════════════════════════════════════════════════
                      _GlassCard(
                        isDark: isDark,
                        accentColor: const Color(0xFF6366F1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'When do you take it?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Frequency Segmented Control
                            _buildAppleSegmentedControl(isDark),
                            
                            // Frequency Details (days selection or interval)
                            _buildFrequencyDetails(isDark),
                            
                            // Reminder Times (always shown now)
                            const SizedBox(height: 20),
                              
                              // Quick Add Row
                              Text(
                                'Quick add',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              // Preset Chips (quick add/remove)
                              _buildSimplePresetChips(isDark),
                              
                              const SizedBox(height: 16),
                              
                              // Selected Times Label
                              if (_reminderTimes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'Selected times',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              
                              // All Selected Times as Editable Pills
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ..._reminderTimes.map((time) => _AppleTimePill(
                                    time: time,
                                    isDark: isDark,
                                    onTap: () => _editTime(time),
                                    onRemove: () {
                                      setState(() => _reminderTimes.remove(time));
                                      HapticHelper.light();
                                    },
                                  )),
                                  
                                  // Add Custom Time Button (inline)
                                  GestureDetector(
                                    onTap: _addCustomTime,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark 
                                              ? Colors.white.withOpacity(0.12) 
                                              : Colors.black.withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 16,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Custom',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Visual Time Arc (when times selected)
                      if (_reminderTimes.isNotEmpty) ...[
                        _TimeArcWidget(
                          times: _reminderTimes,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Reminder Preview
                      _buildReminderPreview(isDark),

                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════════════════════════
                      // More Options (Collapsible)
                      // ═══════════════════════════════════════════════════════════
                      _buildAdditionalInfo(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Keyboard-aware Bottom Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                  ? 12 
                  : MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: _buildSaveButton(isEditing, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDosageUnitDropdown(bool isDark) {
    return Container(
      height: 56, // Match text field height
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface1Dark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _dosageUnit,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: isDark ? Colors.white70 : Colors.black54),
          dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
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

  /// Apple-style unit picker dropdown
  Widget _buildAppleUnitPicker(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.08) 
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _dosageUnit,
          isExpanded: true,
          icon: Icon(
            Icons.expand_more_rounded, 
            color: isDark ? Colors.white54 : Colors.black45,
            size: 20,
          ),
          dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
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

  /// Apple-style segmented control for frequency selection
  Widget _buildAppleSegmentedControl(bool isDark) {
    final options = [
      {'type': FrequencyType.daily, 'label': 'Daily'},
      {'type': FrequencyType.specificDays, 'label': 'Days'},
      {'type': FrequencyType.interval, 'label': 'Interval'},
      {'type': FrequencyType.asNeeded, 'label': 'As needed'},
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.06) 
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
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
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white.withOpacity(0.15) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Simple preset chips - just toggle add/remove
  Widget _buildSimplePresetChips(bool isDark) {
    final presets = [
      {'label': 'Morning', 'icon': Icons.wb_twilight_rounded, 'hour': 8, 'color': const Color(0xFFF59E0B)},
      {'label': 'Noon', 'icon': Icons.wb_sunny_rounded, 'hour': 12, 'color': const Color(0xFFEAB308)},
      {'label': 'Evening', 'icon': Icons.nights_stay_rounded, 'hour': 20, 'color': const Color(0xFF6366F1)},
      {'label': 'Bedtime', 'icon': Icons.bedtime_rounded, 'hour': 22, 'color': const Color(0xFF8B5CF6)},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: presets.map((preset) {
        final presetTime = TimeOfDay(hour: preset['hour'] as int, minute: 0);
        final chipColor = preset['color'] as Color;
        final isSelected = _reminderTimes.any((t) => 
          t.hour == presetTime.hour && t.minute == 0
        );
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _reminderTimes.removeWhere((t) => 
                  t.hour == presetTime.hour && t.minute == 0
                );
              } else {
                _reminderTimes.add(presetTime);
                _reminderTimes.sort((a, b) => 
                  (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)
                );
              }
            });
            HapticHelper.selection();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        chipColor.withOpacity(0.2),
                        chipColor.withOpacity(0.1),
                      ],
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? chipColor.withOpacity(0.5)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: chipColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  preset['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? chipColor
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 6),
                Text(
                  preset['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : chipColor.withOpacity(0.9))
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFrequencySegmentedControl(bool isDark) {
    final options = [
      {'type': FrequencyType.daily, 'label': 'Daily', 'icon': Icons.today_rounded},
      {'type': FrequencyType.specificDays, 'label': 'Days', 'icon': Icons.date_range_rounded},
      {'type': FrequencyType.interval, 'label': 'Interval', 'icon': Icons.loop_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = _frequencyType == option['type'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _frequencyType = option['type'] as FrequencyType;
                  if (_reminderTimes.isEmpty) {
                    _reminderTimes.add(const TimeOfDay(hour: 9, minute: 0));
                  }
                });
                HapticHelper.selection();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF6366F1) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ],
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

      default:
        return const SizedBox.shrink();


    }
  }

  Widget _buildWeekdayChips(bool isDark) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        alignment: WrapAlignment.center,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.surface1Dark : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                days[index][0], // First letter only for compact circle
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReminderPreview(bool isDark) {
    final preview = _generateReminderPreview();
    final hasNoTimes = _reminderTimes.isEmpty;
    
    // Amber warning colors
    const warningColor = Color(0xFFF59E0B);
    const successColor = Color(0xFF6366F1);
    final displayColor = hasNoTimes ? warningColor : successColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            displayColor.withOpacity(hasNoTimes ? 0.15 : 0.1),
            displayColor.withOpacity(hasNoTimes ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: displayColor.withOpacity(hasNoTimes ? 0.4 : 0.3), 
          width: hasNoTimes ? 1.5 : 1,
        ),
        boxShadow: hasNoTimes
            ? [
                BoxShadow(
                  color: warningColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasNoTimes ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
            size: 22,
            color: displayColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNoTimes)
                  Text(
                    'Add at least one reminder time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: displayColor,
                    ),
                  )
                else
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
              ],
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
    return _AppleCard(
      isDark: isDark,
      padding: EdgeInsets.zero, // Handle padding internally for collapse effect
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle
          InkWell(
            onTap: () {
              setState(() => _showAdditionalInfo = !_showAdditionalInfo);
              HapticHelper.selection();
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: Radius.circular(_showAdditionalInfo ? 0 : 20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Additional Details',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _showAdditionalInfo ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Collapsible Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showAdditionalInfo
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        
                        // Photo Section Header
                        _SectionLabel(label: 'Appearance', isDark: isDark),
                        const SizedBox(height: 12),
                        _buildPhotoSection(isDark),
                        
                        const SizedBox(height: 24),
                        _SectionLabel(label: 'Form & Color', isDark: isDark),
                        const SizedBox(height: 12),
                        // Dosage (Moved here)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _AppleTextField(
                                hint: 'Dosage e.g. 500 (Optional)',
                                controller: _dosageAmountController,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildAppleUnitPicker(isDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildColorSelector(isDark),
                        
                        const SizedBox(height: 24),
                        _SectionLabel(label: 'Inventory Management', isDark: isDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MinimalTextField(
                                label: 'Current Stock',
                                controller: _stockController,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MinimalTextField(
                                label: 'Low Stock Alert',
                                controller: _thresholdController,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                icon: Icons.notifications_active_outlined,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        _SectionLabel(label: 'Pharmacy Info', isDark: isDark),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          label: 'Pharmacy Name',
                          controller: _pharmacyNameController,
                          isDark: isDark,
                          icon: Icons.store_mall_directory_outlined,
                        ),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          label: 'Pharmacy Phone',
                          controller: _pharmacyPhoneController,
                          isDark: isDark,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_outlined,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(bool isDark) {
    return Row(
      children: [
        Hero(
          tag: widget.medicine?.id != null ? 'cabinet_icon_${widget.medicine!.id}' : 'new_medicine_hero',
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(20), // Matches Main Card
              border: Border.all(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
              ),
              image: _imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: _imagePath == null
                ? Icon(
                    Icons.medication_outlined,
                    size: 32,
                    color: isDark ? Colors.white24 : Colors.black26,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImageButton(
                label: 'Take Photo',
                icon: Icons.camera_alt_rounded,
                onPressed: () => _pickImage(ImageSource.camera),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _ImageButton(
                label: 'Choose from Gallery',
                icon: Icons.photo_library_rounded,
                onPressed: () => _pickImage(ImageSource.gallery),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildMedicineTypeSelector(bool isDark) {
    final types = [
      {'label': 'Tablet', 'value': 'tablet', 'image': 'assets/icons/medicine/3d/tablet.png'},
      {'label': 'Liquid', 'value': 'liquid', 'image': 'assets/icons/medicine/3d/liquid.png'},
      {'label': 'Injection', 'value': 'injection', 'image': 'assets/icons/medicine/3d/injection.png'},
      {'label': 'Drop', 'value': 'drop', 'image': 'assets/icons/medicine/3d/drop.png'},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedMedicineType == type['value'];
        final primaryColor = Color(_selectedColor);
        final bool isLast = type == types.last;
        final imagePath = type['image'] as String;
        
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMedicineType = type['value'] as String;
                _selectedIcon = _iconFromType(type['value'] as String);
              });
              HapticHelper.selection();
            },
            child: AnimatedScale(
              scale: isSelected ? 1.03 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : 6),
                height: 70,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.08))
                      : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 3D Icon (bigger)
                    Image.asset(
                      imagePath,
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medication_rounded,
                          color: isSelected ? primaryColor : Colors.grey,
                          size: 36,
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    // Label (smaller)
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected 
                            ? primaryColor 
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

  /// Just the save button without container decorations (for keyboard-aware layout)
  Widget _buildSaveButton(bool isEditing, bool isDark) {
    final isValid = _isFormValid();
    
    return GestureDetector(
      onTap: (_isSaving || !isValid) ? null : _saveMedicine,
      child: AnimatedScale(
        scale: _isSaving ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isValid
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7C3AED), // Vibrant purple
                      Color(0xFF6366F1), // Indigo
                    ],
                  )
                : null,
            color: isValid ? null : (isDark ? Colors.white12 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isValid
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                        Colors.white,
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
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Save Changes' : 'Add Medicine',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isValid
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.black38),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
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

    String dosageText = '';
    if (_dosageAmountController.text.trim().isNotEmpty) {
       dosageText = '${_dosageAmountController.text} $_dosageUnit';
    }

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
      // 1. Delete ALL existing schedules for this medicine (Cleaner than update)
      // This also ensures we don't have duplicate alarms or ghost notifications
      if (widget.medicine != null) {
        final existingSchedules = scheduleProvider.getSchedulesForMedicine(savedMedicine.id!);
        for (final s in existingSchedules) {
          if (s.id != null) await scheduleProvider.deleteSchedule(s.id!);
        }
      }

      // 2. Add New Schedules
      if (_frequencyType != FrequencyType.asNeeded && _reminderTimes.isNotEmpty) {
        final frequencyDays = _frequencyType == FrequencyType.specificDays
            ? (_selectedDays.toList()..sort())
            : null;

        // Support multiple times per day (create a schedule for each time)
        for (final time in _reminderTimes) {
             final schedule = Schedule(
              medicineId: savedMedicine.id!,
              timeOfDay: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              frequencyType: _frequencyType,
              frequencyDays: frequencyDays?.join(','),
              intervalDays: _frequencyType == FrequencyType.interval ? _intervalDays : null,
              startDate: _frequencyType == FrequencyType.interval
                  ? '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'
                  : null,
            );
            await scheduleProvider.addSchedule(schedule, savedMedicine);
        }
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
  final IconData? icon;

  const _MinimalTextField({
    required this.label,
    this.hint,
    required this.controller,
    required this.isDark,
    this.validator,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
    this.icon,
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
                prefixIcon: icon != null 
                    ? Icon(
                        icon, 
                        size: 20, 
                        color: isDark ? Colors.white38 : Colors.black38
                      ) 
                    : null,
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
          mainAxisAlignment: MainAxisAlignment.center,
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

// ═══════════════════════════════════════════════════════════════════════════
// APPLE-STYLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Frosted-glass style card container with subtle shadows
class _AppleCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets? padding;

  const _AppleCard({
    required this.child,
    required this.isDark,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.06) 
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.08) 
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Apple-style pill-shaped text field with subtle inner shadow
class _AppleTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isDark;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Function(String)? onChanged;

  const _AppleTextField({
    required this.hint,
    this.controller,
    this.focusNode,
    required this.isDark,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.08) 
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction ?? TextInputAction.next,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: icon != null 
              ? Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: icon != null ? 0 : 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Apple-style time pill with tap and optional remove functionality
class _AppleTimePill extends StatelessWidget {
  final TimeOfDay time;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AppleTimePill({
    required this.time,
    required this.isDark,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                : [Colors.white, const Color(0xFFF8F8F8)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.12) 
                : Colors.black.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              time.format(context),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.15) 
                        : Colors.black.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
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

/// Premium glassmorphism card with blur effect and gradient border
class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? accentColor;

  const _GlassCard({
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF6366F1);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
        ),
        border: Border.all(
          width: 1.5,
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: isDark 
              ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
              : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.3),
                      ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Visual time arc showing dose times throughout the day
class _TimeArcWidget extends StatelessWidget {
  final List<TimeOfDay> times;
  final bool isDark;

  const _TimeArcWidget({
    required this.times,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B).withOpacity(0.5),
                  const Color(0xFF0F172A).withOpacity(0.3),
                ]
              : [
                  const Color(0xFFFEF3C7).withOpacity(0.5),
                  const Color(0xFFE0E7FF).withOpacity(0.3),
                ],
        ),
      ),
      child: CustomPaint(
        painter: _TimeArcPainter(
          times: times,
          isDark: isDark,
        ),
        child: Stack(
          children: [
            // Time zone labels
            Positioned(
              left: 16,
              bottom: 12,
              child: _timeLabel('6AM', isDark),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(child: _timeLabel('12PM', isDark)),
            ),
            Positioned(
              right: 16,
              bottom: 12,
              child: _timeLabel('6PM', isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}

class _TimeArcPainter extends CustomPainter {
  final List<TimeOfDay> times;
  final bool isDark;

  _TimeArcPainter({required this.times, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 20);
    final radius = size.width * 0.42;
    
    // Draw arc background
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Morning gradient (6AM-12PM)
    final morningGradient = SweepGradient(
      startAngle: 3.14,
      endAngle: 3.14 + 0.5,
      colors: [
        const Color(0xFFFBBF24).withOpacity(0.6),
        const Color(0xFFF59E0B).withOpacity(0.6),
      ],
    );
    
    // Afternoon gradient (12PM-6PM)
    final afternoonGradient = SweepGradient(
      startAngle: 3.14 + 0.5,
      endAngle: 3.14 + 1,
      colors: [
        const Color(0xFF6366F1).withOpacity(0.6),
        const Color(0xFF8B5CF6).withOpacity(0.6),
      ],
    );

    // Draw base arc
    arcPaint.shader = LinearGradient(
      colors: [
        const Color(0xFFFBBF24).withOpacity(isDark ? 0.4 : 0.6),
        const Color(0xFF6366F1).withOpacity(isDark ? 0.4 : 0.6),
        const Color(0xFF8B5CF6).withOpacity(isDark ? 0.4 : 0.6),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14, // Start from left (6AM)
      3.14, // Draw half circle to right (6PM)
      false,
      arcPaint,
    );

    // Draw time markers
    for (final time in times) {
      final hour = time.hour + time.minute / 60.0;
      // Map 6AM-6PM (6-18) to 0-PI
      final normalizedHour = ((hour - 6) / 12).clamp(0.0, 1.0);
      final angle = 3.14 + (normalizedHour * 3.14);
      
      final markerX = center.dx + radius * cos(angle);
      final markerY = center.dy + radius * sin(angle);
      
      // Outer glow
      final glowPaint = Paint()
        ..color = const Color(0xFF6366F1).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(markerX, markerY), 10, glowPaint);
      
      // Inner marker
      final markerPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(markerX, markerY), 6, markerPaint);
      
      // White center
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(markerX, markerY), 3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


