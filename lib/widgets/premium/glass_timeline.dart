import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../glass_container.dart';

class GlassTimeline extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool isDark;

  const GlassTimeline({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isDark,
  });

  @override
  State<GlassTimeline> createState() => _GlassTimelineState();
}

class _GlassTimelineState extends State<GlassTimeline> {
  late ScrollController _scrollController;
  final List<DateTime> _dates = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _generateDates();

    // Scroll to selected date after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(widget.selectedDate);
    });
  }

  void _generateDates() {
    final now = DateTime.now();
    // Generate 14 days before and 14 days after today
    for (int i = -14; i <= 14; i++) {
      _dates.add(now.add(Duration(days: i)));
    }
  }

  void _scrollToDate(DateTime date) {
    final index = _dates.indexWhere(
      (d) => d.day == date.day && d.month == date.month && d.year == date.year,
    );
    if (index != -1 && _scrollController.hasClients) {
      // 60 is item width, 12 is margin => 72 total width per item
      final offset =
          (index * 72.0) - (MediaQuery.of(context).size.width / 2) + 36;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected =
              date.day == widget.selectedDate.day &&
              date.month == widget.selectedDate.month &&
              date.year == widget.selectedDate.year;

          return GestureDetector(
            onTap: () {
              widget.onDateSelected(date);
              _scrollToDate(date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 60,
              child: Stack(
                children: [
                  // The Glass Capsule
                  GlassContainer(
                    width: 60,
                    height: 100,
                    borderRadius: 30,
                    blur: 10,
                    opacity: isSelected ? 0.2 : 0.05,
                    border: isSelected
                        ? Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.5),
                            width: 1.5,
                          )
                        : null,
                    color: isSelected
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: isSelected
                              ? BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                )
                              : null,
                          alignment: Alignment.center,
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (widget.isDark
                                        ? Colors.white
                                        : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Today Dot
                  if (DateFormat('yyyyMMdd').format(date) ==
                      DateFormat('yyyyMMdd').format(DateTime.now()))
                    Positioned(
                      top: 12,
                      right: 0,
                      left: 0,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981), // Emerald
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
