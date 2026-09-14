import '../core/components/timeline_item.dart';
import 'log.dart';
import 'medicine.dart';
import 'schedule.dart';

enum MedicineStatus { pending, take, skipped, missed }

class ScheduleEntry {
  final Schedule schedule;
  final Medicine medicine;
  final DateTime scheduledDateTime;
  final Log? log;
  final TimelineStatus timelineStatus;
  final MedicineStatus medicineStatus;

  const ScheduleEntry({
    required this.schedule,
    required this.medicine,
    required this.scheduledDateTime,
    required this.log,
    required this.timelineStatus,
    required this.medicineStatus,
  });
}
