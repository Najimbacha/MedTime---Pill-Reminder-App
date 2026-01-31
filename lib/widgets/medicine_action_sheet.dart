import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../providers/snooze_provider.dart';
import '../utils/haptic_helper.dart';
import '../core/theme/app_colors.dart';
import '../utils/time_picker_sheet.dart';

/// Action sheet for medicine dose actions
/// Provides Take, Snooze (15min, 1hr, custom), and Skip options
class MedicineActionSheet extends StatelessWidget {
  final Medicine medicine;
  final DateTime scheduledTime;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  const MedicineActionSheet({
    super.key,
    required this.medicine,
    required this.scheduledTime,
    required this.onTake,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snoozeProvider = context.read<SnoozeProvider>();
    final isSnoozed = snoozeProvider.isSnoozed(medicine.id!, scheduledTime);
    final snoozedUntil = snoozeProvider.getSnoozedTimeFor(
      medicine.id!,
      scheduledTime,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: medicine.colorValue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  medicine.iconAssetPath,
                  color: medicine.colorValue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (medicine.dosage.isNotEmpty)
                      Text(
                        medicine.dosage,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    // Show snoozed badge if applicable
                    if (isSnoozed && snoozedUntil != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.snooze,
                              size: 14,
                              color: isDark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Snoozed until ${TimeOfDay.fromDateTime(snoozedUntil).format(context)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action 1: Take Now (Primary)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Cancel snooze if there was one
              if (isSnoozed) {
                snoozeProvider.cancelSnooze(
                  medicineId: medicine.id!,
                  originalScheduledTime: scheduledTime,
                );
              }
              onTake();
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Take Now'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: Snooze or Cancel Snooze
          if (isSnoozed)
            // Show Cancel Snooze button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                snoozeProvider.cancelSnooze(
                  medicineId: medicine.id!,
                  originalScheduledTime: scheduledTime,
                );
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Snooze'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade700,
                side: BorderSide(color: Colors.amber.shade400),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else
            // Show Snooze options
            Row(
              children: [
                Expanded(
                  child: _SnoozeButton(
                    label: '15 Min',
                    icon: Icons.snooze,
                    onTap: () => _snooze(context, 15),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SnoozeButton(
                    label: '1 Hour',
                    icon: Icons.history,
                    onTap: () => _snooze(context, 60),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SnoozeButton(
                    label: 'Custom',
                    icon: Icons.edit_calendar,
                    onTap: () => _customSnooze(context),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Action 3: Skip (Tertiary)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Cancel snooze if there was one
              if (isSnoozed) {
                snoozeProvider.cancelSnooze(
                  medicineId: medicine.id!,
                  originalScheduledTime: scheduledTime,
                );
              }
              onSkip();
            },
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            label: const Text('Skip this dose'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white54 : Colors.grey[600],
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _snooze(BuildContext context, int minutes) async {
    final snoozeProvider = context.read<SnoozeProvider>();
    await snoozeProvider.snoozeDose(
      medicineId: medicine.id!,
      medicineName: medicine.name,
      originalScheduledTime: scheduledTime,
      minutes: minutes,
    );
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _customSnooze(BuildContext context) async {
    Navigator.pop(context);

    // Calculate initial time (30 minutes from now)
    final now = DateTime.now();
    final later = now.add(const Duration(minutes: 30));
    final initialTime = TimeOfDay.fromDateTime(later);

    final TimeOfDay? picked = await TimePickerSheet.show(context, initialTime);

    if (picked != null && context.mounted) {
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      // If picked time is before now, assume tomorrow
      var diff = dt.difference(now).inMinutes;
      if (diff < 0) diff += 1440; // Add 24h

      if (diff > 0) {
        final snoozeProvider = context.read<SnoozeProvider>();
        snoozeProvider.snoozeDose(
          medicineId: medicine.id!,
          medicineName: medicine.name,
          originalScheduledTime: scheduledTime,
          minutes: diff,
        );
      }
    }
  }
}

class _SnoozeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _SnoozeButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDark ? Colors.amber.shade300 : Colors.orange.shade800,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
