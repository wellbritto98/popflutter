import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final calculator = RecurrenceCalculator();
  final anchor = DateTime.utc(2026, 10, 4, 12);
  final interval = IntervalRecurrence(
    quantity: 10,
    unit: IntervalUnit.seconds,
    anchorUtc: anchor,
  );
  DateTime next(
    ScheduleRecurrence recurrence,
    DateTime now, [
    String zone = 'UTC',
  ]) => calculator.nextAfter(recurrence, now, zoneId: zone);
  test(
    'SCHED-04/06 intervals stay anchored and skip exact/past restart slots',
    () {
      expect(next(interval, anchor), DateTime.utc(2026, 10, 4, 12, 0, 10));
      expect(
        next(interval, anchor.add(const Duration(seconds: 10))),
        DateTime.utc(2026, 10, 4, 12, 0, 20),
      );
      expect(
        next(interval, anchor.add(const Duration(seconds: 35))),
        DateTime.utc(2026, 10, 4, 12, 0, 40),
      );
      expect(
        next(interval, anchor.subtract(const Duration(seconds: 1))),
        DateTime.utc(2026, 10, 4, 12, 0, 10),
      );
    },
  );
  test('SCHED-04 a day is 24 elapsed hours through DST', () {
    final day = IntervalRecurrence(
      quantity: 1,
      unit: IntervalUnit.days,
      anchorUtc: DateTime.utc(2026, 3, 7, 14),
    );
    expect(
      next(day, day.anchorUtc, 'America/New_York'),
      DateTime.utc(2026, 3, 8, 14),
    );
  });
  test('SCHED-05 Monday/Thursday strict future boundary', () {
    final weekly = WeeklyRecurrence(weekdays: {1, 4}, hour: 9, minute: 0);
    expect(
      next(weekly, DateTime.utc(2026, 10, 5, 8, 59)),
      DateTime.utc(2026, 10, 5, 9),
    );
    expect(
      next(weekly, DateTime.utc(2026, 10, 5, 9)),
      DateTime.utc(2026, 10, 8, 9),
    );
    expect(
      next(weekly, DateTime.utc(2026, 10, 8, 9)),
      DateTime.utc(2026, 10, 12, 9),
    );
  });
  test('SCHED-05 spring gap 02:30 shifts to 03:30 New York', () {
    final weekly = WeeklyRecurrence(weekdays: {7}, hour: 2, minute: 30);
    final due = next(weekly, DateTime.utc(2026, 3, 8, 5), 'America/New_York');
    expect(due, DateTime.utc(2026, 3, 8, 7, 30));
    expect(
      calculator.localSlot(weekly, due, zoneId: 'America/New_York'),
      '2026-03-08T02:30',
    );
    expect(
      next(weekly, due, 'America/New_York'),
      DateTime.utc(2026, 3, 15, 6, 30),
    );
  });
  test('SCHED-05 autumn fold picks first 01:30 and never the second copy', () {
    final weekly = WeeklyRecurrence(weekdays: {7}, hour: 1, minute: 30);
    expect(
      next(weekly, DateTime.utc(2026, 11, 1, 4), 'America/New_York'),
      DateTime.utc(2026, 11, 1, 5, 30),
    );
    expect(
      next(weekly, DateTime.utc(2026, 11, 1, 5, 30), 'America/New_York'),
      DateTime.utc(2026, 11, 8, 6, 30),
    );
    expect(
      next(weekly, DateTime.utc(2026, 11, 1, 6), 'America/New_York'),
      DateTime.utc(2026, 11, 8, 6, 30),
    );
  });
  test('SCHED-05 zone change and local year crossing', () {
    final weekly = WeeklyRecurrence(weekdays: {1}, hour: 9, minute: 0);
    final now = DateTime.utc(2026, 10, 5, 8);
    expect(
      next(weekly, now, 'America/Sao_Paulo'),
      DateTime.utc(2026, 10, 5, 12),
    );
    expect(next(weekly, now, 'Asia/Tokyo'), DateTime.utc(2026, 10, 12));
    expect(
      next(
        WeeklyRecurrence(weekdays: {5}, hour: 0, minute: 10),
        DateTime.utc(2026, 12, 31, 23, 59),
      ),
      DateTime.utc(2027, 1, 1, 0, 10),
    );
  });
  test('SCHED-06 lateness is inclusive min(30s,D), never early', () {
    final due = anchor.add(const Duration(seconds: 10));
    expect(
      calculator.isEligible(
        interval,
        due,
        due.subtract(const Duration(microseconds: 1)),
      ),
      false,
    );
    expect(calculator.isEligible(interval, due, due), true);
    expect(
      calculator.isEligible(
        interval,
        due,
        due.add(const Duration(seconds: 10)),
      ),
      true,
    );
    expect(
      calculator.isEligible(
        interval,
        due,
        due.add(const Duration(seconds: 10, microseconds: 1)),
      ),
      false,
    );
    final minute = IntervalRecurrence(anchorUtc: anchor);
    expect(
      calculator.isEligible(minute, due, due.add(const Duration(seconds: 30))),
      true,
    );
    expect(
      calculator.isEligible(
        minute,
        due,
        due.add(const Duration(seconds: 30, microseconds: 1)),
      ),
      false,
    );
  });
  test('SCHED-06 weekly lateness inclusive 30 seconds', () {
    final weekly = WeeklyRecurrence(weekdays: {1}, hour: 9, minute: 0);
    expect(
      calculator.isEligible(
        weekly,
        anchor,
        anchor.add(const Duration(seconds: 30)),
      ),
      true,
    );
    expect(
      calculator.isEligible(
        weekly,
        anchor,
        anchor.add(const Duration(seconds: 30, microseconds: 1)),
      ),
      false,
    );
  });
  test('SCHED-05 unknown current IANA zone is unavailable', () {
    expect(
      () => next(
        WeeklyRecurrence(weekdays: {1}, hour: 9, minute: 0),
        anchor,
        'Unknown/Zone',
      ),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'zoneUnavailable',
        ),
      ),
    );
    expect(
      next(interval, anchor, 'Unknown/Zone'),
      DateTime.utc(2026, 10, 4, 12, 0, 10),
    );
  });
}
