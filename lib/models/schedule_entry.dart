import '../core/components/timeline_item.dart';
import 'log.dart';
import 'routine.dart';
import 'schedule.dart';

enum RoutineStatus { pending, take, skipped, missed }

class ScheduleEntry {
  final Schedule schedule;
  final Routine routine;
  final DateTime scheduledDateTime;
  final Log? log;
  final TimelineStatus timelineStatus;
  final RoutineStatus routineStatus;

  const ScheduleEntry({
    required this.schedule,
    required this.routine,
    required this.scheduledDateTime,
    required this.log,
    required this.timelineStatus,
    required this.routineStatus,
  });
}
