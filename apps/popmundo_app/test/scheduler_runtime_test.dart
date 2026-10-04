import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_app/scheduler/scheduler_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Store implements SchedulerStore {
  String? raw;
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String value) async {
    raw = value;
  }
}

class Action implements ScheduledActionExecutor {
  final calls = <int>[];
  @override
  Future<void> execute({
    required LocalNotificationAction action,
    required int notificationId,
  }) async {
    calls.add(notificationId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reload-aware JSON store preserves external writer and rejects failed write', () async {
    SharedPreferences.setMockInitialValues({
      SchedulerSnapshot.storageKey: 'first',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesSchedulerStore(prefs);
    expect(await store.read(), 'first');
    await store.write('second');
    expect(prefs.getString(SchedulerSnapshot.storageKey), 'second');
  });
  test('runner commands acknowledge persisted state and complete boot options before reply', () async {
    var now = DateTime.utc(2026, 10, 4, 12);
    final store = Store();
    final action = Action();
    final replies = <Map<String, Object?>>[];
    final boots = <bool>[];
    final runner = SchedulerRunner(
      coordinator: SchedulerCoordinator(
        store: store,
        executors: {'localNotification': action},
        now: () => now,
        zoneId: () => 'UTC',
      ),
      refreshZone: () async {},
      configureBoot: (enabled) async {
        boots.add(enabled);
      },
      notificationGranted: () async => true,
      send: replies.add,
      now: () => now,
    );
    await runner.start();
    await runner.receive({
      'type': 'scheduler.request',
      'requestId': 'one',
      'command': 'create',
      'id': 'stable',
      'draft': {
        'name': 'Reminder',
        'enabled': true,
        'recurrence': IntervalRecurrence(
          quantity: 10,
          unit: IntervalUnit.seconds,
          anchorUtc: now,
        ).toJson(),
        'action': LocalNotificationAction(
          title: 'saved title',
          body: 'saved body',
        ).toJson(),
      },
    });
    expect(boots.last, true);
    expect(
      SchedulerSnapshot.decode(store.raw!).rules.single.notificationId,
      -1,
    );
    expect(replies.last['requestId'], 'one');
    expect(replies.last['type'], 'scheduler.response');
    expect(replies.last['error'], isNull);
    now = now.add(const Duration(seconds: 10));
    await runner.reconcile();
    expect(action.calls, [-1]);
    final rule = SchedulerSnapshot.decode(store.raw!).rules.single;
    await runner.receive({
      'type': 'scheduler.request',
      'requestId': 'two',
      'command': 'toggle',
      'id': 'stable',
      'revision': rule.revision,
      'enabled': false,
    });
    expect(boots.last, false);
    expect(SchedulerSnapshot.decode(store.raw!).rules.single.enabled, false);
    runner.dispose();
  });
  test(
    'denied activation and failed boot update never acknowledge success',
    () async {
      final store = Store();
      final replies = <Map<String, Object?>>[];
      var granted = false;
      final runner = SchedulerRunner(
        coordinator: SchedulerCoordinator(
          store: store,
          executors: {},
          now: DateTime.now,
          zoneId: () => 'UTC',
        ),
        refreshZone: () async {},
        configureBoot: (enabled) async {
          if (enabled) throw StateError('boot');
        },
        notificationGranted: () async => granted,
        send: replies.add,
      );
      await runner.start();
      final request = {
        'type': 'scheduler.request',
        'requestId': 'a',
        'command': 'create',
        'id': 'stable',
        'draft': {
          'name': 'Reminder',
          'enabled': true,
          'recurrence': IntervalRecurrence(anchorUtc: DateTime.now()).toJson(),
          'action': LocalNotificationAction(title: 't', body: 'b').toJson(),
        },
      };
      await runner.receive(request);
      expect(replies.last['error'], 'permissionDenied');
      expect((await runner.coordinator.list()).rules, isEmpty);
      granted = true;
      await runner.receive(request);
      expect(replies.last['error'], 'bootConfigurationFailed');
      expect(SchedulerSnapshot.decode(store.raw!).rules.single.id, 'stable');
      runner.dispose();
    },
  );
  test(
    'overlapping heartbeat reconciliation coalesces one in-flight operation',
    () async {
      final block = Completer<void>();
      var refreshes = 0;
      final runner = SchedulerRunner(
        coordinator: SchedulerCoordinator(
          store: Store(),
          executors: {},
          now: DateTime.now,
          zoneId: () => 'UTC',
        ),
        refreshZone: () async {
          refreshes++;
          if (refreshes > 1) await block.future;
        },
        configureBoot: (_) async {},
        notificationGranted: () async => true,
        send: (_) {},
      );
      await runner.start();
      final first = runner.reconcile();
      final second = runner.reconcile();
      expect(identical(first, second), true);
      block.complete();
      await first;
      expect(refreshes, 2);
      runner.dispose();
    },
  );
}
