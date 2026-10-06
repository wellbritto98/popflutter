import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/background/keepalive_task_handler.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'scheduler_runtime_test.dart' show Store;

class RecordingRunner extends SchedulerRunner {
  RecordingRunner(void Function(Map<String, Object?>) send)
    : super(
        coordinator: SchedulerCoordinator(
          store: Store(),
          executors: {},
          now: DateTime.now,
          zoneId: () => 'Unknown/Unavailable',
        ),
        refreshZone: () async {},
        configureBoot: (_) async {},
        notificationGranted: () async => true,
        send: send,
      );
  int starts = 0, disposals = 0;
  @override
  Future<void> start() {
    starts++;
    return super.start();
  }

  @override
  Future<void> dispose() {
    disposals++;
    return super.dispose();
  }
}

Map<String, Object?> list(String requestId) => {
  'type': 'scheduler.request',
  'requestId': requestId,
  'command': 'list',
};

void main() {
  final at = DateTime.utc(2026, 10, 4);
  testWidgets(
    'failed factory retries on heartbeat and RPC reads authoritative catalog',
    (tester) async {
      final sent = <Map<String, Object?>>[];
      final runner = RecordingRunner(sent.add);
      var attempts = 0;
      final handler = KeepaliveTaskHandler(
        isAndroid: true,
        send: sent.add,
        createRunner: () async {
          if (++attempts == 1) {
            throw StateError('prefs temporarily unavailable');
          }
          return runner;
        },
      );
      await handler.onStart(at, TaskStarter.developer);
      expect(attempts, 1);
      handler.onRepeatEvent(at);
      expect(sent.single, {'heartbeat': at.toIso8601String()});
      await tester.pump();
      handler.onReceiveData(list('recovered'));
      await tester.pump();
      expect(attempts, 2);
      expect(runner.starts, 1);
      expect(sent.last, {
        'type': 'scheduler.response',
        'requestId': 'recovered',
        'snapshot': SchedulerSnapshot().toJson(),
      });
      await handler.onDestroy(at, false);
    },
  );
  testWidgets(
    'RPC retries completed factory failure without waiting for another tick',
    (tester) async {
      final sent = <Map<String, Object?>>[];
      final runner = RecordingRunner(sent.add);
      var attempts = 0;
      final handler = KeepaliveTaskHandler(
        isAndroid: true,
        send: sent.add,
        createRunner: () async {
          if (++attempts == 1) throw StateError('prefs');
          return runner;
        },
      );
      await handler.onStart(at, TaskStarter.developer);
      handler.onReceiveData(list('rpc'));
      await tester.pump();
      expect(attempts, 2);
      expect(sent.single['snapshot'], SchedulerSnapshot().toJson());
      expect(sent.single['requestId'], 'rpc');
      await handler.onDestroy(at, false);
    },
  );
  testWidgets(
    'startup deadline reports unavailable but repeated ticks never overlap pending factory',
    (tester) async {
      final sent = <Map<String, Object?>>[];
      final factory = Completer<SchedulerRunner>();
      final runner = RecordingRunner(sent.add);
      var attempts = 0;
      final handler = KeepaliveTaskHandler(
        isAndroid: true,
        send: sent.add,
        createRunner: () {
          attempts++;
          return factory.future;
        },
      );
      final started = handler.onStart(at, TaskStarter.developer);
      await tester.pump(const Duration(seconds: 5));
      await started;
      for (var i = 0; i < 3; i++) {
        handler.onRepeatEvent(at);
      }
      handler.onReceiveData(list('pending'));
      await tester.pump();
      expect(attempts, 1);
      expect(sent.where((data) => data.containsKey('heartbeat')), hasLength(3));
      expect(sent.last, {
        'type': 'scheduler.response',
        'requestId': 'pending',
        'error': 'runtimeUnavailable',
      });
      factory.complete(runner);
      await tester.pump();
      handler.onReceiveData(list('ready'));
      await tester.pump();
      expect(attempts, 1);
      expect(runner.starts, 1);
      expect(sent.last['snapshot'], SchedulerSnapshot().toJson());
      expect(sent.last['requestId'], 'ready');
      await handler.onDestroy(at, false);
    },
  );
  testWidgets(
    'destroy disposes late factory result without starting or rearming it',
    (tester) async {
      final sent = <Map<String, Object?>>[];
      final factory = Completer<SchedulerRunner>();
      final runner = RecordingRunner(sent.add);
      var attempts = 0;
      final handler = KeepaliveTaskHandler(
        isAndroid: true,
        send: sent.add,
        createRunner: () {
          attempts++;
          return factory.future;
        },
      );
      final started = handler.onStart(at, TaskStarter.developer);
      await handler.onDestroy(at, false);
      factory.complete(runner);
      await tester.pump();
      await started;
      expect(runner.disposals, 1);
      expect(runner.starts, 0);
      handler.onRepeatEvent(at);
      await tester.pump();
      expect(attempts, 1);
      expect(sent.single, {'heartbeat': at.toIso8601String()});
    },
  );
}
