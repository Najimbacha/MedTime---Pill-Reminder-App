import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shared_adherence_data.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/haptic_helper.dart';
import 'accept_invite_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final adherenceRate = (_stats?['adherenceRate'] ?? 0.0) as double;
    final adherenceColor = adherenceRate >= 80
        ? Colors.green
        : adherenceRate >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            (widget.patient.displayName ?? 'P').substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          widget.patient.displayName ?? 'Patient',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Row(
          children: [
            Icon(
              adherenceRate >= 80 ? Icons.check_circle : Icons.warning,
              size: 16,
              color: adherenceColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${adherenceRate.toStringAsFixed(0)}% adherence',
              style: TextStyle(color: adherenceColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                
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
                const SizedBox(height: 16),

                // Today's Log Stream
                Text(
                  "Today's Activity",
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No activity recorded yet today',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
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
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.medicineName,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            _formatTime(log.scheduledTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
