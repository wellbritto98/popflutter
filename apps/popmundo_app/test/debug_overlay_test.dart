import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/background/background_status.dart';
import 'package:popmundo_app/debug_overlay.dart';
import 'package:popmundo_app/notifications/fake_notification_service.dart';
import 'package:popmundo_app/notifications/notification_service.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Minimal [NotificationService] stub whose calls throw, used to prove
/// [DebugOverlay] never crashes on a plugin/service-level error (NOTIF-08).
/// Kept local to this test file rather than added to
/// [FakeNotificationService], whose configurable fields don't include a
/// throw-on-show toggle per design.md's Components section.
class _ThrowingNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showTestNotification() async {
    throw Exception('boom');
  }
}

void main() {
  testWidgets('collapsed overlay renders no debug control and no panel', (tester) async {
    final bus = PopmundoEventBus();
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('debug-panel')), findsNothing);
  });

  testWidgets('visible overlay shows host, events, eval and clear', (tester) async {
    final bus = PopmundoEventBus();
    final host = HostTracker()..onNavigation(Uri.parse('https://73.popmundo.com/'));
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: host,
          events: bus,
          evaluate: (source) async => 'result:$source',
          cookies: const [CookieSummary(name: 'session', domain: 'popmundo.com')],
          visible: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const Key('debug-panel')), findsOneWidget);
    expect(find.byKey(const Key('debug-host')), findsOneWidget);
    expect(find.textContaining('73.popmundo.com'), findsWidgets);
    expect(find.text('session@popmundo.com'), findsOneWidget);
    expect(find.textContaining('secret-value'), findsNothing);
    expect(find.byKey(const Key('debug-bg-service')), findsNothing);

    bus.emitNetwork(NetworkEvent(method: 'GET', url: 'https://73.popmundo.com/a', status: 200));
    bus.emitConsole(ConsoleEvent(level: 'log', message: 'hello-console'));
    await tester.pump();
    expect(find.textContaining('GET'), findsOneWidget);
    expect(find.textContaining('hello-console'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('debug-eval-input')), '1+1');
    await tester.tap(find.byKey(const Key('debug-eval-run')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debug-eval-result')), findsOneWidget);
    expect(find.text('result:1+1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('debug-clear')));
    await tester.pump();
    expect(find.textContaining('GET 200'), findsNothing);
    expect(find.textContaining('hello-console'), findsNothing);
  });

  testWidgets('visible overlay shows keepalive status lines with keys', (tester) async {
    final bus = PopmundoEventBus();
    final tick = DateTime.now().subtract(const Duration(seconds: 12));
    final status = BackgroundStatus(
      notificationGranted: true,
      batteryUnrestricted: true,
      serviceRunning: true,
      lifecycle: AppLifecycleState.resumed,
      lastHeartbeat: tick,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          backgroundStatus: status,
          visible: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const Key('debug-bg-service')), findsOneWidget);
    expect(find.byKey(const Key('debug-bg-notif')), findsOneWidget);
    expect(find.byKey(const Key('debug-bg-battery')), findsOneWidget);
    expect(find.byKey(const Key('debug-bg-lifecycle')), findsOneWidget);
    expect(find.byKey(const Key('debug-bg-heartbeat')), findsOneWidget);
    expect(find.text('bg: running'), findsOneWidget);
    expect(find.text('notif: granted'), findsOneWidget);
    expect(find.text('battery: unrestricted'), findsOneWidget);
    expect(find.text('lifecycle: resumed'), findsOneWidget);
    expect(find.textContaining('heartbeat:'), findsOneWidget);
    expect(find.textContaining('ago'), findsOneWidget);
  });

  testWidgets('iOS battery shows n/a in debug lines', (tester) async {
    final bus = PopmundoEventBus();
    const status = BackgroundStatus(
      notificationGranted: false,
      batteryUnrestricted: null,
      serviceRunning: false,
      lifecycle: AppLifecycleState.paused,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          backgroundStatus: status,
          visible: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('battery: n/a'), findsOneWidget);
    expect(find.text('notif: denied'), findsOneWidget);
    expect(find.text('bg: stopped'), findsOneWidget);
    expect(find.text('lifecycle: paused'), findsOneWidget);
    expect(find.text('heartbeat: never'), findsOneWidget);
  });

  testWidgets('tapping debug-close invokes onClose, and visible:false hides the panel', (tester) async {
    final bus = PopmundoEventBus();
    var closeCount = 0;

    Widget harness(bool visible) {
      return MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          visible: visible,
          onClose: () => closeCount++,
          child: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(harness(true));
    expect(find.byKey(const Key('debug-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('debug-close')));
    await tester.pump();
    expect(closeCount, 1);

    await tester.pumpWidget(harness(false));
    await tester.pump();
    expect(find.byKey(const Key('debug-panel')), findsNothing);
  });

  testWidgets('send-notification button renders with fixed English label', (
    tester,
  ) async {
    final bus = PopmundoEventBus();
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          notificationService: FakeNotificationService(),
          visible: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const Key('debug-send-notification')), findsOneWidget);
    expect(find.text('send test notification'), findsOneWidget);
  });

  testWidgets(
    'tapping send-notification requests permission and shows a notification when granted',
    (tester) async {
      final bus = PopmundoEventBus();
      final service = FakeNotificationService(permissionGranted: true);
      await tester.pumpWidget(
        MaterialApp(
          home: DebugOverlay(
            host: HostTracker(),
            events: bus,
            evaluate: (source) async => source,
            notificationService: service,
            visible: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('debug-send-notification')));
      await tester.pumpAndSettle();

      expect(service.requestPermissionCalls, 1);
      expect(service.showCalls, 1);
    },
  );

  testWidgets(
    'denied permission: no notification shown, no crash, panel stays interactive (NOTIF-05)',
    (tester) async {
      final bus = PopmundoEventBus();
      final service = FakeNotificationService(permissionGranted: false);
      await tester.pumpWidget(
        MaterialApp(
          home: DebugOverlay(
            host: HostTracker(),
            events: bus,
            evaluate: (source) async => source,
            notificationService: service,
            visible: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('debug-send-notification')));
      await tester.pumpAndSettle();

      expect(service.requestPermissionCalls, 1);
      expect(service.showCalls, 0, reason: 'denied permission must not show a notification');
      expect(find.byKey(const Key('debug-panel')), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('debug-send-notification')),
      );
      expect(
        button.onPressed,
        isNotNull,
        reason: 'panel must remain interactive after a denial',
      );

      // Panel is provably still usable: another control still responds.
      await tester.tap(find.byKey(const Key('debug-clear')));
      await tester.pump();
    },
  );

  testWidgets(
    'repeat tap while a request is in flight is ignored until it completes (NOTIF-06)',
    (tester) async {
      final bus = PopmundoEventBus();
      final service = FakeNotificationService(
        permissionGranted: true,
        showDelay: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DebugOverlay(
            host: HostTracker(),
            events: bus,
            evaluate: (source) async => source,
            notificationService: service,
            visible: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('debug-send-notification')));
      await tester.pump();

      // Still in flight: button must be disabled, so a second tap is inert.
      final inFlightButton = tester.widget<TextButton>(
        find.byKey(const Key('debug-send-notification')),
      );
      expect(
        inFlightButton.onPressed,
        isNull,
        reason: 'button must be disabled while the first tap is in flight',
      );
      await tester.tap(find.byKey(const Key('debug-send-notification')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        service.requestPermissionCalls,
        1,
        reason: 'the in-flight repeat tap must not trigger a second request',
      );
      expect(
        service.showCalls,
        1,
        reason: 'the system tray must never show more than one such notification at once',
      );
    },
  );

  testWidgets(
    'showTestNotification throwing is caught and never crashes the panel (NOTIF-08)',
    (tester) async {
      final bus = PopmundoEventBus();
      await tester.pumpWidget(
        MaterialApp(
          home: DebugOverlay(
            host: HostTracker(),
            events: bus,
            evaluate: (source) async => source,
            notificationService: _ThrowingNotificationService(),
            visible: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('debug-send-notification')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debug-panel')), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('debug-send-notification')),
      );
      expect(
        button.onPressed,
        isNotNull,
        reason: 'a thrown error must not leave the button stuck disabled, and must not crash the panel',
      );
    },
  );
}
