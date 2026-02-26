import 'medicine.dart';
import 'schedule.dart';
import 'log.dart';
import 'snoozed_dose.dart';

/// Captures all medicine-related records for undo after hard delete.
class MedicineDeletionSnapshot {
  final Medicine medicine;
  final List<Schedule> schedules;
  final List<Log> logs;
  final List<SnoozedDose> snoozedDoses;

  const MedicineDeletionSnapshot({
    required this.medicine,
    required this.schedules,
    required this.logs,
    required this.snoozedDoses,
  });
}
