import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/log.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/progress_ring.dart';
import '../widgets/timeline_item.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';
import 'add_edit_medicine_screen.dart';
import 'inventory_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui';

/// Dashboard screen showing today's medicine schedule
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    // Load data after the first frame is rendered
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

    // Reschedule notifications
    await scheduleProvider.rescheduleAllNotifications(
      medicineProvider.medicines,
    );
  }

  bool _showSuccessAnimation = false;

  Future<void> _refresh() async {
    await _loadData();
  }

  void _triggerSuccessAnimation() {
    setState(() {
      _showSuccessAnimation = true;
    });
    _confettiController.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccessAnimation = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, MMM d').format(DateTime.now()),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: SafeArea(
              child: Column(
                children: [
                  // Summary Card
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Consumer<LogProvider>(
                      builder: (context, logProvider, _) {
                        final progress = logProvider.calculateDailyProgress(
                          DateTime.now(),
                          context.read<ScheduleProvider>().schedules,
                        );
                        
                        return ProgressRing(
                          progress: progress['percentage'] as double,
                          total: progress['total'] as int,
                          taken: progress['taken'] as int,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Consumer3<MedicineProvider, ScheduleProvider, LogProvider>(
                      builder: (context, medicineProvider, scheduleProvider, logProvider,
                          child) {
                        if (medicineProvider.isLoading ||
                            scheduleProvider.isLoading ||
                            logProvider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final todaySchedules = scheduleProvider.todaySchedules;
                        final todayLogs = logProvider.todayLogs;

                        // Calculate today's adherence
                        final total = todaySchedules.length;
                        final taken =
                            todayLogs.where((log) => log.status == LogStatus.take).length;
                        final adherenceRate = total > 0 ? (taken / total) : 0.0;

                        if (todaySchedules.isEmpty) {
                          return _buildEmptyState();
                        }

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Today's Date (moved from original position, now part of AppBar)
                              // Text(
                              //   DateFormat('EEEE, MMMM d').format(DateTime.now()),
                              //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              //         fontWeight: FontWeight.bold,
                              //       ),
                              // ),
                              // const SizedBox(height: 8),
                              Text(
                                'Today\'s Schedule',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 16),

                              // Timeline of today's medicines
                              ...todaySchedules.map((schedule) {
                                final medicine = medicineProvider.getMedicineById(
                                  schedule.medicineId,
                                );
                                if (medicine == null) return const SizedBox.shrink();

                                // Check if already logged
                                final log = todayLogs.firstWhere(
                                  (l) =>
                                      l.medicineId == medicine.id &&
                                      l.scheduledTime.hour ==
                                          int.parse(schedule.timeOfDay.split(':')[0]) &&
                                      l.scheduledTime.minute ==
                                          int.parse(schedule.timeOfDay.split(':')[1]),
                                  orElse: () => Log(
                                    medicineId: -1,
                                    scheduledTime: DateTime.now(),
                                    status: LogStatus.missed,
                                  ),
                                );

                                final isLogged = log.medicineId != -1;

                                return TimelineItem(
                                  medicine: medicine,
                                  schedule: schedule,
                                  isLogged: isLogged,
                                  logStatus: isLogged ? log.status : null,
                                  onTake: () => _handleTake(
                                    medicine,
                                    schedule,
                                    medicineProvider,
                                    logProvider,
                                  ),
                                  onSkip: () => _handleSkip(
                                    medicine,
                                    schedule,
                                    logProvider,
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showSuccessAnimation)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(128),
                child: Center(
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_kq5r8acy.json', // Beautiful success checkmark
                    width: 300,
                    height: 300,
                    repeat: false,
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
                Colors.purple
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditMedicineScreen(),
            ),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Med'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No Medicines Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first medicine to get started',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTake(
    medicine,
    schedule,
    MedicineProvider medicineProvider,
    LogProvider logProvider,
  ) async {
    // Create scheduled time for today
    final now = DateTime.now();
    final parts = schedule.timeOfDay.split(':');
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    // Haptic feedback for success
    await HapticHelper.success();
    await SoundHelper.playSuccess();
    
    // Mark as taken
    await logProvider.markAsTaken(medicine.id!, scheduledTime);

    // Decrement stock
    await medicineProvider.decrementStock(medicine.id!);

    // Trigger success animation
    _triggerSuccessAnimation();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ ${medicine.name} marked as taken',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSkip(
    medicine,
    schedule,
    LogProvider logProvider,
  ) async {
    // Create scheduled time for today
    final now = DateTime.now();
    final parts = schedule.timeOfDay.split(':');
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    // Haptic feedback for warning
    await HapticHelper.warning();
    await SoundHelper.playAlert();
    
    // Mark as skipped
    await logProvider.markAsSkipped(medicine.id!, scheduledTime);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped ${medicine.name}',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
