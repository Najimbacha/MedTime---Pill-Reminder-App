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
import '../providers/auth_provider.dart';
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
import '../services/streak_service.dart';
import 'achievements_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ConfettiController _confettiController;
  bool _showSuccessAnimation = false;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    );
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
    _confettiController.dispose();
    _progressAnimationController.dispose();
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
    // Update streak data
    final streak = StreakService.instance.currentStreak;
    if (mounted) setState(() => _streak = streak);
    
    _progressAnimationController.forward(from: 0);
  }

  Future<void> _refresh() async => await _loadData();

  void _triggerSuccessAnimation() {
    if (!mounted) return;
    setState(() => _showSuccessAnimation = true);
    _confettiController.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSuccessAnimation = false);
    });
  }

  void _navigateToAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditMedicineScreen()),
    ).then((_) => _loadData());
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _TopBanner(
        message: message,
        isError: isError,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(
      const Duration(milliseconds: 1500),
      () => overlayEntry.remove(),
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
                          final validEntries = entries
                              .where(
                                (entry) => _isValidMedicine(entry.medicine),
                              )
                              .toList();
                          final pendingEntries = validEntries
                              .where(
                                (entry) =>
                                    entry.timelineStatus !=
                                    TimelineStatus.completed,
                              )
                              .toList();
                          final completedEntries = validEntries
                              .where(
                                (entry) =>
                                    entry.timelineStatus ==
                                    TimelineStatus.completed,
                              )
                              .toList();
                          final totalCount = validEntries.length;
                          final completedCount = completedEntries.length;
                          if (validEntries.isEmpty) {
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              sliver: SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 60,
                                    ),
                                    child: _buildEmptyState(),
                                  ),
                                ),
                              ),
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
                                  nextSchedule: pendingEntries.isNotEmpty
                                      ? pendingEntries.first.scheduledDateTime
                                      : null,
                                  animation: _progressAnimation,
                                  streak: _streak,
                                ),
                                const SizedBox(height: 32),
                                if (pendingEntries.isNotEmpty) ...[
                                  _SectionTitle(
                                    title: 'Upcoming',
                                    count: pendingEntries.length,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ...pendingEntries.map(
                                    (entry) => _AnimatedEntryCard(
                                      key: ValueKey(
                                        '${entry.medicine.id}_${entry.scheduledDateTime}',
                                      ),
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
                                ],
                                if (pendingEntries.isEmpty &&
                                    completedEntries.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _NothingElseToday(isDark: isDark),
                                  const SizedBox(height: 24),
                                ],
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

  bool _isValidMedicine(Medicine medicine) {
    final name = medicine.name.trim();
    if (name.length < 2) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(name)) return false;
    if (medicine.dosage.isNotEmpty && !RegExp(r'\d').hasMatch(medicine.dosage))
      return false;
    return true;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  SliverAppBar _buildAppBar(bool isDark) {
    final authProvider = context.watch<AuthProvider>();
    final name = authProvider.userProfile?.displayName 
                 ?? authProvider.firebaseUser?.displayName 
                 ?? 'Friend';
    final photoUrl = authProvider.firebaseUser?.photoURL;

    return SliverAppBar(
      floating: false,
      pinned: true,
      expandedHeight: 0,
      toolbarHeight: 70, // Slightly taller for avatar
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      elevation: 0,
      title: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Greeting & Name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EmptyStateGraphic(
              calendarAsset: 'assets/icons/medicine/calendar.png',
              pillAsset: 'assets/icons/medicine/pill_round.png',
            ),
            const SizedBox(height: 32),
            Text(
              'No medications scheduled',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first medicine to get started with tracking',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              text: 'Add Medicine',
              icon: Icons.add,
              onPressed: _navigateToAddMedicine,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTake(
    _ScheduleEntry entry,
    MedicineProvider medicineProvider,
    LogProvider logProvider,
  ) async {
    // Guard against null medicine ID
    final medicineId = entry.medicine.id;
    if (medicineId == null) {
      debugPrint('❌ _handleTake: medicine.id is null!');
      _showFeedback('Error: Invalid medicine', isError: true);
      return;
    }

    debugPrint('🔵 _handleTake: Starting for ${entry.medicine.name} (id: $medicineId)');
    await HapticHelper.light();

    try {
      debugPrint('🔵 _handleTake: Calling markAsTaken...');
      await logProvider.markAsTaken(
        medicineId,
        entry.scheduledDateTime,
        medicine: entry.medicine,
      );
      debugPrint('✅ _handleTake: markAsTaken completed');

      debugPrint('🔵 _handleTake: Decrementing stock...');
      await medicineProvider.decrementStock(medicineId);
      debugPrint('✅ _handleTake: Stock decremented');

      // Update streak
      debugPrint('🔵 _handleTake: Updating streak...');
      final isPerfectDay = await StreakService.instance.onMedicineTaken();
      debugPrint('✅ _handleTake: Streak updated (perfectDay: $isPerfectDay)');

      if (mounted) {
        await HapticHelper.success();
        await SoundHelper.playSuccess();
        
        debugPrint('🔵 _handleTake: Reloading data...');
        await _loadData();
        debugPrint('✅ _handleTake: Data reloaded');

        if (isPerfectDay) {
          _confettiController.play();
          _showFeedback('Perfect day! Streak increased! 🔥');
        } else {
          _triggerSuccessAnimation();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ _handleTake ERROR: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        await HapticHelper.error();
        _showFeedback('Failed to mark as taken: $e', isError: true);
      }
    }
  }

  Future<void> _handleSkip(
    _ScheduleEntry entry,
    LogProvider logProvider,
  ) async {
    // Guard against null medicine ID
    final medicineId = entry.medicine.id;
    if (medicineId == null) {
      debugPrint('❌ _handleSkip: medicine.id is null!');
      _showFeedback('Error: Invalid medicine', isError: true);
      return;
    }

    debugPrint('🔵 _handleSkip: Starting for ${entry.medicine.name} (id: $medicineId)');
    await HapticHelper.warning();
    await SoundHelper.playAlert();

    try {
      debugPrint('🔵 _handleSkip: Calling markAsSkipped...');
      await logProvider.markAsSkipped(
        medicineId,
        entry.scheduledDateTime,
        medicine: entry.medicine,
      );
      debugPrint('✅ _handleSkip: markAsSkipped completed');

      debugPrint('🔵 _handleSkip: Reloading data...');
      await _loadData();
      debugPrint('✅ _handleSkip: Data reloaded');

      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      debugPrint('❌ _handleSkip ERROR: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) _showFeedback('Failed to skip: $e', isError: true);
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
    return logs.firstWhereOrNull(
      (log) =>
          log.medicineId == medicineId &&
          log.scheduledTime.year == scheduledDateTime.year &&
          log.scheduledTime.month == scheduledDateTime.month &&
          log.scheduledTime.day == scheduledDateTime.day &&
          log.scheduledTime.hour == scheduledDateTime.hour &&
          log.scheduledTime.minute == scheduledDateTime.minute,
    );
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
    if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 30))))
      return TimelineStatus.overdue;
    return TimelineStatus.pending;
  }

  MedicineStatus _getMedicineStatus(Log? log, DateTime scheduledDateTime) {
    if (log != null) {
      if (log.status == LogStatus.take) return MedicineStatus.completed;
      if (log.status == LogStatus.skip) return MedicineStatus.skipped;
    }
    final now = DateTime.now();
    if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 30))))
      return MedicineStatus.overdue;
    return MedicineStatus.pending;
  }
}

class _TopBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDark;
  const _TopBanner({
    required this.message,
    required this.isError,
    required this.isDark,
  });
  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isError
                  ? Colors.red.withOpacity(0.9)
                  : (widget.isDark ? const Color(0xFF2A2A2A) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.isError
                    ? Colors.white
                    : (widget.isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NothingElseToday extends StatelessWidget {
  final bool isDark;
  const _NothingElseToday({required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Nothing else today 🌿',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: -0.2,
        ),
      ),
    ),
  );
}

class _AnimatedEntryCard extends StatefulWidget {
  final _ScheduleEntry entry;
  final bool isDark;
  final VoidCallback onTake;
  final VoidCallback onSkip;
  const _AnimatedEntryCard({
    super.key,
    required this.entry,
    required this.isDark,
    required this.onTake,
    required this.onSkip,
  });
  @override
  State<_AnimatedEntryCard> createState() => _AnimatedEntryCardState();
}

class _AnimatedEntryCardState extends State<_AnimatedEntryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTake();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scaleAnimation,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MinimalMedicineCard(
        entry: widget.entry,
        isDark: widget.isDark,
        onTake: _handleTap,
        onSkip: widget.onSkip,
      ),
    ),
  );
}

class _StatsCard extends StatelessWidget {
  final int completed;
  final int total;
  final bool isDark;
  final DateTime? nextSchedule;
  final Animation<double> animation;
  final int streak;
  const _StatsCard({
    required this.completed,
    required this.total,
    required this.isDark,
    this.nextSchedule,
    required this.animation,
    this.streak = 0,
  });
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    final clampedRatio = min(ratio, 1.0);
    final percentage = (clampedRatio * 100).round();
    final remaining = max(total - completed, 0);
    final isComplete = remaining == 0 && total > 0;
    
    // Premium gradient colors
    final gradientColors = isDark
        ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
        : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)];
    
    final accentColor = isComplete 
        ? const Color(0xFF10B981) // Emerald
        : const Color(0xFF6366F1); // Indigo
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Premium Progress Ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Background ring
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                    ),
                  ),
                ),
                // Progress ring with animation
                SizedBox(
                  width: 70,
                  height: 70,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => CircularProgressIndicator(
                      value: clampedRatio * animation.value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ),
                // Center content
                if (isComplete)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, color: accentColor, size: 22),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Stats Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (streak > 0)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AchievementsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF5722).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFF5722),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF5722),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isComplete) ...[
                  Text(
                    'All Done!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: -0.5,
                    ),
                  )
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$completed',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '/$total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'doses',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (nextSchedule != null)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Next at ${DateFormat('h:mm a').format(nextSchedule!)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                ],
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
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF3B3B5A), const Color(0xFF2A2A40)]
                : [const Color(0xFFE8E8F0), const Color(0xFFD8D8E8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    ],
  );
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
    final medicineColor = entry.medicine.colorValue;
    final cardGradient = isDark
        ? [const Color(0xFF1E1E2E), const Color(0xFF181825)]
        : [Colors.white, const Color(0xFFFAFAFA)];
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCompleted 
              ? (isDark 
                  ? [const Color(0xFF1A2E1A), const Color(0xFF162516)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFE8F5E9)])
              : cardGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
          width: 1.5,
        ),
        boxShadow: !isCompleted
            ? [
                BoxShadow(
                  color: medicineColor.withOpacity(isDark ? 0.15 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Accent bar for pending items
              if (!isCompleted)
                Container(
                  width: 4,
                  height: 52,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isOverdue
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [medicineColor.withOpacity(0.8), medicineColor],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: (isOverdue ? Colors.red : medicineColor).withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              // Medicine icon - larger, no background
              SizedBox(
                width: 56,
                height: 56,
                child: isCompleted
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 32,
                        ),
                      )
                    : Image.asset(
                        entry.medicine.iconAssetPath,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(width: 14),
              // Medicine info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.medicine.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: isDark
                            ? Colors.white38
                            : Colors.black38,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withOpacity(0.12)
                                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: isOverdue
                                    ? Colors.red
                                    : (isDark ? Colors.white54 : Colors.black45),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.jm().format(entry.scheduledDateTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue
                                      ? Colors.red
                                      : isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (entry.medicine.dosage.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.medicine.dosage,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PremiumActionButton(
                    label: 'Take',
                    icon: Icons.check_rounded,
                    onPressed: onTake,
                    isPrimary: true,
                    isDark: isDark,
                    accentColor: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
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

class _PremiumActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDark;
  final Color accentColor;
  
  const _PremiumActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isPrimary,
    required this.isDark,
    required this.accentColor,
  });
  
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                    ? [Colors.white, const Color(0xFFE5E5E5)]
                    : [const Color(0xFF1A1A1A), Colors.black],
              )
            : null,
        color: isPrimary ? null : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
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
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black54),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MinimalFAB extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _MinimalFAB({required this.onTap, required this.isDark});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 68,
      width: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [Colors.white, const Color(0xFFE8E8E8)]
              : [const Color(0xFF2A2A2A), Colors.black],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: (isDark ? Colors.white : const Color(0xFF6366F1)).withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 4),
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.add_rounded,
        size: 32,
        color: isDark ? Colors.black : Colors.white,
      ),
    ),
  );
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

class _EmptyStateGraphic extends StatefulWidget {
  final String calendarAsset;
  final String pillAsset;

  const _EmptyStateGraphic({
    required this.calendarAsset,
    required this.pillAsset,
    super.key,
  });

  @override
  State<_EmptyStateGraphic> createState() => _EmptyStateGraphicState();
}

class _EmptyStateGraphicState extends State<_EmptyStateGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final Animation<double> _float = Tween(begin: 0.0, end: -10.0)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_controller);

  late final Animation<double> _scale = Tween(begin: 0.96, end: 1.02)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _float.value),
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            widget.calendarAsset,
            width: 220,
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: 20,
            right: 40,
            child: Transform.rotate(
              angle: -0.1,
              child: Image.asset(
                widget.pillAsset,
                width: 72,
                fit: BoxFit.contain,
                color: Colors.white.withOpacity(0.9),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
