import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/background/background_keepalive.dart';

import 'fake_background_platform.dart';

void main() {
  testWidgets('bootstrap requests notification and starts service when stopped', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(
      notificationGranted: false,
      grantNotificationOnRequest: true,
      ignoringBattery: false,
      grantBatteryOnRequest: true,
      runningService: false,
    );
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();
    await tester.pump();

    expect(platform.notificationRequestCount, 1);
    expect(platform.batteryRequestCount, 1);
    expect(platform.initCount, 1);
    expect(platform.startCount, 1);
    expect(keepalive.status.value.notificationGranted, isTrue);
    expect(keepalive.status.value.batteryUnrestricted, isTrue);
    expect(keepalive.status.value.serviceRunning, isTrue);
    expect(keepalive.status.value.bgLabel, 'running');

    keepalive.dispose();
  });

  testWidgets('bootstrap does not start a second service when already running', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(runningService: true);
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();

    expect(platform.startCount, 0);
    expect(keepalive.status.value.serviceRunning, isTrue);

    keepalive.dispose();
  });

  testWidgets('denied notification and battery do not throw; status reflects denial', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(
      grantNotificationOnRequest: false,
      grantBatteryOnRequest: false,
      becomeRunningAfterStart: true,
    );
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();

    expect(keepalive.status.value.notificationGranted, isFalse);
    expect(keepalive.status.value.notifLabel, 'denied');
    expect(keepalive.status.value.batteryUnrestricted, isFalse);
    expect(keepalive.status.value.batteryLabel, 'optimized');
    expect(keepalive.status.value.serviceRunning, isTrue);

    keepalive.dispose();
  });

  testWidgets('notification request throw is swallowed; status denied', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(throwOnNotificationRequest: true);
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();

    expect(keepalive.status.value.notificationGranted, isFalse);
    expect(keepalive.status.value.notifLabel, 'denied');

    keepalive.dispose();
  });

  testWidgets('second bootstrap is a no-op (no forced re-prompt)', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform();
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();
    await keepalive.bootstrap();

    expect(platform.notificationRequestCount, 1);
    expect(platform.batteryRequestCount, 1);
    expect(platform.startCount, 1);

    keepalive.dispose();
  });

  testWidgets('iOS skips battery request and leaves battery n/a', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(isAndroid: false, isIOS: true);
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();

    expect(platform.batteryRequestCount, 0);
    expect(platform.notificationRequestCount, 1);
    expect(keepalive.status.value.batteryUnrestricted, isNull);
    expect(keepalive.status.value.batteryLabel, 'n/a');

    keepalive.dispose();
  });

  testWidgets('heartbeat callback updates lastHeartbeat', (tester) async {
    final platform = FakeBackgroundPlatform();
    final keepalive = BackgroundKeepalive(platform: platform);
    await keepalive.bootstrap();

    final tick = DateTime.utc(2026, 8, 18, 15, 0, 0);
    platform.emitHeartbeat(tick);
    await tester.pump();

    expect(keepalive.status.value.lastHeartbeat, tick);
    expect(
      keepalive.status.value.heartbeatLabel(tick),
      'just now',
    );

    keepalive.dispose();
  });

  testWidgets('onLifecycle updates status lifecycle label', (tester) async {
    final platform = FakeBackgroundPlatform();
    final keepalive = BackgroundKeepalive(platform: platform);

    keepalive.onLifecycle(AppLifecycleState.paused);

    expect(keepalive.status.value.lifecycle, AppLifecycleState.paused);
    expect(keepalive.status.value.lifecycleLabel, 'paused');

    keepalive.dispose();
  });

  testWidgets('startService failure leaves bg stopped without throw', (
    tester,
  ) async {
    final platform = FakeBackgroundPlatform(
      throwOnStart: true,
      becomeRunningAfterStart: false,
    );
    final keepalive = BackgroundKeepalive(platform: platform);

    await keepalive.bootstrap();

    expect(keepalive.status.value.serviceRunning, isFalse);
    expect(keepalive.status.value.bgLabel, 'stopped');

    keepalive.dispose();
  });
}
