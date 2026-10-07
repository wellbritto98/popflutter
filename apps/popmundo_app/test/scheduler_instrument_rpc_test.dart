import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'scheduler_game_editor_test.dart' show intervalDraft;
import 'scheduler_instrument_editor_test.dart'
    show InstrumentDiscovery, instrumentAction;
import 'scheduler_runtime_test.dart' show Store;

void main() {
  test(
    'RPC carries item operations through discovery, create and update',
    () async {
      final store = Store();
      void Function(Object)? listener;
      final sent = <Map<String, Object?>>[];
      final replies = <Map<String, Object?>>[];
      final runner = SchedulerRunner(
        coordinator: SchedulerCoordinator(
          store: store,
          executors: {},
          now: () => DateTime.utc(2026, 10, 7),
          zoneId: () => 'UTC',
        ),
        gameActions: InstrumentDiscovery(),
        refreshZone: () async {},
        configureBoot: (_) async {},
        notificationGranted: () async => true,
        send: (data) {
          replies.add(data);
          listener!(data);
        },
      );
      final client = SchedulerClient(
        send: (data) {
          sent.add(data);
          unawaited(runner.receive(data));
        },
        addListener: (cb) => listener = cb,
        removeListener: (_) {},
        ensureRunning: () async {},
      );
      addTearDown(() async {
        client.dispose();
        await runner.dispose();
      });
      final choices = await client.discoverItems(
        boundUsername: 'bound',
        character: GameCharacter(id: 42, name: 'Saved Character'),
      );
      expect(choices.map((choice) => choice.name).toList(), [
        'Violino',
        'Violino',
      ]);
      expect(choices.map((choice) => choice.operation).toList(), [
        GameItemOperation.use,
        GameItemOperation.tune,
      ]);
      final created = (await client.create(
        intervalDraft(instrumentAction()),
        id: 'rpc-tune',
      )).rules.single;
      expect(
        (created.action as UseItemAction).operation,
        GameItemOperation.tune,
      );
      expect(
        (sent.last['draft'] as Map)['action'],
        instrumentAction().toJson(),
      );
      final updated = (await client.update(
        created,
        intervalDraft(instrumentAction(), name: 'Edited'),
      )).rules.single;
      expect(updated.name, 'Edited');
      expect(updated.id, created.id);
      expect(updated.nextDueUtc, created.nextDueUtc);
      expect(
        (updated.action as UseItemAction).operation,
        GameItemOperation.tune,
      );
      expect(
        (sent.last['draft'] as Map)['action'],
        instrumentAction().toJson(),
      );
      expect(
        SchedulerSnapshot.decode(store.raw!).rules.single.action.toJson(),
        instrumentAction().toJson(),
      );
      final raw = store.raw;
      for (final invalid in [null, "wear"]) {
        await runner.receive({
          "type": "scheduler.request",
          "requestId": "invalid-operation",
          "command": "update",
          "id": updated.id,
          "revision": updated.revision,
          "draft": {
            "name": "Invalid",
            "enabled": updated.enabled,
            "recurrence": updated.recurrence.toJson(),
            "action": {...instrumentAction().toJson(), "operation": invalid},
          },
        });
        expect(replies.last["error"], "invalidAction");
        expect(store.raw, raw);
      }
    },
  );
}
