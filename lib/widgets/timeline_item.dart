import 'package:flutter/material.dart';
import 'dart:io';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../models/log.dart';

/// Timeline item showing a scheduled medicine
class TimelineItem extends StatelessWidget {
  final Medicine medicine;
  final Schedule schedule;
  final bool isLogged;
  final LogStatus? logStatus;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  const TimelineItem({
    super.key,
    required this.medicine,
    required this.schedule,
    required this.isLogged,
    this.logStatus,
    required this.onTake,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time indicator
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.timeOfDay,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schedule.frequencyType != FrequencyType.daily)
                  Text(
                    schedule.frequencyDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179),
                    ),
                  ),
              ],
            ),
          ),

          // Timeline line
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(),
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: _getStatusIcon(),
              ),
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Medicine card
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'med-icon-${medicine.id}',
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: medicine.colorValue.withAlpha(38),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: medicine.imagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(medicine.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    medicine.icon,
                                    color: medicine.colorValue,
                                    size: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                medicine.dosage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(179),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isLogged) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onTake,
                              icon: const Icon(Icons.check, size: 24),
                              label: const Text(
                                'Take',
                                style: TextStyle(fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onSkip,
                              icon: const Icon(Icons.close, size: 24),
                              label: const Text(
                                'Skip',
                                style: TextStyle(fontSize: 18),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getLogStatusIcon(),
                                color: _getStatusColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                logStatus?.name.toUpperCase() ?? 'PENDING',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!isLogged) return Colors.grey.withAlpha(128);
    switch (logStatus) {
      case LogStatus.take:
        return const Color(0xFF66BB6A); // Success Green
      case LogStatus.skip:
        return const Color(0xFFFFA726); // Warning Orange
      case LogStatus.missed:
        return const Color(0xFFEF5350); // Error Red
      default:
        return Colors.grey;
    }
  }

  Widget? _getStatusIcon() {
    if (!isLogged) return null;
    IconData iconData;
    switch (logStatus) {
      case LogStatus.take:
        iconData = Icons.check;
        break;
      case LogStatus.skip:
        iconData = Icons.close;
        break;
      case LogStatus.missed:
        iconData = Icons.warning;
        break;
      default:
        return null;
    }
    return Icon(
      iconData,
      color: Colors.white,
      size: 16,
    );
  }

  IconData _getLogStatusIcon() {
    switch (logStatus) {
      case LogStatus.take:
        return Icons.check_circle;
      case LogStatus.skip:
        return Icons.cancel;
      case LogStatus.missed:
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}
