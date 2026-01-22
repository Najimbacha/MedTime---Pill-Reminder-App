import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shared_adherence_data.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/haptic_helper.dart';
import 'accept_invite_screen.dart';
import '../services/report_service.dart';

/// Dashboard for caregivers to monitor their linked patients
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    final syncProvider = context.read<SyncProvider>();
    await syncProvider.loadLinkedPatients();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Caregiver Dashboard',
          style: theme.textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, _) {
          if (syncProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (syncProvider.linkedPatients.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: syncProvider.linkedPatients.length,
              itemBuilder: (context, index) {
                final patient = syncProvider.linkedPatients[index];
                return _PatientCard(patient: patient);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await HapticHelper.selection();
          if (mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AcceptInviteScreen()),
            );
            if (result == true) {
              _loadData();
            }
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 80,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Patients Linked',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your patient to share their invite code with you to start monitoring their medication adherence.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.selection();
                if (mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcceptInviteScreen()),
                  );
                  if (result == true) {
                    _loadData();
                  }
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Enter Invite Code'),
            ),
          ],
        ),
      ),
    );
  }
}



/// Card displaying a patient's info and adherence summary
class _PatientCard extends StatefulWidget {
  final UserProfile patient;

  const _PatientCard({required this.patient});

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  Map<String, dynamic>? _stats;
  bool _isExpanded = false;
  final ReportService _reportService = ReportService();
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final syncProvider = context.read<SyncProvider>();
    final stats = await syncProvider.loadPatientStats(widget.patient.id);
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_isGeneratingReport) return;
    
    setState(() => _isGeneratingReport = true);
    await HapticHelper.selection();

    try {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF Report...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Fetch recent logs (take 100 via stream first element)
      final syncProvider = context.read<SyncProvider>();
      final logsStream = syncProvider.getLogsStream(widget.patient.id);
      final logs = await logsStream.first; // Get current snapshot

      await _reportService.generateCaregiverReport(
        patientName: widget.patient.displayName ?? 'Patient',
        stats: _stats ?? {},
        recentLogs: logs,
      );
      
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final adherenceRate = (_stats?['adherenceRate'] ?? 0.0) as double;
    final adherenceColor = adherenceRate >= 80
        ? Colors.green
        : adherenceRate >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (widget.patient.displayName ?? 'P').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          title: Text(
            widget.patient.displayName ?? 'Patient',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(
                  adherenceRate >= 80 ? Icons.check_circle_rounded : Icons.warning_rounded,
                  size: 16,
                  color: adherenceColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '${adherenceRate.toStringAsFixed(0)}% adherence',
                  style: TextStyle(
                    color: adherenceColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isGeneratingReport)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  color: colorScheme.primary,
                  onPressed: _generateReport,
                  tooltip: 'Export PDF Report',
                ),
              RotationTransition(
                turns: AlwaysStoppedAnimation(_isExpanded ? 0.5 : 0),
                child: Icon(Icons.expand_more, color: theme.iconTheme.color),
              ),
            ],
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          'Taken',
                          '${_stats?['taken'] ?? 0}',
                          Colors.green,
                        ),
                        _buildStat(
                          'Missed',
                          '${_stats?['missed'] ?? 0}',
                          Colors.red,
                        ),
                        _buildStat(
                          'Skipped',
                          '${_stats?['skipped'] ?? 0}',
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
    
                    // Today's Log Stream
                    Row(
                      children: [
                        Icon(Icons.history, size: 16, color: colorScheme.outline),
                        const SizedBox(width: 8),
                        Text(
                          "TODAY'S ACTIVITY",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.outline,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<SharedAdherenceData>>(
                      stream: context.read<SyncProvider>().getTodayLogsStream(widget.patient.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
    
                        final logs = snapshot.data ?? [];
    
                        if (logs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'No activity yet',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
    
                        return Column(
                          children: logs.take(5).map((log) => _buildLogItem(log)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildLogItem(SharedAdherenceData log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    Color color;

    switch (log.status) {
      case 'taken':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'missed':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'skipped':
        icon = Icons.skip_next;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help_outline;
        color = colorScheme.onSurfaceVariant;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.medicineName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  log.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatTime(log.scheduledTime),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
