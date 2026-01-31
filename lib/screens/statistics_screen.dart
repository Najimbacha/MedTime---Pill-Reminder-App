import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/statistics_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/empty_state_widget.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatisticsProvider>().loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC), // Slate 900 or Slate 50
      body: Consumer<StatisticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          }

          if (provider.overallAdherence == 0 &&
              provider.currentStreak == 0 &&
              provider.weeklyAdherence.every((val) => val == 0)) {
            return _buildPremiumEmptyState(context); // Custom empty state
          }

          return CustomScrollView(
            slivers: [
              // 1. App Bar with Gradient
              SliverAppBar(
                expandedHeight: 320.0,
                floating: false,
                pinned: true,
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'Health Hub',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [
                                const Color(0xFFE2E8F0),
                                const Color(0xFFF8FAFC),
                              ],
                      ),
                    ),
                    child: SafeArea(
                      child: Center(
                        child: _AdherenceRadialHero(
                          percentage: provider.overallAdherence,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Weekly Activity Chart
                      _buildSectionHeader(context, "Weekly Activity", isDark),
                      const SizedBox(height: 16),
                      _buildGradientChart(
                        context,
                        provider.weeklyAdherence,
                        isDark,
                      ),

                      const SizedBox(height: 32),

                      // 3. Smart Insights
                      _buildSectionHeader(
                        context,
                        "Insights & Streaks",
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStreakCard(
                              context,
                              provider.currentStreak,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatusCard(
                              context,
                              provider.overallAdherence,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(
        child: EmptyStateWidget(
          icon: Icons.analytics_outlined,
          title: "No Data Yet",
          message:
              "Your health journey begins with the first pill. Start tracking today!",
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.black87,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGradientChart(
    BuildContext context,
    List<double> weeklyData,
    bool isDark,
  ) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF1E293B),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()}%',
                  const TextStyle(
                    color: Color(0xFFFFD700),
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
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final index = value.toInt();
                  if (index >= 0 && index < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        days[index],
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: weeklyData.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 12,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF818CF8),
                      Color(0xFF6366F1),
                    ], // Indigo Gradient
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak, bool isDark) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF43F5E), Color(0xFFE11D48)], // Rose Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak Days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Current Streak',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, double score, bool isDark) {
    Color bgStart = const Color(0xFF10B981); // Emerald
    Color bgEnd = const Color(0xFF059669);
    IconData icon = Icons.check_circle_rounded;
    String title = "Excellent";

    if (score < 80) {
      bgStart = const Color(0xFFF59E0B); // Amber
      bgEnd = const Color(0xFFD97706);
      icon = Icons.trending_up_rounded;
      title = "On Track";
    }
    if (score < 50) {
      bgStart = const Color(
        0xFF6366F1,
      ); // Indigo (Default/Encouraging instead of red)
      bgEnd = const Color(0xFF4F46E5);
      icon = Icons.refresh_rounded;
      title = "Keep Going";
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgEnd.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Overall Status',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdherenceRadialHero extends StatelessWidget {
  final double percentage;
  final bool isDark;

  const _AdherenceRadialHero({required this.percentage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Outer Glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          // 2. Progress Indicator
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage / 100),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 20,
                backgroundColor: isDark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation(
                  Color(0xFF6366F1),
                ), // Indigo
                strokeCap: StrokeCap.round,
              );
            },
          ),
          // 3. Center Text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'ADHERENCE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white38 : Colors.black45,
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
