import 'routine.dart';
import 'schedule.dart';
import 'log.dart';
import 'snoozed_dose.dart';

/// Captures all routine-related records for undo after hard delete.
class RoutineDeletionSnapshot {
  final Routine routine;
  final List<Schedule> schedules;
  final List<Log> logs;
  final List<SnoozedDose> snoozedDoses;

  const RoutineDeletionSnapshot({
    required this.routine,
    required this.schedules,
    required this.logs,
    required this.snoozedDoses,
  });
}
