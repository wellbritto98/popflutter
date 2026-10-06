import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  final anchor = DateTime.utc(2026, 10, 4, 12);
  IntervalRecurrence interval([int quantity = 1]) => IntervalRecurrence(
    quantity: quantity,
    unit: IntervalUnit.minutes,
    anchorUtc: anchor,
  );
  ScheduleDraft draft({
    String name = ' Reminder ',
    String title = ' Title ',
    String body = ' Message ',
  }) => ScheduleDraft(
    name: name,
    recurrence: interval(),
    action: LocalNotificationAction(title: title, body: body),
  );
  test('SCHED-02 trims valid text and default is one minute', () {
    expect(draft().name, 'Reminder');
    expect((draft().action as LocalNotificationAction).title, 'Title');
    expect((draft().action as LocalNotificationAction).body, 'Message');
    expect(interval().duration, const Duration(minutes: 1));
  });
  for (final count in [0, 10000]) {
    test(['SCHED-02 rejects count ', count.toString()].join(), () {
      expect(() => interval(count), throwsA(isA<SchedulerException>()));
    });
  }
  test('SCHED-02 accepts inclusive interval bounds', () {
    expect(interval(1).quantity, 1);
    expect(interval(9999).quantity, 9999);
  });
  for (final days in [
    <int>{},
    {0},
    {8},
  ]) {
    test(['SCHED-02 rejects weekdays ', days.toString()].join(), () {
      expect(
        () => WeeklyRecurrence(weekdays: days, hour: 9, minute: 0),
        throwsA(isA<SchedulerException>()),
      );
    });
  }
  for (final time in [
    [-1, 0],
    [24, 0],
    [9, -1],
    [9, 60],
  ]) {
    test(['SCHED-02 rejects time ', time.toString()].join(), () {
      expect(
        () => WeeklyRecurrence(weekdays: {1}, hour: time[0], minute: time[1]),
        throwsA(isA<SchedulerException>()),
      );
    });
  }
  test('SCHED-02 rejects blank and overlong text, accepts exact maxima', () {
    for (final text in [' ', 'a' * 81]) {
      expect(() => draft(name: text), throwsA(isA<SchedulerException>()));
    }
    for (final text in [' ', 'a' * 121]) {
      expect(() => draft(title: text), throwsA(isA<SchedulerException>()));
    }
    for (final text in [' ', 'a' * 1001]) {
      expect(() => draft(body: text), throwsA(isA<SchedulerException>()));
    }
    expect(
      draft(name: 'a' * 80, title: 'a' * 120, body: 'a' * 1000).name.length,
      80,
    );
    expect(
      (draft(title: 'a' * 120).action as LocalNotificationAction).title.length,
      120,
    );
    expect(
      (draft(body: 'a' * 1000).action as LocalNotificationAction).body.length,
      1000,
    );
  });
  test('SCHED-02 trimmed UTF-16 maxima preserve exact snapshot payload', () {
    final name = '\u{1f600}' * 40; // 80 UTF-16 code units.
    final title = '\u{1f680}' * 60; // 120 UTF-16 code units.
    final body = '\u{1f514}' * 500; // 1000 UTF-16 code units.
    final accepted = draft(
      name: ' \t$name\n ',
      title: ' \t$title\n ',
      body: ' \t$body\n ',
    );
    final rule = ScheduledRule(
      id: 'schedule-1',
      revision: 1,
      notificationId: -1,
      name: accepted.name,
      enabled: false,
      recurrence: accepted.recurrence,
      action: accepted.action,
    );
    final expectedAction = {
      'type': 'localNotification',
      'title': title,
      'body': body,
    };
    expect(accepted.name, name);
    expect(accepted.action.toJson(), expectedAction);
    expect(rule.toJson()['name'], name);
    expect(rule.toJson()['action'], expectedAction);
    final restored = SchedulerSnapshot.decode(
      SchedulerSnapshot(nextSequence: 2, rules: [rule]).encode(),
    ).rules.single;
    expect(restored.name, name);
    expect(restored.action.toJson(), expectedAction);
  });
  for (final (field, emojiCount) in [
    ('name', 41),
    ('title', 61),
    ('body', 501),
  ]) {
    test('SCHED-02 rejects overlong UTF-16 $field without truncation', () {
      final text = ' \t${'\u{1f600}' * emojiCount}\n ';
      expect(
        () => switch (field) {
          'name' => draft(name: text),
          'title' => draft(title: text),
          _ => draft(body: text),
        },
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'invalidText',
          ),
        ),
      );
    });
  }
  test('T1 exact immutable snapshot roundtrip includes every cursor field', () {
    final due = anchor.add(const Duration(minutes: 1));
    final rule = ScheduledRule(
      id: 'schedule-1',
      revision: 3,
      notificationId: -1,
      name: 'Reminder',
      enabled: true,
      recurrence: interval(),
      action: LocalNotificationAction(title: 'Title', body: 'Message'),
      nextDueUtc: due,
      zoneId: 'UTC',
      lastClaim: ScheduleClaim(
        revision: 3,
        plannedUtc: due,
        localSlot: '2026-10-04T12:01',
      ),
      lastResult: ScheduleResult(
        status: ScheduleResultStatus.failed,
        atUtc: due,
        errorCode: 'permissionDenied',
      ),
    );
    final decoded = SchedulerSnapshot.decode(
      SchedulerSnapshot(nextSequence: 2, rules: [rule]).encode(),
    );
    expect(decoded.toJson(), {
      'schemaVersion': 1,
      'nextSequence': 2,
      'rules': [
        {
          'id': 'schedule-1',
          'revision': 3,
          'notificationId': -1,
          'name': 'Reminder',
          'enabled': true,
          'recurrence': {
            'type': 'interval',
            'quantity': 1,
            'unit': 'minutes',
            'anchorUtc': '2026-10-04T12:00:00.000Z',
          },
          'action': {
            'type': 'localNotification',
            'title': 'Title',
            'body': 'Message',
          },
          'nextDueUtc': '2026-10-04T12:01:00.000Z',
          'zoneId': 'UTC',
          'lastClaim': {
            'revision': 3,
            'plannedUtc': '2026-10-04T12:01:00.000Z',
            'localSlot': '2026-10-04T12:01',
          },
          'lastResult': {
            'status': 'failed',
            'atUtc': '2026-10-04T12:01:00.000Z',
            'errorCode': 'permissionDenied',
          },
        },
      ],
    });
    expect(() => decoded.rules.clear(), throwsUnsupportedError);
    expect(
      WeeklyRecurrence.fromJson({
        'type': 'weekly',
        'weekdays': [4, 1],
        'hour': 9,
        'minute': 30,
      }).toJson(),
      {
        'type': 'weekly',
        'weekdays': [1, 4],
        'hour': 9,
        'minute': 30,
      },
    );
  });
  test(
    'SCHED-07 negative int32 identity and sequence exhaustion/no recycling',
    () {
      expect(SchedulerSnapshot().nextNotificationId, -1);
      expect(
        SchedulerSnapshot(nextSequence: 2147483648).nextNotificationId,
        -2147483648,
      );
      expect(
        () => SchedulerSnapshot(nextSequence: 2147483649).nextNotificationId,
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'idExhausted',
          ),
        ),
      );
      expect(
        SchedulerSnapshot.decode(SchedulerSnapshot(nextSequence: 7).encode())
            .nextNotificationId,
        -7,
      );
    },
  );
  test(
    'SCHED-09 corrupt/unknown schemas and duplicate identities fail closed',
    () {
      for (final raw in [
        'not json',
        '{}',
        '{"schemaVersion":2,"nextSequence":1,"rules":[]}',
        '{"schemaVersion":1,"nextSequence":1.5,"rules":[]}',
      ]) {
        expect(
          () => SchedulerSnapshot.decode(raw),
          throwsA(isA<SchedulerException>()),
        );
      }
      final rule = ScheduledRule(
        id: 'schedule-1',
        revision: 1,
        notificationId: -1,
        name: 'Reminder',
        enabled: false,
        recurrence: interval(),
        action: LocalNotificationAction(title: 'Title', body: 'Message'),
      );
      expect(
        () => SchedulerSnapshot(nextSequence: 2, rules: [rule, rule]),
        throwsA(isA<SchedulerException>()),
      );
      expect(
        () => SchedulerSnapshot(
          nextSequence: 3,
          rules: [
            rule,
            ScheduledRule.fromJson({...rule.toJson(), 'id': 'schedule-2'}),
          ],
        ),
        throwsA(isA<SchedulerException>()),
      );
      expect(
        () => SchedulerSnapshot(
          nextSequence: 3,
          rules: [
            rule,
            ScheduledRule.fromJson({...rule.toJson(), 'notificationId': -2}),
          ],
        ),
        throwsA(isA<SchedulerException>()),
      );
      for (final bad in [0, 1, -2147483649]) {
        expect(
          () =>
              ScheduledRule.fromJson({...rule.toJson(), 'notificationId': bad}),
          throwsA(isA<SchedulerException>()),
        );
      }
      expect(
        () => SchedulerSnapshot(nextSequence: 1, rules: [rule]),
        throwsA(isA<SchedulerException>()),
      );
    },
  );
}
