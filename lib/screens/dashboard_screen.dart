import 'dart:math' as math;
import 'dart:ui';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/log.dart';
import '../models/schedule.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import '../core/components/progress_ring.dart';
import '../core/components/section_header.dart';
import '../core/components/timeline_item.dart';
import '../core/components/medicine_card.dart';
import '../core/components/empty_state.dart';
import '../core/components/app_button.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';
import 'add_edit_medicine_screen.dart';
import 'settings_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ConfettiController _confettiController;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final medicineProvider = context.read<MedicineProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final logProvider = context.read<LogProvider>();

    await Future.wait([
      medicineProvider.loadMedicines(),
      scheduleProvider.loadSchedules(),
      logProvider.loadLogs(),
    ]);

    if (!mounted) return;
    await scheduleProvider.rescheduleAllNotifications(
      medicineProvider.medicines,
    );
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  void _triggerSuccessAnimation() {
    if (!mounted) return;
    setState(() => _showSuccessAnimation = true);
    _confettiController.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSuccessAnimation = false);
      }
    });
  }

  void _navigateToAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditMedicineScreen()),
    ).then((_) => _loadData());
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: isDark ? Colors.white : Colors.black,
            child: SafeArea(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(isDark),
                  Consumer3<MedicineProvider, ScheduleProvider, LogProvider>(
                    builder:
                        (
                          context,
                          medicineProvider,
                          scheduleProvider,
                          logProvider,
                          _,
                        ) {
                          if (medicineProvider.isLoading ||
                              scheduleProvider.isLoading ||
                              logProvider.isLoading) {
                            return SliverFillRemaining(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            );
                          }

                          final entries = _buildScheduleEntries(
                            scheduleProvider.todaySchedules,
                            logProvider.todayLogs,
                            medicineProvider,
                          );
                          final completedCount = logProvider.todayLogs
                              .where((log) => log.status == LogStatus.take)
                              .length;
                          final totalCount = entries.length;
                          final pendingEntries = entries
                              .where(
                                (entry) =>
                                    entry.timelineStatus !=
                                    TimelineStatus.completed,
                              )
                              .toList();
                          final completedEntries = entries
                              .where(
                                (entry) =>
                                    entry.timelineStatus ==
                                    TimelineStatus.completed,
                              )
                              .toList();

                          if (entries.isEmpty) {
                            return SliverFillRemaining(
                              child: _buildEmptyState(),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                const SizedBox(height: 8),
                                _StatsCard(
                                  completed: completedCount,
                                  total: totalCount,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 32),
                                _SectionTitle(
                                  title: 'Upcoming',
                                  count: pendingEntries.length,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                ...pendingEntries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _MinimalMedicineCard(
                                      entry: entry,
                                      isDark: isDark,
                                      onTake: () => _handleTake(
                                        entry,
                                        medicineProvider,
                                        logProvider,
                                      ),
                                      onSkip: () =>
                                          _handleSkip(entry, logProvider),
                                    ),
                                  ),
                                ),
                                if (completedEntries.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _SectionTitle(
                                    title: 'Completed',
                                    count: completedEntries.length,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ...completedEntries.map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _MinimalMedicineCard(
                                        entry: entry,
                                        isDark: isDark,
                                        onTake: () => _handleTake(
                                          entry,
                                          medicineProvider,
                                          logProvider,
                                        ),
                                        onSkip: () =>
                                            _handleSkip(entry, logProvider),
                                      ),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
          ),
          if (_showSuccessAnimation)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Lottie.network(
                      'https://assets9.lottiefiles.com/packages/lf20_kq5r8acy.json',
                      width: 260,
                      height: 260,
                      repeat: false,
                      frameRate: FrameRate.max,
                      errorBuilder: (_, error, __) => Container(
                        width: 160,
                        height: 160,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 3),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 84,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _MinimalFAB(
        onTap: _navigateToAddMedicine,
        isDark: isDark,
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE').format(DateTime.now()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            Text(
              DateFormat('MMMM d').format(DateTime.now()),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.medication_outlined,
      title: 'No medications scheduled',
      message: 'Add your first medicine to get started with tracking',
      action: AppButton(
        text: 'Add Medicine',
        icon: Icons.add,
        onPressed: _navigateToAddMedicine,
      ),
    );
  }

  Future<void> _handleTake(
    _ScheduleEntry entry,
    MedicineProvider medicineProvider,
    LogProvider logProvider,
  ) async {
    final scheduledTime = entry.scheduledDateTime;
    await HapticHelper.success();
    await SoundHelper.playSuccess();
    await logProvider.markAsTaken(entry.medicine.id!, scheduledTime);
    await medicineProvider.decrementStock(entry.medicine.id!);
    await _loadData();
    if (mounted) {
      setState(() {});
      _triggerSuccessAnimation();
      _showFeedback('✓ ${entry.medicine.name} marked as taken');
    }
  }

  Future<void> _handleSkip(
    _ScheduleEntry entry,
    LogProvider logProvider,
  ) async {
    final scheduledTime = entry.scheduledDateTime;
    await HapticHelper.warning();
    await SoundHelper.playAlert();
    await logProvider.markAsSkipped(entry.medicine.id!, scheduledTime);
    await _loadData();
    if (mounted) {
      setState(() {});
      _showFeedback('Skipped ${entry.medicine.name}');
    }
  }

  List<_ScheduleEntry> _buildScheduleEntries(
    List<Schedule> schedules,
    List<Log> logs,
    MedicineProvider medicineProvider,
  ) {
    final sorted = [...schedules]
      ..sort(
        (a, b) => _getScheduledDateTime(a).compareTo(_getScheduledDateTime(b)),
      );
    final entries = <_ScheduleEntry>[];
    for (final schedule in sorted) {
      final medicine = medicineProvider.getMedicineById(schedule.medicineId);
      if (medicine == null) continue;
      final scheduledDateTime = _getScheduledDateTime(schedule);
      final log = _findLogForSchedule(logs, medicine, scheduledDateTime);
      entries.add(
        _ScheduleEntry(
          schedule: schedule,
          medicine: medicine,
          scheduledDateTime: scheduledDateTime,
          log: log,
          timelineStatus: _getTimelineStatus(log, scheduledDateTime),
          medicineStatus: _getMedicineStatus(log, scheduledDateTime),
        ),
      );
    }
    return entries;
  }

  Log? _findLogForSchedule(
    List<Log> logs,
    Medicine medicine,
    DateTime scheduledDateTime,
  ) {
    final medicineId = medicine.id;
    if (medicineId == null) return null;
    return logs.firstWhereOrNull((log) {
      return log.medicineId == medicineId &&
          log.scheduledTime.hour == scheduledDateTime.hour &&
          log.scheduledTime.minute == scheduledDateTime.minute &&
          log.scheduledTime.day == scheduledDateTime.day;
    });
  }

  DateTime _getScheduledDateTime(Schedule schedule) {
    final parts = schedule.timeOfDay.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  TimelineStatus _getTimelineStatus(Log? log, DateTime scheduledDateTime) {
    if (log != null && log.status == LogStatus.take)
      return TimelineStatus.completed;
    final now = DateTime.now();
    if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 30)))) {
      return TimelineStatus.overdue;
    }
    return TimelineStatus.pending;
  }

  MedicineStatus _getMedicineStatus(Log? log, DateTime scheduledDateTime) {
    if (log != null) {
      if (log.status == LogStatus.take) return MedicineStatus.completed;
      if (log.status == LogStatus.skip) return MedicineStatus.skipped;
    }
    final now = DateTime.now();
    if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 30)))) {
      return MedicineStatus.overdue;
    }
    return MedicineStatus.pending;
  }
}

class _StatsCard extends StatelessWidget {
  final int completed;
  final int total;
  final bool isDark;

  const _StatsCard({
    required this.completed,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    final clampedRatio = min(ratio, 1.0);
    final percentage = (clampedRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: clampedRatio,
                    strokeWidth: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE5E5E5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${min(completed, total)} of $total taken',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

class _MinimalMedicineCard extends StatelessWidget {
  final _ScheduleEntry entry;
  final bool isDark;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  const _MinimalMedicineCard({
    required this.entry,
    required this.isDark,
    required this.onTake,
    required this.onSkip,
  });

  bool get isCompleted => entry.medicineStatus == MedicineStatus.completed;
  bool get isOverdue => entry.medicineStatus == MedicineStatus.overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : entry.medicine.colorValue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      )
                    : Image.asset(
                        entry.medicine.iconAssetPath,
                        width: 36,
                        height: 36,
                        fit: BoxFit.fitHeight,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.medicine.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          DateFormat.jm().format(entry.scheduledDateTime),
                          style: TextStyle(
                            fontSize: 13,
                            color: isOverdue
                                ? Colors.red
                                : isDark
                                ? Colors.white60
                                : Colors.black54,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (entry.medicine.dosage.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.medicine.dosage,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Take',
                    icon: Icons.check,
                    onPressed: onTake,
                    isPrimary: true,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Skip',
                    icon: Icons.close,
                    onPressed: onSkip,
                    isPrimary: false,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDark;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isPrimary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalFAB extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _MinimalFAB({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          size: 28,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _ScheduleEntry {
  final Schedule schedule;
  final Medicine medicine;
  final DateTime scheduledDateTime;
  final Log? log;
  final TimelineStatus timelineStatus;
  final MedicineStatus medicineStatus;

  _ScheduleEntry({
    required this.schedule,
    required this.medicine,
    required this.scheduledDateTime,
    required this.log,
    required this.timelineStatus,
    required this.medicineStatus,
  });
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
