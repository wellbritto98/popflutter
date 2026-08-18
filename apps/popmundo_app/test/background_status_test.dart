import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/background/background_status.dart';

void main() {
  group('BackgroundStatus labels', () {
    test('bgLabel is running or stopped', () {
      expect(
        const BackgroundStatus(
          serviceRunning: true,
          lifecycle: AppLifecycleState.resumed,
        ).bgLabel,
        'running',
      );
      expect(
        const BackgroundStatus(
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).bgLabel,
        'stopped',
      );
    });

    test('notifLabel is granted, denied, or unknown', () {
      expect(
        const BackgroundStatus(
          notificationGranted: true,
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).notifLabel,
        'granted',
      );
      expect(
        const BackgroundStatus(
          notificationGranted: false,
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).notifLabel,
        'denied',
      );
      expect(
        const BackgroundStatus(
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).notifLabel,
        'unknown',
      );
    });

    test('batteryLabel is unrestricted, optimized, or n/a when null (iOS)', () {
      expect(
        const BackgroundStatus(
          batteryUnrestricted: true,
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).batteryLabel,
        'unrestricted',
      );
      expect(
        const BackgroundStatus(
          batteryUnrestricted: false,
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).batteryLabel,
        'optimized',
      );
      expect(
        const BackgroundStatus(
          serviceRunning: false,
          lifecycle: AppLifecycleState.resumed,
        ).batteryLabel,
        'n/a',
      );
    });

    test('lifecycleLabel uses AppLifecycleState.name', () {
      expect(
        const BackgroundStatus(
          serviceRunning: false,
          lifecycle: AppLifecycleState.paused,
        ).lifecycleLabel,
        'paused',
      );
    });

    test('heartbeatLabel is never, just now, or Ns ago', () {
      const base = BackgroundStatus(
        serviceRunning: true,
        lifecycle: AppLifecycleState.resumed,
      );
      expect(base.heartbeatLabel(), 'never');

      final now = DateTime.utc(2026, 8, 18, 12, 0, 0);
      expect(
        BackgroundStatus(
          serviceRunning: true,
          lifecycle: AppLifecycleState.resumed,
          lastHeartbeat: now,
        ).heartbeatLabel(now),
        'just now',
      );
      expect(
        BackgroundStatus(
          serviceRunning: true,
          lifecycle: AppLifecycleState.resumed,
          lastHeartbeat: now.subtract(const Duration(seconds: 12)),
        ).heartbeatLabel(now),
        '12s ago',
      );
    });
  });
}
