import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/log.dart';
import '../providers/log_provider.dart';
import '../providers/routine_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogProvider>().loadLogs();
      context.read<RoutineProvider>().loadRoutines();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logs = context.watch<LogProvider>().getLogsForDate(_selectedDay);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('History')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: TableCalendar<Log>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              eventLoader: (day) => context
                  .read<LogProvider>()
                  .getLogsForDate(day)
                  .where((log) => log.status == LogStatus.take)
                  .toList(),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                markerDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
                weekendTextStyle: TextStyle(color: colorScheme.onSurface),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
                weekendStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left_rounded),
                rightChevronIcon: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CountPill(count: logs.length),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 44,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No routines completed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final log in logs) _HistoryTile(log: log),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count done',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Log log;

  const _HistoryTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routine = context.watch<RoutineProvider>().getRoutineById(
      log.routineId,
    );
    if (routine == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: routine.colorValue.withValues(alpha: 0.12),
          foregroundColor: routine.colorValue,
          child: Icon(routine.icon),
        ),
        title: Text(
          routine.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(DateFormat.jm().format(log.scheduledTime)),
        trailing: Icon(
          log.status == LogStatus.take
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: log.status == LogStatus.take
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
