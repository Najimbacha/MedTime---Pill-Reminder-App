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
    _RoutineIconOption(1, Icons.water_drop_rounded, 0xFF0EA5E9, 'Water'),
    _RoutineIconOption(2, Icons.menu_book_rounded, 0xFF4F46E5, 'Read'),
    _RoutineIconOption(3, Icons.directions_walk_rounded, 0xFF16A34A, 'Walk'),
    _RoutineIconOption(4, Icons.spa_rounded, 0xFFDB2777, 'Care'),
    _RoutineIconOption(5, Icons.bedtime_rounded, 0xFF7C3AED, 'Sleep'),
    _RoutineIconOption(6, Icons.home_rounded, 0xFFF97316, 'Home'),
    _RoutineIconOption(7, Icons.fitness_center_rounded, 0xFFDC2626, 'Move'),
    _RoutineIconOption(8, Icons.self_improvement_rounded, 0xFF0891B2, 'Calm'),
  ];

  static const _repeatOptions = [
    _RepeatOption('daily', 'Every day', Icons.event_repeat_rounded),
    _RepeatOption('weekdays', 'Weekdays', Icons.work_history_rounded),
    _RepeatOption('weekends', 'Weekends', Icons.weekend_rounded),
    _RepeatOption(
      'specific',
      'Specific days',
      Icons.calendar_view_week_rounded,
    ),
    _RepeatOption('interval', 'Every X days', Icons.timelapse_rounded),
    _RepeatOption('once', 'Once', Icons.event_available_rounded),
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

  Color get _accent => Color(_selectedColor);

  _RoutineIconOption get _selectedOption => _iconOptions.firstWhere(
    (option) => option.value == _selectedIcon,
    orElse: () => _iconOptions[1],
  );

  String get _repeatLabel {
    if (_repeat == 'specific') {
      if (_selectedDays.isEmpty) return 'Choose days';
      return (_selectedDays.toList()..sort()).map(_shortDayName).join(', ');
    }
    if (_repeat == 'interval') {
      final days = int.tryParse(_intervalController.text) ?? 7;
      return 'Every $days ${days == 1 ? 'day' : 'days'}';
    }
    return _repeatOptions.firstWhere((option) => option.value == _repeat).label;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _time = picked);
    HapticHelper.selection();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
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
    final colorScheme = theme.colorScheme;
    final isEditing = widget.medicine != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit routine' : 'New routine'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete routine',
              onPressed: _deleteRoutine,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
              sliver: SliverList.list(
                children: [
                  _RoutinePreview(
                    accent: _accent,
                    icon: _selectedOption.icon,
                    name: _nameController.text.trim().isEmpty
                        ? 'Read 20 minutes'
                        : _nameController.text.trim(),
                    time: _time.format(context),
                    repeat: _repeatLabel,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                  const SizedBox(height: 18),
                  _TimePanel(
                    accent: _accent,
                    time: _time.format(context),
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(
                    icon: Icons.repeat_rounded,
                    text: 'Repeat',
                    color: _accent,
                  ),
                  const SizedBox(height: 12),
                  _RepeatSelector(
                    repeat: _repeat,
                    options: _repeatOptions,
                    onChanged: (value) {
                      setState(() => _repeat = value);
                      HapticHelper.selection();
                    },
                  ),
                  if (_repeat == 'specific') ...[
                    const SizedBox(height: 14),
                    _DaySelector(
                      selectedDays: _selectedDays,
                      accent: _accent,
                      onDayToggled: (day) {
                        setState(() {
                          if (_selectedDays.contains(day)) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                        HapticHelper.selection();
                      },
                    ),
                  ],
                  if (_repeat == 'interval') ...[
                    const SizedBox(height: 14),
                    _IntervalPanel(
                      controller: _intervalController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_repeat == 'interval' || _repeat == 'once') ...[
                    const SizedBox(height: 14),
                    _DatePanel(
                      date: _formatDate(_startDate),
                      label: _repeat == 'once' ? 'Date' : 'Start date',
                      onTap: _pickStartDate,
                    ),
                  ],
                  const SizedBox(height: 26),
                  _SectionLabel(
                    icon: Icons.interests_rounded,
                    text: 'Icon',
                    color: _accent,
                  ),
                  const SizedBox(height: 12),
                  _IconGrid(
                    options: _iconOptions,
                    selectedValue: _selectedIcon,
                    onSelected: (option) {
                      setState(() {
                        _selectedIcon = option.value;
                        _selectedColor = option.colorValue;
                      });
                      HapticHelper.selection();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActionBar(
        isSaving: _isSaving,
        isEnabled: _isValid,
        onSave: _saveRoutine,
      ),
    );
  }

  static String _shortDayName(int day) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[day - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _RoutinePreview extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String name;
  final String time;
  final String repeat;

  const _RoutinePreview({
    required this.accent,
    required this.icon,
    required this.name,
    required this.time,
    required this.repeat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 31),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniPill(icon: Icons.schedule_rounded, label: time),
                    _MiniPill(icon: Icons.repeat_rounded, label: repeat),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePanel extends StatelessWidget {
  final Color accent;
  final String time;
  final VoidCallback onTap;

  const _TimePanel({
    required this.accent,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.48,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded, color: accent, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RepeatSelector extends StatelessWidget {
  final String repeat;
  final List<_RepeatOption> options;
  final ValueChanged<String> onChanged;

  const _RepeatSelector({
    required this.repeat,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          Builder(
            builder: (context) {
              final selected = repeat == option.value;
              return ChoiceChip(
                selected: selected,
                avatar: Icon(
                  option.icon,
                  size: 18,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.primary,
                ),
                label: Text(option.label),
                onSelected: (_) => onChanged(option.value),
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: colorScheme.surfaceContainerLow,
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              );
            },
          ),
      ],
    );
  }
}

class _DaySelector extends StatelessWidget {
  final Set<int> selectedDays;
  final Color accent;
  final ValueChanged<int> onDayToggled;

  const _DaySelector({
    required this.selectedDays,
    required this.accent,
    required this.onDayToggled,
  });

  @override
  Widget build(BuildContext context) {
    const days = [
      _DayOption(1, 'M'),
      _DayOption(2, 'T'),
      _DayOption(3, 'W'),
      _DayOption(4, 'T'),
      _DayOption(5, 'F'),
      _DayOption(6, 'S'),
      _DayOption(7, 'S'),
    ];

    return Row(
      children: [
        for (final day in days) ...[
          Expanded(
            child: Tooltip(
              message: _weekdayName(day.value),
              child: InkWell(
                onTap: () => onDayToggled(day.value),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedDays.contains(day.value)
                        ? accent
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    day.label,
                    style: TextStyle(
                      color: selectedDays.contains(day.value)
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (day.value != 7) const SizedBox(width: 7),
        ],
      ],
    );
  }

  static String _weekdayName(int value) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[value - 1];
  }
}

class _IntervalPanel extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _IntervalPanel({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            'Every',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: (_) {
                final days = int.tryParse(controller.text);
                if (days == null || days < 1 || days > 365) return '1-365';
                return null;
              },
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'days',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePanel extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;

  const _DatePanel({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      tileColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      leading: const Icon(Icons.event_rounded),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  final List<_RoutineIconOption> options;
  final int selectedValue;
  final ValueChanged<_RoutineIconOption> onSelected;

  const _IconGrid({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final selected = option.value == selectedValue;
        final color = Color(option.colorValue);
        return Tooltip(
          message: option.label,
          child: InkWell(
            onTap: () => onSelected(option),
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? color
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(option.icon, color: color, size: 28),
                  const SizedBox(height: 7),
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool isSaving;
  final bool isEnabled;
  final VoidCallback onSave;

  const _BottomActionBar({
    required this.isSaving,
    required this.isEnabled,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: FilledButton.icon(
        onPressed: isSaving || !isEnabled ? null : onSave,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_rounded),
        label: Text(isSaving ? 'Saving' : 'Save routine'),
      ),
    );
  }
}

class _RoutineIconOption {
  final int value;
  final IconData icon;
  final int colorValue;
  final String label;

  const _RoutineIconOption(this.value, this.icon, this.colorValue, this.label);
}

class _RepeatOption {
  final String value;
  final String label;
  final IconData icon;

  const _RepeatOption(this.value, this.label, this.icon);
}

class _DayOption {
  final int value;
  final String label;

  const _DayOption(this.value, this.label);
}
