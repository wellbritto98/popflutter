import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'scheduler_coordinator_test.dart' show TestStore, TestExecutor;
import 'game_actions_transport_test.dart' show FixtureTransport, loginHtml;
import 'game_actions_item_test.dart' show ActionTransport, itemAction;

class GameExecutor implements ScheduledGameActionExecutor {
  final effects = <Map<String, Object?>>[];
  GameActionOutcome outcome = const GameActionOutcome(
    status: GameActionStatus.confirmed,
  );
  Future<GameActionOutcome> Function()? work;
  void Function()? onCancel;
  bool cancelled = false;
  bool disposed = false;
  @override
  Future<GameActionOutcome> execute(
    GameScheduledAction action, {
    bool Function()? isEligible,
    Future<void> Function()? beforeHttp,
  }) async {
    if (isEligible != null && !isEligible()) {
      return const GameActionOutcome(
        status: GameActionStatus.failed,
        errorCode: 'occurrenceExpired',
      );
    }
    await beforeHttp?.call();
    effects.add(action.toJson());
    return work != null ? work!() : outcome;
  }

  @override
  void cancel() {
    cancelled = true;
    onCancel?.call();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    cancel();
  }
}

class Notices implements ScheduledGameNotifications {
  Notices(this.store);
  final TestStore store;
  final events = <Map<String, Object?>>[];
  bool startFails = false;
  bool resultFails = false;
  @override
  Future<void> showStart({
    required GameScheduledAction action,
    required int notificationId,
  }) async {
    final claim = SchedulerSnapshot.decode(store.raw!).rules
        .singleWhere((r) => r.notificationId == notificationId)
        .lastClaim;
    expect(claim, isNotNull, reason: 'durable claim precedes start');
    events.add({
      'kind': 'start',
      'id': notificationId,
      'action': action.toJson(),
    });
    if (startFails) throw const SchedulerException('permissionDenied');
  }

  @override
  Future<void> showResult({
    required GameScheduledAction action,
    required int notificationId,
    required GameActionOutcome outcome,
  }) async {
    final result = SchedulerSnapshot.decode(store.raw!).rules
        .singleWhere((r) => r.notificationId == notificationId)
        .lastResult;
    expect(
      result.status.name,
      outcome.status.name,
      reason: 'truthful result persisted before final notice',
    );
    events.add({
      'kind': 'result',
      'id': notificationId,
      'action': action.toJson(),
      'outcome': outcome.toJson(),
    });
    if (resultFails) throw StateError('synthetic-platform-failure');
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  final anchor = DateTime.utc(2026, 10, 6);
  late DateTime time;
  late TestStore store;
  late GameExecutor game;
  late Notices notices;
  late SchedulerCoordinator coordinator;
  ScheduleDraft draft() => ScheduleDraft(
    name: 'Item',
    recurrence: IntervalRecurrence(
      quantity: 10,
      unit: IntervalUnit.seconds,
      anchorUtc: anchor,
    ),
    action: itemAction(),
  );
  SchedulerCoordinator fresh({
    ScheduledGameActionExecutor? executor,
    ScheduledGameNotifications? notifications,
  }) => SchedulerCoordinator(
    store: store,
    executors: {'localNotification': TestExecutor()},
    gameExecutor: executor ?? game,
    gameNotifications: notifications ?? notices,
    now: () => time,
    zoneId: () => 'UTC',
  );
  setUp(() {
    time = anchor;
    store = TestStore();
    game = GameExecutor();
    notices = Notices(store);
    coordinator = fresh();
  });
  Future<void> due() async {
    await coordinator.create(draft(), id: 'one');
    time = anchor.add(const Duration(seconds: 10));
  }

  test(
    'SGA-09 dispose prevents queued discovery before coordinator result drain',
    () async {
      final slowStore = _SlowResultStore();
      store = slowStore;
      notices = Notices(store);
      final pending = Completer<AuthHttpResponse>();
      final active = FixtureTransport()..handler = (_) => pending.future;
      var factories = 0;
      final service = GameActionsService(
        createTransport: () {
          factories++;
          return factories == 1 ? active : FixtureTransport();
        },
        readCredentials: () async =>
            const GameCredentials(username: 'account', password: 'synthetic'),
        limits: const GameActionLimits(cooldown: Duration.zero),
      );
      coordinator = fresh(executor: service);
      await due();
      final running = coordinator.reconcile();
      await Future<void>.delayed(Duration.zero);
      final queued = service.discoverCharacters().then<Object?>(
        (_) => 'discoveryStarted',
        onError: (Object error) => error,
      );
      slowStore.blockResult = true;
      final disposing = coordinator.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final beforeDrain = factories;
      slowStore.gate.complete();
      await running;
      await disposing;
      final result = await queued;
      expect(
        result,
        isA<GameActionException>().having(
          (e) => e.code,
          'code',
          'serviceUnavailable',
        ),
      );
      expect(beforeDrain, 1);
      expect(factories, 1);
      expect(active.closed, true);
    },
  );
  for (final missing in ['executor', 'notifications']) {
    test('SGA-07 missing $missing fails without game traffic', () async {
      coordinator = SchedulerCoordinator(
        store: store,
        executors: const {},
        gameExecutor: missing == 'executor' ? null : game,
        gameNotifications: missing == 'notifications' ? null : notices,
        now: () => time,
        zoneId: () => 'UTC',
      );
      await due();
      final rule = (await coordinator.reconcile()).rules.single;
      expect(rule.lastResult.status, ScheduleResultStatus.failed);
      expect(
        rule.lastResult.errorCode,
        missing == 'executor'
            ? 'executorUnavailable'
            : 'notificationUnavailable',
      );
      expect(game.effects, isEmpty);
      expect(
        notices.events.where((event) => event['kind'] == 'start'),
        isEmpty,
      );
    });
  }
  test('SGA-09 long first rule skips overdue second target and keeps both characters', () async {
    await coordinator.create(draft(), id: 'one');
    final secondAction = UseItemAction(
      boundUsername: 'account',
      character: GameCharacter(id: 2, name: 'Other char'),
      itemName: 'Other item',
    );
    await coordinator.create(
      ScheduleDraft(
        name: 'Second',
        recurrence: draft().recurrence,
        action: secondAction,
      ),
      id: 'two',
    );
    time = anchor.add(const Duration(seconds: 10));
    game.work = () async {
      time = anchor.add(const Duration(seconds: 21));
      return const GameActionOutcome(status: GameActionStatus.confirmed);
    };
    final rules = (await coordinator.reconcile()).rules;
    expect(game.effects, [itemAction().toJson()]);
    expect(rules[0].action.toJson(), itemAction().toJson());
    expect(rules[1].action.toJson(), secondAction.toJson());
    expect(rules[1].lastClaim, isNull);
    expect(rules.map((r) => r.nextDueUtc).toList(), [
      anchor.add(const Duration(seconds: 30)),
      anchor.add(const Duration(seconds: 30)),
    ]);
    expect(notices.events.map((e) => e['id']).toList(), [-1, -1]);
    await coordinator.reconcile();
    expect(game.effects.length, 1);
  });

  test(
    'SGA-01 game snapshot/action-only edit keeps character and cadence',
    () async {
      final created = await coordinator.create(draft(), id: 'one');
      final original = created.rules.single;
      expect(
        SchedulerSnapshot.decode(store.raw!).rules.single.action.toJson(),
        itemAction().toJson(),
      );
      time = anchor.add(const Duration(seconds: 5));
      final changed = await coordinator.update(
        'one',
        ScheduleDraft(
          name: 'Changed',
          recurrence: original.recurrence,
          action: itemAction('Other item'),
        ),
        expectedRevision: 1,
      );
      final rule = changed.rules.single;
      expect([rule.id, rule.notificationId, rule.revision], ['one', -1, 2]);
      expect(rule.nextDueUtc, original.nextDueUtc);
      expect((rule.recurrence as IntervalRecurrence).anchorUtc, anchor);
      expect((rule.action as UseItemAction).character.toJson(), {
        'id': 3327035,
        'name': 'Saved old name',
      });
      expect((rule.action as UseItemAction).itemName, 'Other item');
    },
  );
  for (final status in GameActionStatus.values) {
    test(
      'SGA-07/08 $status persists exact outcome and same start/result card',
      () async {
        game.outcome = GameActionOutcome(
          status: status,
          errorCode: status == GameActionStatus.confirmed
              ? null
              : 'boundedCode',
        );
        await due();
        final rule = (await coordinator.reconcile()).rules.single;
        expect(rule.lastResult.status.name, status.name);
        expect(rule.lastResult.errorCode, game.outcome.errorCode);
        expect(rule.lastResult.atUtc, time);
        expect(
          rule.lastClaim!.plannedUtc,
          anchor.add(const Duration(seconds: 10)),
        );
        expect(rule.lastAttemptUtc, rule.lastClaim!.plannedUtc);
        expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 20)));
        expect(game.effects, [itemAction().toJson()]);
        expect(notices.events, [
          {'kind': 'start', 'id': -1, 'action': itemAction().toJson()},
          {
            'kind': 'result',
            'id': -1,
            'action': itemAction().toJson(),
            'outcome': game.outcome.toJson(),
          },
        ]);
        await coordinator.reconcile();
        expect(game.effects.length, 1);
      },
    );
  }
  test('SGA-07 claim failure stops all notices/gameplay', () async {
    await due();
    store.fail = true;
    await expectLater(
      coordinator.reconcile(),
      throwsA(
        isA<SchedulerException>().having((e) => e.code, 'code', 'writeFailed'),
      ),
    );
    expect(game.effects, isEmpty);
    expect(notices.events, isEmpty);
  });
  test(
    'SGA-07 start permission failure keeps claim and stops gameplay',
    () async {
      await due();
      notices.startFails = true;
      final rule = (await coordinator.reconcile()).rules.single;
      expect(rule.lastResult.status, ScheduleResultStatus.failed);
      expect(rule.lastResult.errorCode, 'permissionDenied');
      expect(
        rule.lastClaim!.plannedUtc,
        anchor.add(const Duration(seconds: 10)),
      );
      expect(game.effects, isEmpty);
      expect(notices.events.first['kind'], 'start');
      await coordinator.reconcile();
      expect(game.effects, isEmpty);
    },
  );
  test(
    'SGA-07 final card failure preserves confirmed effect without retry',
    () async {
      await due();
      notices.resultFails = true;
      final rule = (await coordinator.reconcile()).rules.single;
      expect(rule.lastResult.status, ScheduleResultStatus.confirmed);
      expect(rule.lastResult.errorCode, isNull);
      expect(
        SchedulerSnapshot.decode(store.raw!).rules.single.lastResult.status,
        ScheduleResultStatus.confirmed,
      );
      await coordinator.reconcile();
      expect(game.effects.length, 1);
      expect(notices.events.length, 2);
    },
  );
  test(
    'SGA-08 result-write failure preserves interrupted claim and no replay',
    () async {
      await due();
      store.failWrite = store.writes + 2;
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
      expect(game.effects.length, 1);
      final restored = (await fresh().load()).rules.single;
      expect(
        restored.lastResult.status,
        ScheduleResultStatus.skippedInterrupted,
      );
      expect(restored.nextDueUtc, anchor.add(const Duration(seconds: 20)));
      await coordinator.reconcile();
      expect(game.effects.length, 1);
    },
  );
  test('SGA-09 game completion longer than five seconds is awaited', () async {
    await due();
    game.work = () async {
      await Future<void>.delayed(const Duration(milliseconds: 5150));
      return const GameActionOutcome(status: GameActionStatus.confirmed);
    };
    final rule = (await coordinator.reconcile()).rules.single;
    expect(rule.lastResult.status, ScheduleResultStatus.confirmed);
    expect(game.effects.length, 1);
  });
  test(
    'SGA-09 dispose aborts active executor and blocks later commands',
    () async {
      await due();
      final pending = Completer<GameActionOutcome>();
      game.work = () => pending.future;
      game.onCancel = () {
        if (!pending.isCompleted) {
          pending.complete(
            const GameActionOutcome(
              status: GameActionStatus.uncertain,
              errorCode: 'outcomeUncertain',
            ),
          );
        }
      };
      final running = coordinator.reconcile();
      await Future<void>.delayed(Duration.zero);
      await coordinator.dispose();
      await running;
      expect(game.cancelled, true);
      expect(game.disposed, true);
      expect(game.effects.length, 1);
      await expectLater(
        coordinator.list(),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'serviceUnavailable',
          ),
        ),
      );
    },
  );
  test('SGA-09 shared discovery queue rechecks slot eligibility before notice/HTTP', () async {
    final pending = Completer<AuthHttpResponse>();
    final discoveryTransport = FixtureTransport()
      ..handler = (_) => pending.future;
    var factories = 0;
    final service = GameActionsService(
      createTransport: () {
        factories++;
        return factories == 1 ? discoveryTransport : ActionTransport();
      },
      readCredentials: () async =>
          const GameCredentials(username: 'account', password: 'synthetic'),
      limits: const GameActionLimits(cooldown: Duration.zero),
    );
    final discovery = service.discoverCharacters();
    await Future<void>.delayed(Duration.zero);
    coordinator = fresh(executor: service);
    await due();
    final running = coordinator.reconcile();
    await Future<void>.delayed(Duration.zero);
    time = anchor.add(const Duration(seconds: 21));
    discoveryTransport.handler = null;
    pending.complete(const AuthHttpResponse(status: 200, body: loginHtml));
    await discovery;
    final rule = (await running).rules.single;
    expect(rule.lastResult.errorCode, 'occurrenceExpired');
    expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 30)));
    expect(notices.events, isEmpty);
    expect(factories, 1);
    await service.dispose();
  });
  test('SGA-09 delayed game completion arms future slot without cadence drift or replay', () async {
    await due();
    game.work = () async {
      time = anchor.add(const Duration(seconds: 35));
      return const GameActionOutcome(status: GameActionStatus.confirmed);
    };
    final rule = (await coordinator.reconcile()).rules.single;
    expect(rule.lastResult.status, ScheduleResultStatus.confirmed);
    expect(rule.lastResult.atUtc, time);
    expect(rule.nextDueUtc, anchor.add(const Duration(seconds: 40)));
    expect(rule.nextDueUtc!.isAfter(time), true);
    expect((rule.recurrence as IntervalRecurrence).anchorUtc, anchor);
    expect(rule.lastAttemptUtc, anchor.add(const Duration(seconds: 10)));
    await coordinator.reconcile();
    expect(game.effects.length, 1);
  });
}

class _SlowResultStore extends TestStore {
  final gate = Completer<void>();
  bool blockResult = false;
  @override
  Future<void> write(String value) async {
    if (blockResult && writes == 2) await gate.future;
    await super.write(value);
  }
}
