import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/app_wiring.dart';
import 'package:popmundo_app/background/keepalive_task_handler.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'scheduler_runtime_test.dart' show Store;

class CleanupExecutor implements ScheduledGameActionExecutor {
  final closed = Completer<void>();
  int cancels = 0;
  @override
  void cancel() {
    cancels++;
  }

  @override
  Future<void> dispose() => closed.future;
  @override
  Future<GameActionOutcome> execute(
    GameScheduledAction action, {
    bool Function()? isEligible,
    Future<void> Function()? beforeHttp,
  }) async => const GameActionOutcome(status: GameActionStatus.confirmed);
}

SchedulerRunner runner(CleanupExecutor executor) => SchedulerRunner(
  coordinator: SchedulerCoordinator(
    store: Store(),
    executors: {},
    gameExecutor: executor,
    now: DateTime.now,
    zoneId: () => 'UTC',
  ),
  refreshZone: () async {},
  configureBoot: (_) async {},
  notificationGranted: () async => true,
  send: (_) {},
);
void main() {
  testWidgets('destroy waits for HTTP cleanup and cancels before draining', (
    tester,
  ) async {
    final executor = CleanupExecutor();
    final value = runner(executor);
    final handler = KeepaliveTaskHandler(
      isAndroid: true,
      createRunner: () async => value,
      send: (_) {},
    );
    await handler.onStart(DateTime.utc(2026), TaskStarter.developer);
    var finished = false;
    final destroyed = handler
        .onDestroy(DateTime.utc(2026), false)
        .then((_) => finished = true);
    expect(executor.cancels, 1);
    await tester.pump();
    expect(finished, false);
    executor.closed.complete();
    await tester.pump();
    await destroyed;
    expect(finished, true);
  });
  testWidgets(
    'late factory result is disposed and cleanup awaited without startup',
    (tester) async {
      final executor = CleanupExecutor();
      final factory = Completer<SchedulerRunner>();
      final handler = KeepaliveTaskHandler(
        isAndroid: true,
        createRunner: () => factory.future,
        send: (_) {},
      );
      final startup = handler.onStart(
        DateTime.utc(2026),
        TaskStarter.developer,
      );
      await handler.onDestroy(DateTime.utc(2026), false);
      var finished = false;
      unawaited(startup.then((_) => finished = true));
      factory.complete(runner(executor));
      await tester.pump();
      expect(executor.cancels, 1);
      expect(finished, false);
      executor.closed.complete();
      await tester.pump();
      await startup;
      expect(finished, true);
    },
  );
  test(
    'AppWiring disposes pending scheduler client and unregisters listener',
    () async {
      var removed = 0;
      final client = SchedulerClient(
        send: (_) {},
        addListener: (_) {},
        removeListener: (_) => removed++,
        ensureRunning: () async {},
      );
      final jar = MemoryCookieSink();
      final wiring = AppWiring(
        runtime: InAppPopmundoRuntime(),
        store: MemoryKeyValueStore(),
        secretStore: MemorySecretStore(),
        cookieSink: jar,
        cookieSource: jar,
        schedulerApi: client,
      );
      final read = client.list();
      final failure = expectLater(
        read,
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'serviceUnavailable',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await wiring.dispose();
      await failure;
      expect(removed, 1);
    },
  );
}
