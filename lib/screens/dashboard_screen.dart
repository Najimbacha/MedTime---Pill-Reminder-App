import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/log.dart';
import '../models/medicine.dart';
import '../models/schedule_entry.dart';
import '../providers/log_provider.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/haptic_helper.dart';
import '../core/components/timeline_item.dart';
import 'add_edit_medicine_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final Set<String> _justCompleted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<MedicineProvider>().loadMedicines(),
      context.read<ScheduleProvider>().loadSchedules(),
      context.read<LogProvider>().loadLogs(),
    ]);
  }

  Future<void> _openRoutine({Medicine? routine}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(medicine: routine),
      ),
    );
    _loadData();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    _loadData();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _complete(ScheduleEntry entry) async {
    final logProvider = context.read<LogProvider>();
    final id = _entryKey(entry);
    setState(() => _justCompleted.add(id));
    await HapticHelper.success();
    await logProvider.markAsTaken(
      entry.medicine.id!,
      entry.scheduledDateTime,
      medicine: entry.medicine,
    );
    await Future.delayed(const Duration(milliseconds: 260));
    await _loadData();
    if (mounted) setState(() => _justCompleted.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today'),
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: _openHistory,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer3<MedicineProvider, ScheduleProvider, LogProvider>(
          builder: (context, routineProvider, scheduleProvider, logProvider, _) {
            final entries = _entriesForToday(
              routineProvider,
              scheduleProvider,
              logProvider,
            );

            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No routines yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a simple recurring reminder for something you do every day.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openRoutine(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Routine'),
                  ),
                ],
              );
            }

            final pending = entries
                .where((e) => e.medicineStatus != MedicineStatus.take)
                .toList();
            final completed = entries
                .where((e) => e.medicineStatus == MedicineStatus.take)
                .toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                ..._section('Morning', pending, 0, 12),
                ..._section('Afternoon', pending, 12, 18),
                ..._section('Tonight', pending, 18, 24),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Completed', count: completed.length),
                  const SizedBox(height: 10),
                  for (final entry in completed)
                    _RoutineTile(
                      entry: entry,
                      completed: true,
                      fading: false,
                      onDone: null,
                      onTap: () => _openRoutine(routine: entry.medicine),
                    ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRoutine(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  List<Widget> _section(
    String title,
    List<ScheduleEntry> entries,
    int startHour,
    int endHour,
  ) {
    final sectionEntries = entries
        .where(
          (e) =>
              e.scheduledDateTime.hour >= startHour &&
              e.scheduledDateTime.hour < endHour,
        )
        .toList();
    if (sectionEntries.isEmpty) return const [];

    return [
      if (title != 'Morning') const SizedBox(height: 28),
      _SectionHeader(title: title, count: sectionEntries.length),
      const SizedBox(height: 10),
      for (final entry in sectionEntries)
        _RoutineTile(
          entry: entry,
          completed: false,
          fading: _justCompleted.contains(_entryKey(entry)),
          onDone: () => _complete(entry),
          onTap: () => _openRoutine(routine: entry.medicine),
        ),
    ];
  }

  List<ScheduleEntry> _entriesForToday(
    MedicineProvider routineProvider,
    ScheduleProvider scheduleProvider,
    LogProvider logProvider,
  ) {
    final now = DateTime.now();
    final schedules = scheduleProvider.getSchedulesForDate(now);
    final entries = <ScheduleEntry>[];

    for (final schedule in schedules) {
      final routine = routineProvider.getMedicineById(schedule.medicineId);
      if (routine == null) continue;

      final parts = schedule.timeOfDay.split(':');
      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final log = logProvider.getLatestLogForSlot(
        routine.id!,
        scheduledDateTime,
      );

      final completed = log?.status == LogStatus.take;
      entries.add(
        ScheduleEntry(
          schedule: schedule,
          medicine: routine,
          scheduledDateTime: scheduledDateTime,
          log: log,
          timelineStatus: completed
              ? TimelineStatus.completed
              : TimelineStatus.pending,
          medicineStatus: completed
              ? MedicineStatus.take
              : MedicineStatus.pending,
        ),
      );
    }

    entries.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return entries;
  }

  String _entryKey(ScheduleEntry entry) =>
      '${entry.medicine.id}-${entry.scheduledDateTime.toIso8601String()}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final ScheduleEntry entry;
  final bool completed;
  final bool fading;
  final VoidCallback? onDone;
  final VoidCallback onTap;

  const _RoutineTile({
    required this.entry,
    required this.completed,
    required this.fading,
    required this.onDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routine = entry.medicine;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: fading ? 0.2 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: routine.colorValue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(routine.icon, color: routine.colorValue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat.jm().format(entry.scheduledDateTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (completed)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  )
                else
                  FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(76, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
