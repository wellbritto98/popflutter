import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/device_zone.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_app/scheduler/scheduler_store.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'scheduler_runtime_test.dart' show Store, Action;

class BrokenPreferences extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'store reload observes a fresh engine value and false writes fail',
    () async {
      SharedPreferences.setMockInitialValues({
        SchedulerSnapshot.storageKey: 'before',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = PreferencesSchedulerStore(prefs);
      SharedPreferences.setMockInitialValues({
        SchedulerSnapshot.storageKey: 'external',
      });
      expect(await store.read(), 'external');
      await expectLater(
        PreferencesSchedulerStore(BrokenPreferences()).write('next'),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'writeFailed',
          ),
        ),
      );
    },
  );
  test(
    'zone lookup is bounded, never silently UTC, and retains last valid value',
    () async {
      tz.initializeTimeZones();
      Future<String> Function() read = () => Completer<String>().future;
      final zone = DeviceZone(
        read: () => read(),
        timeout: const Duration(milliseconds: 2),
      );
      await zone.refresh();
      expect(zone.identifier, 'Unknown/Unavailable');
      read = () async => 'America/Sao_Paulo';
      await zone.refresh();
      expect(zone.identifier, 'America/Sao_Paulo');
      read = () async => throw StateError('native');
      await zone.refresh();
      expect(zone.identifier, 'America/Sao_Paulo');
      read = () async => 'America/New_York';
      await zone.refresh();
      expect(zone.identifier, 'America/New_York');
    },
  );
  testWidgets(
    'nearest timer fires without native heartbeat and stops after delete',
    (tester) async {
      final store = Store();
      final action = Action();
      var now = DateTime.utc(2026, 10, 4);
      final replies = <Map<String, Object?>>[];
      final runner = SchedulerRunner(
        coordinator: SchedulerCoordinator(
          store: store,
          executors: {'localNotification': action},
          now: () => now,
          zoneId: () => 'UTC',
        ),
        refreshZone: () async {},
        configureBoot: (_) async {},
        notificationGranted: () async => true,
        send: replies.add,
        now: () => now,
      );
      await runner.start();
      await runner.receive({
        'type': 'scheduler.request',
        'requestId': 'one',
        'command': 'create',
        'id': 'a',
        'draft': {
          'name': 'a',
          'enabled': true,
          'recurrence': IntervalRecurrence(
            quantity: 1,
            unit: IntervalUnit.seconds,
            anchorUtc: now,
          ).toJson(),
          'action': LocalNotificationAction(title: 'a', body: 'b').toJson(),
        },
      });
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(action.calls, [-1]);
      final rule = (await runner.coordinator.list()).rules.single;
      await runner.receive({
        'type': 'scheduler.request',
        'requestId': 'two',
        'command': 'delete',
        'id': 'a',
        'revision': rule.revision,
      });
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(action.calls, [-1]);
      expect((await runner.coordinator.list()).rules, isEmpty);
      runner.dispose();
    },
  );
  test('corrupt startup stays preserved, reports typed RPC error, can recover fresh read', () async {
    final store = Store()..raw = 'corrupt';
    final replies = <Map<String, Object?>>[];
    final runner = SchedulerRunner(
      coordinator: SchedulerCoordinator(
        store: store,
        executors: {},
        now: DateTime.now,
        zoneId: () => 'UTC',
      ),
      refreshZone: () async {},
      configureBoot: (_) async {},
      notificationGranted: () async => true,
      send: replies.add,
    );
    await expectLater(runner.start(), throwsA(isA<SchedulerException>()));
    await runner.receive({
      'type': 'scheduler.request',
      'requestId': 'one',
      'command': 'list',
    });
    expect(replies.last['error'], 'corruptSnapshot');
    expect(store.raw, 'corrupt');
    store.raw = null;
    await runner.reconcile();
    await runner.receive({
      'type': 'scheduler.request',
      'requestId': 'two',
      'command': 'list',
    });
    expect(replies.last['error'], isNull);
    expect(replies.last['snapshot'], SchedulerSnapshot().toJson());
    runner.dispose();
  });
}
