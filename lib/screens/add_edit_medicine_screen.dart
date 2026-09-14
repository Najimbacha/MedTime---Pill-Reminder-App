import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../models/schedule.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../utils/haptic_helper.dart';
import 'notification_troubleshoot_screen.dart';
import 'paywall_screen.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicine;

  const AddEditMedicineScreen({super.key, this.medicine});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _intervalController;

  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  String _repeat = 'daily';
  Set<int> _selectedDays = {1, 2, 3, 4, 5};
  DateTime _startDate = DateTime.now();
  int _selectedIcon = 2;
  int _selectedColor = 0xFF4F46E5;
  bool _isSaving = false;

  static const _iconOptions = [
    _RoutineIconOption(1, Icons.water_drop_rounded, 0xFF0EA5E9),
    _RoutineIconOption(2, Icons.menu_book_rounded, 0xFF4F46E5),
    _RoutineIconOption(3, Icons.directions_walk_rounded, 0xFF16A34A),
    _RoutineIconOption(4, Icons.spa_rounded, 0xFFDB2777),
    _RoutineIconOption(5, Icons.bedtime_rounded, 0xFF7C3AED),
    _RoutineIconOption(6, Icons.home_rounded, 0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine?.name ?? '');
    _intervalController = TextEditingController(text: '7');

    final routine = widget.medicine;
    if (routine != null) {
      _selectedIcon = routine.typeIcon;
      _selectedColor = routine.color;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final schedules = context
            .read<ScheduleProvider>()
            .getSchedulesForMedicine(routine.id!);
        if (schedules.isEmpty || !mounted) return;

        final schedule = schedules.first;
        final parts = schedule.timeOfDay.split(':');
        setState(() {
          _time = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
          _startDate = schedule.startDate != null
              ? DateTime.parse(schedule.startDate!)
              : DateTime.now();
          _intervalController.text = '${schedule.intervalDays ?? 7}';
          _repeat = _repeatFromSchedule(schedule);
          if (schedule.frequencyType == FrequencyType.specificDays) {
            _selectedDays = schedule.daysList.toSet();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_repeat == 'specific' && _selectedDays.isEmpty) return false;
    if (_repeat == 'interval') {
      final days = int.tryParse(_intervalController.text);
      return days != null && days > 0 && days <= 365;
    }
    return true;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
    HapticHelper.selection();
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate() || !_isValid) return;

    setState(() => _isSaving = true);

    final readiness = await NotificationService.instance
        .checkSchedulingReadiness();
    if (!readiness.canSchedule && !Platform.isWindows) {
      if (mounted) {
        setState(() => _isSaving = false);
        await _showSchedulingBlockedDialog(readiness);
      }
      return;
    }

    final routine = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text.trim(),
      dosage: '',
      typeIcon: _selectedIcon,
      currentStock: 0,
      lowStockThreshold: 0,
      color: _selectedColor,
    );

    if (!mounted) return;
    final routineProvider = context.read<MedicineProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    Medicine? savedRoutine;
    try {
      if (widget.medicine == null) {
        savedRoutine = await routineProvider.addMedicine(routine);
      } else {
        await routineProvider.updateMedicine(routine);
        savedRoutine = routine;
      }
    } on PremiumLimitException catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save routine: $e')));
      }
      return;
    }

    if (savedRoutine?.id == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    await scheduleProvider.replaceSchedulesForMedicine(savedRoutine!.id!, [
      _buildSchedule(savedRoutine.id!),
    ], savedRoutine);

    if (!mounted) return;
    final navigator = Navigator.of(context);
    await HapticHelper.success();
    setState(() => _isSaving = false);
    navigator.pop();
  }

  Schedule _buildSchedule(int routineId) {
    final timeOfDay =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final startDate =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';

    switch (_repeat) {
      case 'weekdays':
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '1,2,3,4,5',
        );
      case 'weekends':
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.specificDays,
          frequencyDays: '6,7',
        );
      case 'specific':
        final days = (_selectedDays.toList()..sort()).join(',');
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.specificDays,
          frequencyDays: days,
        );
      case 'interval':
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.interval,
          intervalDays: int.parse(_intervalController.text),
          startDate: startDate,
        );
      case 'once':
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.once,
          startDate: startDate,
          endDate: startDate,
        );
      case 'daily':
      default:
        return Schedule(
          medicineId: routineId,
          timeOfDay: timeOfDay,
          frequencyType: FrequencyType.daily,
        );
    }
  }

  String _repeatFromSchedule(Schedule schedule) {
    if (schedule.frequencyType == FrequencyType.daily) return 'daily';
    if (schedule.frequencyType == FrequencyType.interval) return 'interval';
    if (schedule.frequencyType == FrequencyType.once) return 'once';
    if (schedule.frequencyType == FrequencyType.specificDays) {
      final days = schedule.daysList.toSet();
      if (_setsEqual(days, {1, 2, 3, 4, 5})) return 'weekdays';
      if (_setsEqual(days, {6, 7})) return 'weekends';
      return 'specific';
    }
    return 'daily';
  }

  bool _setsEqual(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _showSchedulingBlockedDialog(
    NotificationSchedulingReadiness readiness,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications need attention'),
        content: Text(readiness.reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationTroubleshootScreen(),
                ),
              );
            },
            child: const Text('Help'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoutine() async {
    final routine = widget.medicine;
    if (routine?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          '${routine!.name} will be removed from Today and History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<MedicineProvider>().deleteMedicineWithSnapshot(
      routine!.id!,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.medicine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Routine' : 'Add Routine'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteRoutine,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Routine name',
                hintText: 'Read 20 minutes',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Name required'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _FieldTile(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: _time.format(context),
              onTap: _pickTime,
            ),
            const SizedBox(height: 16),
            _RepeatCard(
              repeat: _repeat,
              selectedDays: _selectedDays,
              intervalController: _intervalController,
              onRepeatChanged: (value) => setState(() => _repeat = value),
              onDayToggled: (day) {
                setState(() {
                  if (_selectedDays.contains(day)) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              onIntervalChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              'Icon',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in _iconOptions)
                  _IconChoice(
                    option: option,
                    selected: _selectedIcon == option.value,
                    onTap: () {
                      setState(() {
                        _selectedIcon = option.value;
                        _selectedColor = option.colorValue;
                      });
                      HapticHelper.selection();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton(
          onPressed: _isSaving || !_isValid ? null : _saveRoutine,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _RepeatCard extends StatelessWidget {
  final String repeat;
  final Set<int> selectedDays;
  final TextEditingController intervalController;
  final ValueChanged<String> onRepeatChanged;
  final ValueChanged<int> onDayToggled;
  final ValueChanged<String> onIntervalChanged;

  const _RepeatCard({
    required this.repeat,
    required this.selectedDays,
    required this.intervalController,
    required this.onRepeatChanged,
    required this.onDayToggled,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Repeat',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: repeat,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Every day')),
                  DropdownMenuItem(value: 'weekdays', child: Text('Weekdays')),
                  DropdownMenuItem(value: 'weekends', child: Text('Weekends')),
                  DropdownMenuItem(
                    value: 'specific',
                    child: Text('Specific days'),
                  ),
                  DropdownMenuItem(
                    value: 'interval',
                    child: Text('Every X days'),
                  ),
                  DropdownMenuItem(value: 'once', child: Text('Once')),
                ],
                onChanged: (value) {
                  if (value != null) onRepeatChanged(value);
                },
              ),
            ],
          ),
          if (repeat == 'specific') ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final day in const [
                  _DayOption(1, 'M'),
                  _DayOption(2, 'T'),
                  _DayOption(3, 'W'),
                  _DayOption(4, 'T'),
                  _DayOption(5, 'F'),
                  _DayOption(6, 'S'),
                  _DayOption(7, 'S'),
                ])
                  FilterChip(
                    selected: selectedDays.contains(day.value),
                    label: Text(day.label),
                    onSelected: (_) => onDayToggled(day.value),
                  ),
              ],
            ),
          ],
          if (repeat == 'interval') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Every', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 10),
                SizedBox(
                  width: 82,
                  child: TextFormField(
                    controller: intervalController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (_) {
                      if (repeat != 'interval') return null;
                      final days = int.tryParse(intervalController.text);
                      if (days == null || days < 1 || days > 365) {
                        return '1-365';
                      }
                      return null;
                    },
                    onChanged: onIntervalChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Text('days', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final _RoutineIconOption option;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(option.colorValue);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(option.icon, color: color),
      ),
    );
  }
}

class _RoutineIconOption {
  final int value;
  final IconData icon;
  final int colorValue;

  const _RoutineIconOption(this.value, this.icon, this.colorValue);
}

class _DayOption {
  final int value;
  final String label;

  const _DayOption(this.value, this.label);
}
