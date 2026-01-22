import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/staggered_list_animation.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/log_provider.dart';
import '../providers/medicine_provider.dart';
import '../models/log.dart';
import '../widgets/medicine_log_card.dart';
import '../widgets/empty_state_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  // Using 7 days for the chart
  List<Map<String, dynamic>> _weeklyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final logProvider = context.read<LogProvider>();
    
    // Load weekly stats for the chart (last 7 days from selected date)
    // For simplicity, let's show the "current week" of the selected date
    // Or just last 7 days ending at selected date. Let's do 7 days ending selected.
    final List<Map<String, dynamic>> stats = [];
    for (int i = 6; i >= 0; i--) {
      final date = _selectedDate.subtract(Duration(days: i));
      final dayLogs = await logProvider.getLogsByDate(date);
      final taken = dayLogs.where((l) => l.status == LogStatus.take).length;
      final total = dayLogs.length;
      stats.add({
        'day': DateFormat('E').format(date).substring(0, 1), // M, T, W
        'rate': total > 0 ? (taken / total) * 100 : 0.0,
        'date': date,
      });
    }

    if (mounted) {
      setState(() {
        _weeklyStats = stats;
        _isLoading = false;
      });
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logProvider = context.watch<LogProvider>();
    final medicineProvider = context.watch<MedicineProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Calendar Strip & Chart Area
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Date Selector
                      _buildDateSelector(isDark),
                      const SizedBox(height: 24),
                      // Chart
                      SizedBox(
                        height: 180,
                        child: _buildWeeklyChart(isDark),
                      ),
                    ],
                  ),
                ),

                // 2. Logs List
                Expanded(
                  child: FutureBuilder<List<Log>>(
                    future: logProvider.getLogsByDate(_selectedDate),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      
                      final logs = snapshot.data!;
                      if (logs.isEmpty) return _buildEmptyState(isDark);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Bottom padding for glass nav
                        child: SimpleStaggeredList(
                          children: logs.map((log) {
                            final medicine = medicineProvider.getMedicineById(log.medicineId);
                            if (medicine == null) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MedicineLogCard(
                                medicineName: medicine.name,
                                dosage: medicine.dosage,
                                status: log.status,
                                scheduledTime: log.scheduledTime,
                                colorValue: medicine.color,
                                iconAssetPath: medicine.iconAssetPath,
                                medicineType: medicine.typeIcon == 1 ? 'Pill' : 'Medicine',
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateSelector(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _onDateChanged(_selectedDate.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
          ),
        ),
        Column(
          children: [
            Text(
              DateFormat('EEEE').format(_selectedDate),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            if (_selectedDate.add(const Duration(days: 1)).isAfter(DateTime.now())) return;
            _onDateChanged(_selectedDate.add(const Duration(days: 1)));
          },
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(bool isDark) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            // tooltipBgColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            tooltipBgColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}%',
                TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= _weeklyStats.length) return const SizedBox();
                final day = _weeklyStats[value.toInt()]['day'] as String;
                final date = _weeklyStats[value.toInt()]['date'] as DateTime;
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.blue 
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _weeklyStats.asMap().entries.map((e) {
          final index = e.key;
          final data = e.value;
          final rate = data['rate'] as double;
          final date = data['date'] as DateTime;
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: rate,
                color: isSelected ? Colors.blue : (isDark ? Colors.white24 : Colors.grey.shade300),
                width: 12,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100, // Full height background
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyStateWidget(
          title: 'No activity yet',
          message: 'Records for this day will appear here once you take or skip your medicines.',
          icon: Icons.history_edu_rounded,
        ),
      ),
    );
  }
}

