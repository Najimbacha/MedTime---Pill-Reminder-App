import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/log_provider.dart';
import '../providers/medicine_provider.dart';
import '../models/log.dart';

/// Screen showing adherence history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final logProvider = context.read<LogProvider>();
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    
    final stats = await logProvider.getAdherenceStats(startOfMonth, endOfMonth);
    setState(() {
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History & Reports',
          style: TextStyle(fontSize: 22),
        ),
      ),
      body: Consumer2<LogProvider, MedicineProvider>(
        builder: (context, logProvider, medicineProvider, child) {
          final logs = logProvider.logs;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Card
                if (_stats != null) _buildStatsCard(),
                const SizedBox(height: 24),

                // Month Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 32),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month - 1,
                          );
                        });
                        _loadStats();
                      },
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 32),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month + 1,
                          );
                        });
                        _loadStats();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Logs List
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (logs.isEmpty)
                  _buildEmptyState()
                else
                  ...logs.take(20).map((log) {
                    final medicine = medicineProvider.getMedicineById(log.medicineId);
                    if (medicine == null) return const SizedBox.shrink();
                    return _buildLogItem(log, medicine.name);
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    final total = _stats!['total'] as int;
    final taken = _stats!['taken'] as int;
    final skipped = _stats!['skipped'] as int;
    final missed = _stats!['missed'] as int;
    final adherenceRate = _stats!['adherence_rate'] as String;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Adherence Rate',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$adherenceRate%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Taken', taken, Colors.green),
                _buildStatItem('Skipped', skipped, Colors.orange),
                _buildStatItem('Missed', missed, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(Log log, String medicineName) {
    IconData icon;
    Color color;
    
    switch (log.status) {
      case LogStatus.take:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case LogStatus.skip:
        icon = Icons.cancel;
        color = Colors.orange;
        break;
      case LogStatus.missed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          medicineName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy - h:mm a').format(log.scheduledTime),
          style: const TextStyle(fontSize: 16),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            log.statusText.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
