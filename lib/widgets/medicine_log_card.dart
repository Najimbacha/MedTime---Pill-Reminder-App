import 'package:flutter/material.dart';
import '../models/log.dart';
import '../utils/common_medicines.dart';

class MedicineLogCard extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final LogStatus status;
  final DateTime scheduledTime;
  final int colorValue;
  final String? iconAssetPath;
  final String? medicineType;

  const MedicineLogCard({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.status,
    required this.scheduledTime,
    required this.colorValue,
    this.iconAssetPath,
    this.medicineType,
  });

  bool get isCompleted => status == LogStatus.take;
  bool get isSkipped => status == LogStatus.skip;
  bool get isMissed => status == LogStatus.missed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicineColor = Color(colorValue);

    final cardGradient = isDark
        ? [const Color(0xFF1E1E2E), const Color(0xFF181825)]
        : [Colors.white, const Color(0xFFFAFAFA)];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCompleted
              ? (isDark
                  ? [const Color(0xFF1A2E1A), const Color(0xFF162516)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFE8F5E9)])
              : (isMissed
                  ? (isDark
                      ? [const Color(0xFF2E1A1A), const Color(0xFF251616)]
                      : [const Color(0xFFFDF0F0), const Color(0xFFF9E8E8)])
                  : cardGradient),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withOpacity(0.3)
              : (isMissed
                  ? Colors.red.withOpacity(0.3)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04))),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF10B981).withOpacity(0.15)
                  : (isMissed
                      ? Colors.red.withOpacity(0.15)
                      : medicineColor.withOpacity(0.15)),
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 28)
                : (isMissed
                    ? const Icon(Icons.error_rounded,
                        color: Colors.red, size: 28)
                    : (iconAssetPath != null
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(iconAssetPath!,
                                color: medicineColor),
                          )
                        : Icon(Icons.medication_rounded,
                            color: medicineColor, size: 24))),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicineName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration:
                        isSkipped ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dosage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(scheduledTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status Pill
          _buildStatusPill(context, status),
        ],
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, LogStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case LogStatus.take:
        color = const Color(0xFF10B981);
        text = 'TAKEN';
        icon = Icons.check;
        break;
      case LogStatus.skip:
        color = Colors.orange;
        text = 'SKIPPED';
        icon = Icons.fast_forward_rounded;
        break;
      case LogStatus.missed:
        color = Colors.red;
        text = 'MISSED';
        icon = Icons.close;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    // Simple formatter to avoid intl import dependency if possible, or use TimeOfDay
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
