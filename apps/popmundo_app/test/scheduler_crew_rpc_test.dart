import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'scheduler_runtime_test.dart' show Store;

void main() {
  test('unquoted maximum survives create and list across engine RPC', () async {
    final store = Store();
    void Function(Object)? listener;
    final runner = SchedulerRunner(
      coordinator: SchedulerCoordinator(
        store: store,
        executors: {},
        now: () => DateTime.utc(2026, 10, 6),
        zoneId: () => 'UTC',
      ),
      refreshZone: () async {},
      configureBoot: (_) async {},
      notificationGranted: () async => true,
      now: () => DateTime.utc(2026, 10, 6),
      send: (reply) => listener!(reply),
    );
    final client = SchedulerClient(
      send: (request) => unawaited(runner.receive(request)),
      addListener: (cb) => listener = cb,
      removeListener: (_) {},
      ensureRunning: () async {},
    );
    addTearDown(client.dispose);
    addTearDown(runner.dispose);
    final action = PayCrewAction(
      boundUsername: 'bound',
      character: GameCharacter(id: 42, name: 'Saved Character'),
      artistId: 77,
      artistName: 'Saved Band',
      bonusLevel: 20,
    );
    final created = await client.create(
      ScheduleDraft(
        name: 'Future maximum',
        recurrence: IntervalRecurrence(
          quantity: 7,
          unit: IntervalUnit.days,
          anchorUtc: DateTime.utc(2026, 10, 6),
        ),
        action: action,
      ),
      id: 'future-crew',
    );
    expect(created.rules.single.id, 'future-crew');
    expect(created.rules.single.action.toJson(), {
      'type': 'payCrew',
      'boundUsername': 'bound',
      'character': {'id': 42, 'name': 'Saved Character'},
      'artistId': 77,
      'artistName': 'Saved Band',
      'bonusLevel': 20,
      'maxCostMinor': null,
    });
    final listed = (await client.list()).rules.single;
    expect(listed.action.toJson(), created.rules.single.action.toJson());
    expect(
      SchedulerSnapshot.decode(store.raw!).rules.single.action.toJson(),
      created.rules.single.action.toJson(),
    );
    expect((listed.action as PayCrewAction).maxCostMinor, isNull);
  });
}
