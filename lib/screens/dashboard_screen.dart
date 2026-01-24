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
import '../widgets/glass_dialog.dart';
import '../widgets/staggered_list_animation.dart';
import '../utils/sound_helper.dart';
import 'add_edit_medicine_screen.dart';
import 'settings_screen.dart';
import 'package:lottie/lottie.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import '../services/report_service.dart';
import '../services/history_service.dart';
import 'package:confetti/confetti.dart';
import '../widgets/empty_state_widget.dart';
import 'achievements_screen.dart';
import '../widgets/medicine_action_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ConfettiController _confettiController;
  bool _showSuccessAnimation = false;
  /// Optmistic removal IDs for Dismissible items. Value true = taken, false = skipped
  final Map<String, bool> _dismissedItems = {};
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
      // Gradient Background
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
              ? AppColors.surfaceGradientDark 
              : AppColors.surfaceGradientLight,
        ),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              backgroundColor: isDark ? AppColors.surface1Dark : Colors.white,
              child: SafeArea(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(), // Smoother scroll
                  ),
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
                                    strokeWidth: 3,
                                    color: AppColors.primary,
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
                                  (entry) {
                                    if (entry.timelineStatus == TimelineStatus.completed) return false;
                                    final key = '${entry.medicine.id}_${entry.scheduledDateTime.toIso8601String()}';
                                    return !_dismissedItems.containsKey(key);
                                  }
                                )
                                .toList();

                            final completedEntries = validEntries
                                .where(
                                  (entry) =>
                                      entry.timelineStatus ==
                                      TimelineStatus.completed,
                                )
                                .toList();
                                
                            // Calculate Optimistic Stats
                            final alreadyCompletedKeys = completedEntries
                                .map((e) => '${e.medicine.id}_${e.scheduledDateTime.toIso8601String()}')
                                .toSet();
                                
                            final optimisticTakenCount = _dismissedItems.entries
                                .where((e) => e.value == true && !alreadyCompletedKeys.contains(e.key))
                                .length;
                                
                            final totalCount = validEntries.length; 
                            final completedCount = completedEntries.length + optimisticTakenCount;

                            // Group by Time of Day
                            final morning = pendingEntries.where((e) => e.scheduledDateTime.hour < 12).toList();
                            final afternoon = pendingEntries.where((e) => e.scheduledDateTime.hour >= 12 && e.scheduledDateTime.hour < 18).toList();
                            final evening = pendingEntries.where((e) => e.scheduledDateTime.hour >= 18).toList();
                            
                            if (validEntries.isEmpty) {
                              return SliverPadding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                sliver: SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 60),
                                      child: _buildEmptyState(),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _StatsCard(
                                    completed: completedCount,
                                    total: totalCount,
                                    isDark: isDark,
                                    nextSchedule: pendingEntries.isNotEmpty
                                        ? pendingEntries.first.scheduledDateTime
                                        : null,
                                    animation: _progressAnimation,
                                    streak: _streak,
                                    onExportReport: _exportReport,
                                  ),
                                  const SizedBox(height: 32),
                                  
                                    if (morning.isNotEmpty) ...[
                                      _SectionTitle(title: 'Morning 🌅', count: morning.length, isDark: isDark),
                                      const SizedBox(height: 16),
                                      SimpleStaggeredList(
                                        children: morning.map((entry) => _AnimatedEntryCard(
                                          key: ValueKey('${entry.medicine.id}_${entry.scheduledDateTime}'),
                                          entry: entry,
                                          isDark: isDark,
                                          onTake: () => _handleTake(entry, medicineProvider, logProvider),
                                          onSkip: () => _handleSkip(entry, logProvider),
                                        )).toList(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],

                                    if (afternoon.isNotEmpty) ...[
                                      _SectionTitle(title: 'Afternoon ☀️', count: afternoon.length, isDark: isDark),
                                      const SizedBox(height: 16),
                                      SimpleStaggeredList(
                                        children: afternoon.map((entry) => _AnimatedEntryCard(
                                          key: ValueKey('${entry.medicine.id}_${entry.scheduledDateTime}'),
                                          entry: entry,
                                          isDark: isDark,
                                          onTake: () => _handleTake(entry, medicineProvider, logProvider),
                                          onSkip: () => _handleSkip(entry, logProvider),
                                        )).toList(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],

                                    if (evening.isNotEmpty) ...[
                                      _SectionTitle(title: 'Evening 🌙', count: evening.length, isDark: isDark),
                                      const SizedBox(height: 16),
                                      SimpleStaggeredList(
                                        children: evening.map((entry) => _AnimatedEntryCard(
                                          key: ValueKey('${entry.medicine.id}_${entry.scheduledDateTime}'),
                                          entry: entry,
                                          isDark: isDark,
                                          onTake: () => _handleTake(entry, medicineProvider, logProvider),
                                          onSkip: () => _handleSkip(entry, logProvider),
                                        )).toList(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  
                                  if (pendingEntries.isEmpty && completedEntries.isNotEmpty) ...[
                                    const SizedBox(height: 16),
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
                                          onOptions: () {}, // No-op for completed items
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
            
            // Success Overlay
            if (_showSuccessAnimation)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
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
              ),
              
            // Confetti Layer
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFF6366F1), // Indigo
                  Color(0xFFEF4444), // Red
                  Color(0xFF10B981), // Emerald
                  Color(0xFFF59E0B), // Amber
                  Color(0xFF8B5CF6), // Violet
                ],
                gravity: 0.2,
                numberOfParticles: 20,
              ),
            ),
          ],
        ),
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
      floating: true,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      toolbarHeight: 90,
      title: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
             // Premium Avatar with Glow
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Greeting & Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_getGreeting()},',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Streak Badge in AppBar
        if (_streak > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AchievementsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyStateWidget(
          title: 'No medications',
          message: 'Add your first medicine to get started with tracking.',
          icon: Icons.medication_outlined,
          buttonText: 'Add Medicine',
          onButtonPressed: _navigateToAddMedicine,
        ),
      ],
    );
  }

  // ... inside _DashboardScreenState ...
  final HistoryService _historyService = HistoryService();



// ...

  Future<void> _exportReport() async {
    await HapticHelper.selection();
    
    String? name;
    if (mounted) {
      name = await showDialog<String>(
        context: context,
        builder: (context) {
          String input = '';
          return GlassDialog(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Export Report',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter patient name to include in the report (optional)',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Patient Name',
                    hintText: 'e.g. Najim Bacha',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => input = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, input),
                child: const Text('Generate PDF'),
              ),
            ],
          );
        },
      );
    }
    
    if (name == null && mounted) return; 
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('Generating PDF Report...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final reportService = ReportService();
      
      // Fetch required data on demand
      final medicines = context.read<MedicineProvider>().medicines;
      final overallAdherence = await _historyService.getOverallAdherence();
      final recentLogs = await _historyService.getRecentLogs(limit: 30);
      
      // Create map for med names
      final medNames = {for (var m in medicines) m.id!: m.name};

      await reportService.generateAndShareReport(
        medicines: medicines,
        overallAdherence: overallAdherence,
        streak: _streak, // Use current dashboard streak
        recentLogs: recentLogs,
        medicineNames: medNames,
        patientName: name,
      );
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleTake(
    _ScheduleEntry entry,
    MedicineProvider medicineProvider,
    LogProvider logProvider,
  ) async {
    final medicineId = entry.medicine.id;
    if (medicineId == null) return;

    final uniqueKey = '${entry.medicine.id}_${entry.scheduledDateTime.toIso8601String()}';
    // Optimistic Update for Dismissible
    setState(() {
      _dismissedItems[uniqueKey] = true; // Taken
    });

    await HapticHelper.light();

    try {
      // 1. Mark as taken and get log
      await logProvider.markAsTaken(
        medicineId,
        entry.scheduledDateTime,
        medicine: entry.medicine,
      );

      // 2. Decrement stock
      await medicineProvider.decrementStock(medicineId);

      // 3. Update streak
      final isPerfectDay = await StreakService.instance.onMedicineTaken();

      if (mounted) {
        await HapticHelper.success();
        await SoundHelper.playSuccess();
        
        await _loadData();

        if (isPerfectDay) {
          _confettiController.play();
        } else {
          _triggerSuccessAnimation();
        }
      }
    } catch (e) {
      debugPrint('❌ _handleTake ERROR: $e');
      if (mounted) {
         HapticHelper.error();
        _showFeedback('Failed to mark as taken: $e', isError: true);
      }
    }
  }

  Future<void> _handleSkip(
    _ScheduleEntry entry,
    LogProvider logProvider,
  ) async {
    final medicineId = entry.medicine.id;
    if (medicineId == null) return;
    
    final uniqueKey = '${entry.medicine.id}_${entry.scheduledDateTime.toIso8601String()}';
    setState(() {
      _dismissedItems[uniqueKey] = false; // Skipped
    });

    await HapticHelper.light();

    try {
      debugPrint('🔵 _handleSkip: Calling markAsSkipped...');
      final log = await logProvider.markAsSkipped(
        medicineId,
        entry.scheduledDateTime,
        medicine: entry.medicine,
      );
      debugPrint('✅ _handleSkip: markAsSkipped completed');

      if (mounted) {
        await _loadData();
        
        // Show Undo SnackBar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.skip_next_rounded, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(child: Text('Skipped ${entry.medicine.name}')),
              ],
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.orangeAccent,
              onPressed: () async {
                // UNDO ACTION
                await logProvider.deleteLog(log.id!);
                await _loadData();
                if (mounted) {
                   HapticHelper.selection();
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Action undone'), duration: Duration(seconds: 1)),
                   );
                }
              },
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _handleSkip ERROR: $e');
      if (mounted) {
         HapticHelper.error();
        _showFeedback('Failed to skip: $e', isError: true);
      }
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
      (log) {
        if (log.medicineId != medicineId) return false;
        
        // Relaxed matching: Match if within 2 minutes to handle potential DB precision loss
        final diff = log.scheduledTime.difference(scheduledDateTime).abs();
        return diff.inMinutes < 2;
      }
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

  void _handleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicineActionSheet(
        medicine: widget.entry.medicine,
        onTake: () async {
          await _controller.forward();
          await _controller.reverse();
          widget.onTake();
        },
        onSkip: widget.onSkip,
        onSnooze: (minutes) async {
             // Schedule snooze
             await NotificationService.instance.scheduleSnooze(
               medicineId: widget.entry.medicine.id!, 
               medicineName: widget.entry.medicine.name, 
               dosage: widget.entry.medicine.dosage, 
               minutes: minutes
             );
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Snoozed for $minutes minutes 💤')),
               );
             }
        },
      ),
    );
  }

  void _handleTake() async {
    await SoundHelper.playSuccess(); // Play satisfying sound
    await _controller.forward();
    await _controller.reverse();
    widget.onTake();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey(
                '${widget.entry.medicine.id}_${widget.entry.scheduledDateTime.toIso8601String()}'),
            direction: DismissDirection.horizontal,
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                widget.onTake();
              } else {
                widget.onSkip();
              }
            },
            background: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10B981), // Green
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 32),
                  SizedBox(width: 8),
                  Text(
                    "Take",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.grey, // Grey
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.centerRight,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                ],
              ),
            ),
            child: _MinimalMedicineCard(
              entry: widget.entry,
              isDark: widget.isDark,
              onTake: _handleTake,
              onSkip: widget.onSkip,
              onOptions: _handleOptions,
            ),
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
  final VoidCallback onExportReport;

  const _StatsCard({
    required this.completed,
    required this.total,
    required this.isDark,
    this.nextSchedule,
    required this.animation,
    this.streak = 0,
    required this.onExportReport,
  });

  @override
  Widget build(BuildContext context) {
    // Premium Design Colors
    final progressGradient = const SweepGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF818CF8)], // Indigo to lighter Indigo
      startAngle: 0.0,
      endAngle: 3.14 * 2,
    );
    
    // Calculate progress
    double percentage = 0;
    if (total > 0) {
      percentage = (completed / total);
    }
    double clampedRatio = percentage.clamp(0.0, 1.0);
    int percentageInt = (percentage * 100).toInt();
    
    // Determine if it's a "rest day" (no doses scheduled)
    final isRestDay = total == 0;
    final isComplete = completed == total && total > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Compact Progress Ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Background Ring
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 8,
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Shadow for depth
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
              // Foreground Gradient Ring (Rotated to start at top)
              Transform.rotate(
                angle: -1.5708, // -90 degrees (start at top)
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) {
                      // Inflate significantly to ensure gradient covers completely
                      return progressGradient.createShader(rect.inflate(20)); 
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2), // Ensure stroke doesn't touch bounds
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) => CircularProgressIndicator(
                          value: isRestDay ? 0.001 : (clampedRatio * animation.value),
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Center content
              if (isRestDay)
                Icon(
                  Icons.wb_sunny_rounded,
                  size: 26,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade600,
                )
              else if (isComplete)
                const Icon(
                  Icons.check_rounded,
                  size: 28,
                  color: Color(0xFF10B981),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percentageInt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: isDark ? Colors.white54 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // 2. Stats Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title + Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isRestDay 
                            ? 'Rest Day' 
                            : isComplete 
                                ? 'All Done! 🎉'
                                : 'Daily Progress',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PDF Export Button with label
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onExportReport,
                            borderRadius: BorderRadius.circular(8),
                            child: Tooltip(
                              message: 'Export PDF Report',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withOpacity(0.15) : const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 14,
                                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Doses Count or Rest Day message
                if (isRestDay)
                  Text(
                    'No medications scheduled',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$completed',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '/$total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'doses',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                      ),
                      // Next schedule inline
                      if (nextSchedule != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat.jm().format(nextSchedule!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
  final VoidCallback onOptions;
  const _MinimalMedicineCard({
    required this.entry,
    required this.isDark,
    required this.onTake,
    required this.onSkip,
    required this.onOptions,
  });
  bool get isCompleted => entry.medicineStatus == MedicineStatus.completed;
  bool get isOverdue => entry.medicineStatus == MedicineStatus.overdue;
  
  @override
  Widget build(BuildContext context) {
    final medicineColor = entry.medicine.colorValue;
    final accentColor = isOverdue ? Colors.red : medicineColor;
    
    return GestureDetector(
      onTap: onOptions, // Long-press or tap opens action sheet
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCompleted
              ? (isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FDF4))
              : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF10B981).withOpacity(0.3)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
            width: 1,
          ),
          boxShadow: !isCompleted
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(isDark ? 0.08 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Color accent dot
            if (!isCompleted)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            // Medicine icon - compact
            SizedBox(
              width: 40,
              height: 40,
              child: Hero(
                tag: 'medicine_icon_${entry.medicine.id}',
                child: isCompleted
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      )
                    : Image.asset(
                        entry.medicine.iconAssetPath,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Medicine info - expanded
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + Time row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.medicine.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            decorationColor: isDark ? Colors.white38 : Colors.black38,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Inline time
                      Text(
                        DateFormat.jm().format(entry.scheduledDateTime),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                          color: isOverdue
                              ? Colors.red
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  // Dosage row (if present)
                  if (entry.medicine.dosage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.medicine.dosage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Take button - compact circular
            if (!isCompleted) ...[
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTake,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Take',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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


