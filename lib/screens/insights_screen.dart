import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/history_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../models/log.dart';
import '../providers/medicine_provider.dart';
import '../services/report_service.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final HistoryService _historyService = HistoryService();
  bool _isLoading = true;
  List<AdherenceData> _adherenceTrend = [];
  double _overallAdherence = 0.0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trend = await _historyService.getLast7DaysAdherence();
    final overall = await _historyService.getOverallAdherence();
    final streak = await _historyService.getCurrentStreak();

    if (mounted) {
      setState(() {
        _adherenceTrend = trend;
        _overallAdherence = overall;
        _streak = streak;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportReport() async {
    await HapticHelper.selection();
    await SoundHelper.playClick();
    
    // Show simple input dialog for name
    String? name;
    if (mounted) {
      name = await showDialog<String>(
        context: context,
        builder: (context) {
          String input = '';
          return AlertDialog(
            title: const Text('Export Report'),
            content: TextField(
              decoration: const InputDecoration(labelText: 'Patient Name (Optional)'),
              onChanged: (v) => input = v,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, input), child: const Text('Generate')),
            ],
          );
        },
      );
    }
    
    if (name == null && mounted) return; // Cancelled

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF Report...')),
      );
    }

    try {
      final reportService = ReportService();
      // user name handling
      
      // Get data
      final medicines = context.read<MedicineProvider>().medicines;
      final logs = await _historyService.getRecentLogs(limit: 30);
      
      // Create map for med names
      final medNames = {for (var m in medicines) m.id!: m.name};

      await reportService.generateAndShareReport(
        medicines: medicines,
        overallAdherence: _overallAdherence,
        streak: _streak,
        recentLogs: logs,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Insights', style: TextStyle(fontSize: 22)),
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 24),
                  _buildAdherenceChart(),
                  const SizedBox(height: 24),
                  _buildStreakCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Row(
      children: [
        _buildStatCard(
          'Overall Adherence',
          '${_overallAdherence.toStringAsFixed(1)}%',
          Icons.check_circle_outline,
          Colors.green,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Current Streak',
          '$_streak Days',
          Icons.local_fire_department,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7-Day Adherence Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= _adherenceTrend.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _adherenceTrend[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('E').format(date).substring(0, 1),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _adherenceTrend.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.rate);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withAlpha(26),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stars, color: Colors.orange, size: 32),
        ),
        title: const Text(
          'Keep it up!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'You have a $_streak day streak of taking all your medications. Let\'s go for another day!',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
