import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';

import 'scheduler_runtime_test.dart' show Store, Action;

void main() {
  test('reversed concurrent replies, remote codes and corrupt responses are isolated', () async {
    final sent = <Map<String, Object?>>[];
    void Function(Object)? listener;
    final client = SchedulerClient(
      send: sent.add,
      addListener: (cb) => listener = cb,
      removeListener: (_) {},
      ensureRunning: () async {},
    );
    final first = client.list();
    final second = client.list();
    await Future<void>.delayed(Duration.zero);
    expect(sent[0]['requestId'], isNot(sent[1]['requestId']));
    listener!({
      'type': 'scheduler.response',
      'requestId': sent[1]['requestId'],
      'snapshot': SchedulerSnapshot(nextSequence: 2).toJson(),
    });
    listener!({
      'type': 'scheduler.response',
      'requestId': sent[0]['requestId'],
      'snapshot': SchedulerSnapshot(nextSequence: 1).toJson(),
    });
    expect((await second).nextSequence, 2);
    expect((await first).nextSequence, 1);
    final failed = client.list();
    final failure = expectLater(
      failed,
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'revisionConflict',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    listener!({
      'type': 'scheduler.response',
      'requestId': sent.last['requestId'],
      'error': 'revisionConflict',
    });
    await failure;
    final invalid = client.list();
    final invalidResult = expectLater(
      invalid,
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'invalidResponse',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    listener!({
      'type': 'scheduler.response',
      'requestId': sent.last['requestId'],
      'snapshot': {'schemaVersion': 99},
    });
    await invalidResult;
    client.dispose();
  });
  test(
    'mutation transport preserves id/revision and authoritative full draft',
    () async {
      final store = Store();
      final sent = <Map<String, Object?>>[];
      void Function(Object)? listener;
      final runner = SchedulerRunner(
        coordinator: SchedulerCoordinator(
          store: store,
          executors: {'localNotification': Action()},
          now: () => DateTime.utc(2026, 10, 4),
          zoneId: () => 'UTC',
        ),
        refreshZone: () async {},
        configureBoot: (_) async {},
        notificationGranted: () async => true,
        send: (reply) => listener!(reply),
        now: () => DateTime.utc(2026, 10, 4),
      );
      await runner.start();
      final client = SchedulerClient(
        send: (request) {
          sent.add(request);
          unawaited(runner.receive(request));
        },
        addListener: (cb) => listener = cb,
        removeListener: (_) {},
        ensureRunning: () async {},
      );
      final draft = ScheduleDraft(
        name: ' saved ',
        recurrence: IntervalRecurrence(
          quantity: 3,
          unit: IntervalUnit.hours,
          anchorUtc: DateTime.utc(2026),
        ),
        action: LocalNotificationAction(title: ' title ', body: ' body '),
      );
      final created = await client.create(draft, id: 'stable-id');
      expect(sent.last['id'], 'stable-id');
      expect(sent.last['draft'], {
        'name': 'saved',
        'enabled': true,
        'recurrence': draft.recurrence.toJson(),
        'action': {
          'type': 'localNotification',
          'title': 'title',
          'body': 'body',
        },
      });
      expect(created.rules.single.notificationId, -1);
      final updated = await client.update(
        created.rules.single,
        ScheduleDraft(
          name: 'edited',
          recurrence: created.rules.single.recurrence,
          action: draft.action,
        ),
      );
      expect(sent.last['revision'], 1);
      expect(updated.rules.single.revision, 2);
      expect(SchedulerSnapshot.decode(store.raw!).rules.single.name, 'edited');
      final paused = await client.toggle(updated.rules.single, false);
      expect(paused.rules.single.enabled, false);
      await client.delete(paused.rules.single);
      expect(SchedulerSnapshot.decode(store.raw!).rules, isEmpty);
      client.dispose();
      runner.dispose();
    },
  );
  test('correlates replies, ignores heartbeat and wrong request, validates snapshot', () async {
    final sent = <Map<String, Object?>>[];
    void Function(Object)? listener;
    final client = SchedulerClient(
      send: sent.add,
      addListener: (value) => listener = value,
      removeListener: (_) {},
      ensureRunning: () async {},
      timeout: const Duration(milliseconds: 50),
    );
    final pending = client.list();
    await Future<void>.delayed(Duration.zero);
    listener!({'heartbeat': '2026-10-04T00:00:00Z'});
    listener!({
      'type': 'scheduler.response',
      'requestId': 'wrong',
      'snapshot': SchedulerSnapshot().toJson(),
    });
    listener!({
      'type': 'scheduler.response',
      'requestId': sent.single['requestId'],
      'snapshot': SchedulerSnapshot().toJson(),
    });
    expect((await pending).rules, isEmpty);
    client.dispose();
  });
  test('timeouts and typed remote errors are observable', () async {
    final client = SchedulerClient(
      send: (_) {},
      addListener: (_) {},
      removeListener: (_) {},
      ensureRunning: () async {},
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      client.list(),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'requestTimeout',
        ),
      ),
    );
    client.dispose();
  });
}
