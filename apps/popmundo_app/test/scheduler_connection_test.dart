import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/background/background_keepalive.dart';
import 'package:popmundo_app/scheduler/scheduler_connection.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_background_platform.dart';

void main() {
  testWidgets(
    'readiness fails within its bound when no Dart heartbeat arrives',
    (tester) async {
      final platform = FakeBackgroundPlatform(runningService: true);
      final keepalive = BackgroundKeepalive(platform: platform);
      final pending = waitForSchedulerService(
        keepalive,
        platform,
        timeout: const Duration(seconds: 1),
        now: tester.binding.clock.now,
      );
      final assertion = expectLater(
        pending,
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'serviceUnavailable',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await assertion;
      expect(platform.startCount, 0);
      keepalive.dispose();
    },
  );
  testWidgets(
    'first request waits for Dart heartbeat readiness rather than native running flag',
    (tester) async {
      final platform = FakeBackgroundPlatform(runningService: true);
      final keepalive = BackgroundKeepalive(platform: platform);
      final sent = <Map<String, Object?>>[];
      void Function(Object)? callback;
      final client = SchedulerClient(
        send: sent.add,
        addListener: (cb) => callback = cb,
        removeListener: (_) {},
        ensureRunning: () => waitForSchedulerService(keepalive, platform),
      );
      final pending = client.list();
      await tester.pump();
      expect(sent, isEmpty);
      platform.emitHeartbeat(DateTime.utc(2026, 10, 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(sent, hasLength(1));
      callback!({
        'type': 'scheduler.response',
        'requestId': sent.single['requestId'],
        'snapshot': SchedulerSnapshot().toJson(),
      });
      expect((await pending).rules, isEmpty);
      client.dispose();
      keepalive.dispose();
    },
  );
}
