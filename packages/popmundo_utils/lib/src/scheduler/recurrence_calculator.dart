import 'package:timezone/timezone.dart' as tz;

import 'scheduler_models.dart';

/// Calendar operations use the database initialized by the platform adapter.
class RecurrenceCalculator {
  DateTime nextAfter(
    ScheduleRecurrence recurrence,
    DateTime now, {
    required String zoneId,
  }) {
    now = now.toUtc();
    if (recurrence is IntervalRecurrence) {
      final duration = recurrence.duration.inMicroseconds;
      final elapsed = now.difference(recurrence.anchorUtc).inMicroseconds;
      final slot = elapsed < 0 ? 1 : elapsed ~/ duration + 1;
      return recurrence.anchorUtc.add(Duration(microseconds: slot * duration));
    }
    final weekly = recurrence as WeeklyRecurrence;
    final location = _location(zoneId);
    final local = tz.TZDateTime.from(now, location);
    // UTC here represents a calendar date, not a 24-hour increment in the zone.
    for (var day = 0; day <= 14; day++) {
      final date = DateTime.utc(local.year, local.month, local.day + day);
      if (!weekly.weekdays.contains(date.weekday)) continue;
      final wall = DateTime.utc(
        date.year,
        date.month,
        date.day,
        weekly.hour,
        weekly.minute,
      );
      final candidate = _resolveWall(wall, location);
      if (candidate.isAfter(now)) return candidate;
    }
    throw const SchedulerException('noFutureOccurrence');
  }

  bool isEligible(ScheduleRecurrence recurrence, DateTime due, DateTime now) {
    final late = now.toUtc().difference(due.toUtc());
    final limit =
        recurrence is IntervalRecurrence &&
            recurrence.duration < const Duration(seconds: 30)
        ? recurrence.duration
        : const Duration(seconds: 30);
    return !late.isNegative && late <= limit;
  }

  String? localSlot(
    ScheduleRecurrence recurrence,
    DateTime plannedUtc, {
    required String zoneId,
  }) {
    if (recurrence is! WeeklyRecurrence) return null;
    final local = tz.TZDateTime.from(plannedUtc, _location(zoneId));
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      recurrence.hour,
      recurrence.minute,
    ).toIso8601String().substring(0, 16);
  }

  tz.Location _location(String zoneId) {
    if (zoneId == "UTC") return tz.UTC;
    try {
      return tz.getLocation(zoneId);
    } catch (_) {
      throw const SchedulerException('zoneUnavailable');
    }
  }

  DateTime _resolveWall(DateTime wall, tz.Location location) {
    // Consider the offsets on both sides of any nearby transition, including
    // 24-hour date-line jumps. Valid copies are sorted so folds use the first.
    final offsets = <Duration>{};
    for (final days in [-2, -1, 0, 1, 2]) {
      offsets.add(
        location
            .timeZone(wall.add(Duration(days: days)).millisecondsSinceEpoch)
            .offset,
      );
    }
    final valid = <DateTime>[];
    DateTime? gapCandidate;
    Duration? smallestShift;
    for (final offset in offsets) {
      final candidate = wall.subtract(offset);
      final local = tz.TZDateTime.from(candidate, location);
      final resolvedWall = DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
      final shift = resolvedWall.difference(wall);
      if (shift == Duration.zero) {
        valid.add(candidate);
      } else if (!shift.isNegative &&
          (smallestShift == null || shift < smallestShift)) {
        smallestShift = shift;
        gapCandidate = candidate;
      }
    }
    if (valid.isNotEmpty) {
      valid.sort();
      return valid.first;
    }
    if (gapCandidate != null) return gapCandidate;
    throw const SchedulerException('zoneUnavailable');
  }
}
