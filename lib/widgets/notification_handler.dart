import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import '../screens/main_screen.dart';

class NotificationHandler extends StatefulWidget {
  final Widget child;

  const NotificationHandler({super.key, required this.child});

  @override
  State<NotificationHandler> createState() => _NotificationHandlerState();
}

class _NotificationHandlerState extends State<NotificationHandler> {
  @override
  void initState() {
    super.initState();
    // Set up the listener
    NotificationService.instance.onNotificationAction =
        _handleNotificationAction;
  }

  void _handleNotificationAction(
    int medicineId,
    String action,
    String? payload,
  ) {
    debugPrint('Notification Action: $action for routine $medicineId');
    if (!mounted) return;

    if (action == 'take') {
      final medicineProvider = Provider.of<MedicineProvider>(
        context,
        listen: false,
      );
      final logProvider = Provider.of<LogProvider>(context, listen: false);

      // Mark as done.
      if (payload != null) {
        final parts = payload.split('|');
        if (parts.length > 3) {
          try {
            final originalTime = DateTime.parse(parts[3]);
            final now = DateTime.now();

            // Unified slot-time calculation
            var scheduledTime = DateTime(
              now.year,
              now.month,
              now.day,
              originalTime.hour,
              originalTime.minute,
            );

            // Cross-midnight adjustment
            if (now.hour < 4 && originalTime.hour > 20) {
              scheduledTime = scheduledTime.subtract(const Duration(days: 1));
            }

            debugPrint(
              'Notification Action: marking $medicineId done for $scheduledTime',
            );

            logProvider.markAsTaken(medicineId, scheduledTime).then((_) {
              if (!mounted) return;
              // Reload all data so the dashboard updates
              logProvider.loadLogs();
              medicineProvider.loadMedicines();
              context.read<ScheduleProvider>().loadSchedules();

              // User requested: navigate to home screen on "Take Now" too
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
                );
              }
              debugPrint('Dashboard refresh triggered after notification Done');
            });
          } catch (e) {
            debugPrint('🔴 Error parsing scheduled time: $e');
          }
        }
      }

      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Routine done'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (action == 'snooze') {
      final medicineProvider = Provider.of<MedicineProvider>(
        context,
        listen: false,
      );
      final medicine = medicineProvider.getMedicineById(medicineId);

      if (medicine != null) {
        NotificationService.instance.snoozeNotification(
          notificationId: medicineId,
          medicineId: medicineId,
          medicineName: medicine.name,
          dosage: medicine.dosage,
        );
      }
    } else if (action == 'view') {
      // User tapped the notification body — navigate to home screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
