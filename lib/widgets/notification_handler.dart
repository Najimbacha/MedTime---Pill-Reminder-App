import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';

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
    NotificationService.instance.onNotificationAction = _handleNotificationAction;
  }

  void _handleNotificationAction(int medicineId, String action, String? payload) {
    debugPrint('Notification Action: $action for medicine $medicineId');
    if (!mounted) return;

    if (action == 'take') {
      final medicineProvider = Provider.of<MedicineProvider>(context, listen: false);
      final logProvider = Provider.of<LogProvider>(context, listen: false);

      // 1. Decrement Stock
      medicineProvider.decrementStock(medicineId);
      
      // 2. Mark as Taken (Log it)
      if (payload != null) {
         final parts = payload.split('|');
         if (parts.length > 3) {
            try {
              final scheduledTime = DateTime.parse(parts[3]);
              logProvider.markAsTaken(medicineId, scheduledTime);
              debugPrint('✅ Marked as taken in foreground for $scheduledTime');
            } catch (e) {
              debugPrint('🔴 Error parsing scheduled time: $e');
            }
         } else {
            // Fallback: If no scheduled time, try to find a matching schedule for "now"
            // This is less accurate but better than nothing.
            // Or just logging "now" as scheduled time might be wrong if it mismatches.
            debugPrint('⚠️ Payload missing scheduled time, only stock decremented.');
         }
      }

      // Optional: Show snackbar or visual confirmation if app is in foreground
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine taken! Stock updated.')),
      );
    } else if (action == 'snooze') {
      final medicineProvider = Provider.of<MedicineProvider>(context, listen: false);
      final medicine = medicineProvider.getMedicineById(medicineId);
      
      if (medicine != null) {
         NotificationService.instance.snoozeNotification(
            notificationId: medicineId, 
            medicineId: medicineId,
            medicineName: medicine.name,
            dosage: medicine.dosage,
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
