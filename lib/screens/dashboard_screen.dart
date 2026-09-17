import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/log.dart';
import '../models/routine.dart';
import '../models/schedule_entry.dart';
import '../providers/log_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/haptic_helper.dart';
import '../core/components/timeline_item.dart';
import 'add_edit_routine_screen.dart';
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
      context.read<RoutineProvider>().loadRoutines(),
      context.read<ScheduleProvider>().loadSchedules(),
      context.read<LogProvider>().loadLogs(),
    ]);
  }

  Future<void> _openRoutine({Routine? routine}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditRoutineScreen(routine: routine),
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
      entry.routine.id!,
      entry.scheduledDateTime,
    );
    await Future.delayed(const Duration(milliseconds: 260));
    await _loadData();
    if (mounted) setState(() => _justCompleted.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
        child: Consumer3<RoutineProvider, ScheduleProvider, LogProvider>(
          builder: (context, routineProvider, scheduleProvider, logProvider, _) {
            final entries = _entriesForToday(
              routineProvider,
              scheduleProvider,
              logProvider,
            );

            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 120),
                children: [
                  Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'No routines yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a simple recurring reminder for something you do every day.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
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
                .where((e) => e.routineStatus != RoutineStatus.take)
                .toList();
            final completed = entries
                .where((e) => e.routineStatus == RoutineStatus.take)
                .toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _TodaySummary(
                  total: entries.length,
                  completed: completed.length,
                ),
                const SizedBox(height: 24),
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
                      onTap: () => _openRoutine(routine: entry.routine),
                    ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add routine',
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
          onTap: () => _openRoutine(routine: entry.routine),
        ),
    ];
  }

  List<ScheduleEntry> _entriesForToday(
    RoutineProvider routineProvider,
    ScheduleProvider scheduleProvider,
    LogProvider logProvider,
  ) {
    final now = DateTime.now();
    final schedules = scheduleProvider.getSchedulesForDate(now);
    final entries = <ScheduleEntry>[];

    for (final schedule in schedules) {
      final routine = routineProvider.getRoutineById(schedule.routineId);
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
          routine: routine,
          scheduledDateTime: scheduledDateTime,
          log: log,
          timelineStatus: completed
              ? TimelineStatus.completed
              : TimelineStatus.pending,
          routineStatus: completed
              ? RoutineStatus.take
              : RoutineStatus.pending,
        ),
      );
    }

    entries.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return entries;
  }

  String _entryKey(ScheduleEntry entry) =>
      '${entry.routine.id}-${entry.scheduledDateTime.toIso8601String()}';
}

class _TodaySummary extends StatelessWidget {
  final int total;
  final int completed;

  const _TodaySummary({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = total - completed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              remaining == 0
                  ? Icons.check_circle_rounded
                  : Icons.timelapse_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == 0 ? 'All done today' : '$remaining remaining',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of $total completed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
            fontWeight: FontWeight.w800,
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
    final routine = entry.routine;

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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: routine.colorValue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
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
                      minimumSize: const Size(78, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
