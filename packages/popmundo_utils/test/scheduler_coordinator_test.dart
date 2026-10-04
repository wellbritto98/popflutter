import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class TestStore implements SchedulerStore {
  String? raw;
  bool fail = false;
  bool failAfterWrite = false;
  int? failWrite;
  int writes = 0;
  final snapshots = <SchedulerSnapshot>[];
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String value) async {
    writes++;
    if (fail || failWrite == writes) throw StateError('storage');
    raw = value;
    if (failAfterWrite) throw StateError("uncertain");
    snapshots.add(SchedulerSnapshot.decode(value));
  }
}

class TestExecutor implements ScheduledActionExecutor {
  final payloads = <Map<String, Object?>>[];
  Future<void> Function(int)? onExecute;
  @override
  Future<void> execute({
    required LocalNotificationAction action,
    required int notificationId,
  }) async {
    payloads.add({
      'id': notificationId,
      'title': action.title,
      'body': action.body,
    });
    await onExecute?.call(notificationId);
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final anchor = DateTime.utc(2026, 10, 4, 12);
  late DateTime now;
  late String zone;
  late TestStore store;
  late TestExecutor executor;
  late SchedulerCoordinator coordinator;
  ScheduleDraft draft({
    String name = 'Reminder',
    String title = 'Title',
    ScheduleRecurrence? recurrence,
    bool enabled = true,
  }) => ScheduleDraft(
    name: name,
    enabled: enabled,
    recurrence:
        recurrence ??
        IntervalRecurrence(
          quantity: 10,
          unit: IntervalUnit.seconds,
          anchorUtc: anchor,
        ),
    action: LocalNotificationAction(title: title, body: 'Message'),
  );
  SchedulerCoordinator fresh() => SchedulerCoordinator(
    store: store,
    executors: {'localNotification': executor},
    now: () => now,
    zoneId: () => zone,
  );
  SchedulerSnapshot saved() => SchedulerSnapshot.decode(store.raw!);
  setUp(() {
    now = anchor;
    zone = 'UTC';
    store = TestStore();
    executor = TestExecutor();
    coordinator = fresh();
  });
  test('SCHED-03 save returns exact authoritative persisted state', () async {
    final snapshot = await coordinator.create(draft(), id: 'one');
    expect(snapshot.toJson(), saved().toJson());
    final rule = snapshot.rules.single;
    expect(
      [rule.id, rule.revision, rule.notificationId, rule.name, rule.enabled],
      ['one', 1, -1, 'Reminder', true],
    );
    expect(rule.action.toJson(), {
      'type': 'localNotification',
      'title': 'Title',
      'body': 'Message',
    });
    expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 10)));
    expect(rule.lastResult.status, ScheduleResultStatus.neverExecuted);
    expect(snapshot.nextSequence, 2);
    expect((await coordinator.list()).toJson(), saved().toJson());
  });
  test(
    'SCHED-06 restart :35 and exact due skip everything without notifications',
    () async {
      await coordinator.create(draft(), id: 'one');
      now = anchor.add(const Duration(seconds: 35));
      final restored = await fresh().load();
      expect(executor.payloads, isEmpty);
      expect(
        restored.rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 40)),
      );
      expect(
        saved().rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 40)),
      );
      now = anchor.add(const Duration(seconds: 40));
      expect(
        (await fresh().load()).rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 50)),
      );
      expect(executor.payloads, isEmpty);
    },
  );
  test(
    'SCHED-04/07 :10/:20 submit saved payload with stable card and no drift',
    () async {
      await coordinator.create(draft(), id: 'one');
      now = anchor.add(const Duration(seconds: 10));
      await coordinator.reconcile();
      now = anchor.add(const Duration(seconds: 20));
      final snapshot = await coordinator.reconcile();
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
        {'id': -1, 'title': 'Title', 'body': 'Message'},
      ]);
      expect(
        snapshot.rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 30)),
      );
      expect(
        snapshot.rules.single.lastClaim!.plannedUtc,
        anchor.add(const Duration(seconds: 20)),
      );
      expect(
        snapshot.rules.single.lastResult.status,
        ScheduleResultStatus.submitted,
      );
      expect(snapshot.rules.single.lastResult.atUtc, now);
      expect(snapshot.rules.single.lastResult.errorCode, isNull);
    },
  );
  test(
    'SCHED-06 active overdue beyond bound skips, inclusive bound attempts one',
    () async {
      await coordinator.create(draft(), id: 'one');
      now = anchor.add(const Duration(seconds: 20, microseconds: 1));
      expect(
        (await coordinator.reconcile()).rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 30)),
      );
      expect(executor.payloads, isEmpty);
      now = anchor.add(const Duration(seconds: 40));
      expect(
        (await coordinator.reconcile()).rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 50)),
      );
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
      ]);
    },
  );
  test(
    'SCHED-03 text preserves cadence, recurrence change resets from now',
    () async {
      await coordinator.create(draft(), id: 'one');
      now = anchor.add(const Duration(seconds: 5));
      final edited = (await coordinator.update(
        'one',
        draft(name: 'Edited', title: 'New'),
        expectedRevision: 1,
      )).rules.single;
      expect(
        [
          edited.id,
          edited.notificationId,
          edited.revision,
          edited.name,
          edited.action.title,
        ],
        ['one', -1, 2, 'Edited', 'New'],
      );
      expect((edited.recurrence as IntervalRecurrence).anchorUtc, anchor);
      expect(edited.nextDueUtc, anchor.add(const Duration(seconds: 10)));
      final changed = (await coordinator.update(
        'one',
        draft(
          recurrence: IntervalRecurrence(
            quantity: 20,
            unit: IntervalUnit.seconds,
            anchorUtc: anchor,
          ),
        ),
        expectedRevision: 2,
      )).rules.single;
      expect((changed.recurrence as IntervalRecurrence).anchorUtc, now);
      expect(changed.nextDueUtc, anchor.add(const Duration(seconds: 25)));
      expect(changed.notificationId, -1);
    },
  );
  test('SCHED-03 pause and reenable establishes new future anchor', () async {
    await coordinator.create(draft(), id: 'one');
    now = anchor.add(const Duration(seconds: 5));
    final paused = (await coordinator.toggle(
      'one',
      expectedRevision: 1,
      enabled: false,
    )).rules.single;
    expect(paused.enabled, false);
    expect(paused.nextDueUtc, isNull);
    now = anchor.add(const Duration(seconds: 10));
    await coordinator.reconcile();
    expect(executor.payloads, isEmpty);
    final enabled = (await coordinator.toggle(
      'one',
      expectedRevision: 2,
      enabled: true,
    )).rules.single;
    expect(enabled.nextDueUtc, anchor.add(const Duration(seconds: 20)));
    expect((enabled.recurrence as IntervalRecurrence).anchorUtc, now);
    expect(enabled.notificationId, -1);
  });
  test(
    'SCHED-10 stale revisions and unknown identities rejected without mutation',
    () async {
      await coordinator.create(draft(), id: 'one');
      final before = store.raw;
      for (final operation in [
        () => coordinator.update('one', draft(), expectedRevision: 0),
        () => coordinator.toggle('one', expectedRevision: 0, enabled: false),
        () => coordinator.delete('one', expectedRevision: 0),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<SchedulerException>().having(
              (e) => e.code,
              'code',
              'revisionConflict',
            ),
          ),
        );
      }
      await expectLater(
        coordinator.delete('absent', expectedRevision: 1),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'ruleNotFound',
          ),
        ),
      );
      await expectLater(
        coordinator.create(draft(), id: 'one'),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'duplicateId',
          ),
        ),
      );
      expect(store.raw, before);
    },
  );
  test('SCHED-07 deleted IDs never recycle after fresh coordinator', () async {
    await coordinator.create(draft(), id: 'one');
    await coordinator.delete('one', expectedRevision: 1);
    expect(saved().rules, isEmpty);
    expect(saved().nextSequence, 2);
    final snapshot = await fresh().create(draft(), id: 'two');
    expect(snapshot.rules.single.notificationId, -2);
    expect(snapshot.nextSequence, 3);
  });
  test(
    'SCHED-09 failed command write never acknowledges or mutates memory',
    () async {
      await coordinator.load();
      store.fail = true;
      await expectLater(
        coordinator.create(draft(), id: 'one'),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'writeFailed',
          ),
        ),
      );
      expect(store.raw, isNull);
      expect(executor.payloads, isEmpty);
      store.fail = false;
      expect((await coordinator.list()).rules, isEmpty);
    },
  );
  test('SCHED-09 failed claim prevents action and reload skips due', () async {
    await coordinator.create(draft(), id: 'one');
    now = anchor.add(const Duration(seconds: 10));
    store.fail = true;
    await expectLater(
      coordinator.reconcile(),
      throwsA(
        isA<SchedulerException>().having((e) => e.code, 'code', 'writeFailed'),
      ),
    );
    expect(executor.payloads, isEmpty);
    expect(saved().rules.single.lastClaim, isNull);
    store.fail = false;
    expect(
      (await coordinator.reconcile()).rules.single.nextDueUtc,
      anchor.add(const Duration(seconds: 20)),
    );
    expect(executor.payloads, isEmpty);
  });
  test('SCHED-10 durable claim exists before action starts', () async {
    await coordinator.create(draft(), id: 'one');
    now = anchor.add(const Duration(seconds: 10));
    executor.onExecute = (_) async {
      final rule = saved().rules.single;
      expect(rule.lastClaim!.revision, 1);
      expect(rule.lastClaim!.plannedUtc, now);
      expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 20)));
    };
    await coordinator.reconcile();
    expect(
      saved().rules.single.lastResult.status,
      ScheduleResultStatus.submitted,
    );
  });
  test(
    'SCHED-09 failed action continues separate rule and never retries',
    () async {
      await coordinator.create(draft(), id: 'one');
      await coordinator.create(draft(title: 'Second'), id: 'two');
      executor.onExecute = (id) async {
        if (id == -1) throw const SchedulerException('permissionDenied');
      };
      now = anchor.add(const Duration(seconds: 10));
      final snapshot = await coordinator.reconcile();
      expect(snapshot.rules[0].lastResult.status, ScheduleResultStatus.failed);
      expect(snapshot.rules[0].lastResult.errorCode, 'permissionDenied');
      expect(
        snapshot.rules[1].lastResult.status,
        ScheduleResultStatus.submitted,
      );
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
        {'id': -2, 'title': 'Second', 'body': 'Message'},
      ]);
      await coordinator.reconcile();
      expect(executor.payloads.length, 2);
      expect(snapshot.rules.map((r) => r.nextDueUtc), [
        anchor.add(const Duration(seconds: 20)),
        anchor.add(const Duration(seconds: 20)),
      ]);
    },
  );
  test(
    'SCHED-09 five-second timeout is failed uncertain and does not retry',
    () async {
      await coordinator.create(draft(), id: 'one');
      executor.onExecute = (_) => Completer<void>().future;
      now = anchor.add(const Duration(seconds: 10));
      final elapsed = Stopwatch()..start();
      final rule = (await coordinator.reconcile()).rules.single;
      expect(rule.lastResult.status, ScheduleResultStatus.failed);
      expect(rule.lastResult.errorCode, 'actionTimeout');
      expect(elapsed.elapsed, greaterThanOrEqualTo(const Duration(seconds: 5)));
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 7)));
      await coordinator.reconcile();
      expect(executor.payloads.length, 1);
      expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 20)));
    },
  );
  test(
    'SCHED-09 failed result write is uncertain, fresh load drops pending claim',
    () async {
      await coordinator.create(draft(), id: 'one');
      store.failWrite = store.writes + 2;
      now = anchor.add(const Duration(seconds: 10));
      await expectLater(
        coordinator.reconcile(),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'resultUncertain',
          ),
        ),
      );
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
      ]);
      final restored = (await fresh().load()).rules.single;
      expect(
        restored.lastResult.status,
        ScheduleResultStatus.skippedInterrupted,
      );
      expect(restored.lastClaim, isNull);
      expect(restored.nextDueUtc, anchor.add(const Duration(seconds: 20)));
      await fresh().reconcile();
      expect(executor.payloads.length, 1);
    },
  );
  test(
    'SCHED-10 overlapping commands and ticks have no lost updates/duplicates',
    () async {
      await Future.wait([
        coordinator.create(draft(), id: 'one'),
        coordinator.create(draft(title: 'Second'), id: 'two'),
      ]);
      now = anchor.add(const Duration(seconds: 10));
      await Future.wait([
        coordinator.reconcile(),
        coordinator.reconcile(),
        coordinator.update('one', draft(name: 'Edited'), expectedRevision: 1),
      ]);
      expect(executor.payloads.length, 2);
      final rules = saved().rules;
      expect(rules.map((r) => [r.id, r.name, r.notificationId, r.revision]), [
        ['one', 'Edited', -1, 2],
        ['two', 'Reminder', -2, 1],
      ]);
      expect(rules.map((r) => r.nextDueUtc), [
        anchor.add(const Duration(seconds: 20)),
        anchor.add(const Duration(seconds: 20)),
      ]);
    },
  );
  test(
    'SCHED-10 completed pause/delete/recurrence edit beats queued tick',
    () async {
      await coordinator.create(draft(), id: 'pause');
      await coordinator.create(draft(), id: 'delete');
      await coordinator.create(draft(), id: 'edit');
      now = anchor.add(const Duration(seconds: 10));
      await Future.wait([
        coordinator.toggle('pause', expectedRevision: 1, enabled: false),
        coordinator.delete('delete', expectedRevision: 1),
        coordinator.update(
          'edit',
          draft(
            recurrence: IntervalRecurrence(
              quantity: 20,
              unit: IntervalUnit.seconds,
              anchorUtc: anchor,
            ),
          ),
          expectedRevision: 1,
        ),
        coordinator.reconcile(),
      ]);
      expect(executor.payloads, isEmpty);
      expect(saved().rules.map((r) => [r.id, r.enabled, r.nextDueUtc]), [
        ['pause', false, null],
        ['edit', true, anchor.add(const Duration(seconds: 30))],
      ]);
    },
  );
  test('SCHED-05 unknown zone preserves weekly but intervals continue and zone changes rearm', () async {
    now = DateTime.utc(2026, 10, 5, 8);
    await coordinator.create(draft(), id: 'interval');
    await coordinator.create(
      draft(recurrence: WeeklyRecurrence(weekdays: {1}, hour: 9, minute: 0)),
      id: 'weekly',
    );
    zone = 'Unknown/Zone';
    now = now.add(const Duration(seconds: 10));
    final snapshot = await fresh().load();
    expect(snapshot.rules[0].nextDueUtc, now.add(const Duration(seconds: 10)));
    expect(snapshot.rules[1].enabled, true);
    expect(snapshot.rules[1].nextDueUtc, isNull);
    expect(snapshot.rules[1].lastResult.errorCode, 'zoneUnavailable');
    zone = 'America/Sao_Paulo';
    coordinator = fresh();
    final changed = await coordinator.load();
    expect(changed.rules[1].nextDueUtc, DateTime.utc(2026, 10, 5, 12));
    zone = 'Asia/Tokyo';
    expect(
      (await coordinator.reconcile()).rules[1].nextDueUtc,
      DateTime.utc(2026, 10, 12),
    );
    now = now.add(const Duration(seconds: 10));
    await coordinator.reconcile();
    expect(executor.payloads, [
      {'id': -1, 'title': 'Title', 'body': 'Message'},
    ]);
  });
  test(
    'SCHED-09 corrupt persisted blob is preserved, no commands or actions',
    () async {
      store.raw = '{"schemaVersion":99,"rules":[]}';
      final raw = store.raw;
      await expectLater(coordinator.load(), throwsA(isA<SchedulerException>()));
      await expectLater(
        coordinator.create(draft(), id: 'one'),
        throwsA(isA<SchedulerException>()),
      );
      await expectLater(
        coordinator.reconcile(),
        throwsA(isA<SchedulerException>()),
      );
      expect(store.raw, raw);
      expect(store.writes, 0);
      expect(executor.payloads, isEmpty);
    },
  );
  test('SCHED-03/09 uncertain command rereads committed rule and rejects duplicate nonce', () async {
    await coordinator.load();
    store.failAfterWrite = true;
    await expectLater(
      coordinator.create(draft(), id: 'nonce'),
      throwsA(
        isA<SchedulerException>().having((e) => e.code, 'code', 'writeFailed'),
      ),
    );
    expect(saved().rules.single.id, 'nonce');
    store.failAfterWrite = false;
    expect((await coordinator.list()).rules.single.notificationId, -1);
    await expectLater(
      coordinator.create(draft(), id: 'nonce'),
      throwsA(
        isA<SchedulerException>().having((e) => e.code, 'code', 'duplicateId'),
      ),
    );
    expect(saved().nextSequence, 2);
    expect(saved().rules.length, 1);
  });
  test(
    'SCHED-03 action claimed before pause may finish, no later claim',
    () async {
      await coordinator.create(draft(), id: 'one');
      final started = Completer<void>();
      final release = Completer<void>();
      executor.onExecute = (_) async {
        started.complete();
        await release.future;
      };
      now = anchor.add(const Duration(seconds: 10));
      final tick = coordinator.reconcile();
      await started.future;
      final pause = coordinator.toggle(
        'one',
        expectedRevision: 1,
        enabled: false,
      );
      release.complete();
      await tick;
      await pause;
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
      ]);
      expect(
        saved().rules.single.lastResult.status,
        ScheduleResultStatus.submitted,
      );
      expect(saved().rules.single.enabled, false);
      expect(saved().rules.single.nextDueUtc, isNull);
      now = now.add(const Duration(seconds: 10));
      await coordinator.reconcile();
      expect(executor.payloads.length, 1);
    },
  );
  test(
    'SCHED-05 weekly claim remembers intended fold slot across restart',
    () async {
      zone = 'America/New_York';
      now = DateTime.utc(2026, 11, 1, 4);
      await coordinator.create(
        draft(recurrence: WeeklyRecurrence(weekdays: {7}, hour: 1, minute: 30)),
        id: 'weekly',
      );
      now = DateTime.utc(2026, 11, 1, 5, 30);
      final rule = (await coordinator.reconcile()).rules.single;
      expect(rule.lastClaim!.localSlot, '2026-11-01T01:30');
      expect(rule.lastClaim!.plannedUtc, DateTime.utc(2026, 11, 1, 5, 30));
      expect(rule.nextDueUtc, DateTime.utc(2026, 11, 8, 6, 30));
      now = DateTime.utc(2026, 11, 1, 6, 30);
      final restored = (await fresh().load()).rules.single;
      expect(restored.lastResult.status, ScheduleResultStatus.submitted);
      expect(restored.lastClaim!.localSlot, '2026-11-01T01:30');
      expect(restored.nextDueUtc, DateTime.utc(2026, 11, 8, 6, 30));
      expect(executor.payloads, [
        {'id': -1, 'title': 'Title', 'body': 'Message'},
      ]);
    },
  );
  test(
    'SCHED-09 startup drops claim interrupted before platform submission',
    () async {
      await coordinator.create(draft(), id: 'one');
      final value = saved();
      final pending = value.rules.single.copyWith(
        nextDueUtc: anchor.add(const Duration(seconds: 20)),
        lastClaim: ScheduleClaim(
          revision: 1,
          plannedUtc: anchor.add(const Duration(seconds: 10)),
        ),
        lastResult: ScheduleResult(status: ScheduleResultStatus.neverExecuted),
      );
      store.raw = SchedulerSnapshot(nextSequence: 2, rules: [pending]).encode();
      now = anchor.add(const Duration(seconds: 15));
      final restored = (await fresh().load()).rules.single;
      expect(
        restored.lastResult.status,
        ScheduleResultStatus.skippedInterrupted,
      );
      expect(restored.lastResult.atUtc, now);
      expect(restored.lastResult.errorCode, isNull);
      expect(restored.lastClaim, isNull);
      expect(restored.nextDueUtc, anchor.add(const Duration(seconds: 20)));
      expect(executor.payloads, isEmpty);
    },
  );
  test(
    'SCHED-10 backward clock restart never repeats an already claimed UTC slot',
    () async {
      await coordinator.create(draft(), id: 'one');
      now = anchor.add(const Duration(seconds: 10));
      await coordinator.reconcile();
      now = anchor;
      coordinator = fresh();
      expect(
        (await coordinator.load()).rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 20)),
      );
      now = anchor.add(const Duration(seconds: 10));
      await coordinator.reconcile();
      expect(executor.payloads.length, 1);
      now = anchor.add(const Duration(seconds: 20));
      await coordinator.reconcile();
      expect(executor.payloads.length, 2);
      expect(
        saved().rules.single.lastClaim!.plannedUtc,
        anchor.add(const Duration(seconds: 20)),
      );
    },
  );
  test(
    'SCHED-09 backward clock also skips an interrupted future claim',
    () async {
      await coordinator.create(draft(), id: 'one');
      final value = saved();
      store.raw = SchedulerSnapshot(
        nextSequence: 2,
        rules: [
          value.rules.single.copyWith(
            lastClaim: ScheduleClaim(
              revision: 1,
              plannedUtc: anchor.add(const Duration(seconds: 10)),
            ),
            nextDueUtc: anchor.add(const Duration(seconds: 20)),
            lastResult: ScheduleResult(
              status: ScheduleResultStatus.neverExecuted,
            ),
          ),
        ],
      ).encode();
      final snapshot = await fresh().load();
      expect(
        snapshot.rules.single.nextDueUtc,
        anchor.add(const Duration(seconds: 20)),
      );
      expect(
        snapshot.rules.single.lastResult.status,
        ScheduleResultStatus.skippedInterrupted,
      );
      expect(executor.payloads, isEmpty);
    },
  );
  test('SCHED-10 durable attempt watermark roundtrips, migrates and resets only for new cadence', () async {
    await coordinator.create(draft(), id: 'one');
    now = anchor.add(const Duration(seconds: 10));
    await coordinator.reconcile();
    expect(
      saved().rules.single.lastAttemptUtc,
      DateTime.utc(2026, 10, 4, 12, 0, 10),
    );
    expect(
      saved().rules.single.toJson()['lastAttemptUtc'],
      '2026-10-04T12:00:10.000Z',
    );
    await coordinator.update('one', draft(name: 'Text'), expectedRevision: 1);
    expect(
      saved().rules.single.lastAttemptUtc,
      DateTime.utc(2026, 10, 4, 12, 0, 10),
    );
    await coordinator.update(
      'one',
      draft(
        recurrence: IntervalRecurrence(
          quantity: 20,
          unit: IntervalUnit.seconds,
          anchorUtc: anchor,
        ),
      ),
      expectedRevision: 2,
    );
    expect(saved().rules.single.lastAttemptUtc, isNull);
    expect(saved().rules.single.lastClaim, isNull);
    now = anchor.add(const Duration(seconds: 30));
    await coordinator.reconcile();
    await coordinator.toggle('one', expectedRevision: 3, enabled: false);
    expect(
      saved().rules.single.lastAttemptUtc,
      DateTime.utc(2026, 10, 4, 12, 0, 30),
    );
    await coordinator.toggle('one', expectedRevision: 4, enabled: true);
    expect(saved().rules.single.lastAttemptUtc, isNull);
    expect(
      saved().rules.single.nextDueUtc,
      anchor.add(const Duration(seconds: 50)),
    );
    // Schema-1 snapshots preceding this cursor migrate the durable claim.
    final old = saved().rules.single.toJson();
    old.remove('lastAttemptUtc');
    old['lastClaim'] = ScheduleClaim(
      revision: 5,
      plannedUtc: anchor.add(const Duration(seconds: 50)),
    ).toJson();
    old['lastResult'] = ScheduleResult(
      status: ScheduleResultStatus.neverExecuted,
    ).toJson();
    store.raw = SchedulerSnapshot(
      nextSequence: 2,
      rules: [ScheduledRule.fromJson(old)],
    ).encode();
    now = anchor;
    final restored = (await fresh().load()).rules.single;
    expect(restored.lastClaim, isNull);
    expect(restored.lastAttemptUtc, DateTime.utc(2026, 10, 4, 12, 0, 50));
    expect(
      saved().rules.single.lastAttemptUtc,
      DateTime.utc(2026, 10, 4, 12, 0, 50),
    );
    expect(
      (await fresh().load()).rules.single.nextDueUtc,
      DateTime.utc(2026, 10, 4, 12, 1, 10),
    );
  });
}
