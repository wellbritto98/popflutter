// Device-real assertions for the debug-panel test notification (NOTIF-01,
// NOTIF-03, NOTIF-04, NOTIF-05, NOTIF-07).
//
// These exercise the REAL LocalNotificationsService, the REAL
// flutter_local_notifications plugin channel, and the REAL Android
// permission dialog/system tray. Nothing here is faked — the fast-tier
// widget test (apps/popmundo_app/test/debug_overlay_test.dart) already
// proves DebugOverlay's own guard/try-catch logic against
// FakeNotificationService and stays as-is; this file's whole point is the
// plumbing the fast tier structurally cannot reach.
//
// ONE patrolTest PER FILE — DO NOT ADD A SECOND ONE.
// Patrol can only run a single Dart test per app process: PatrolAppService's
// `_testExecutionRequested` / `_testExecutionCompleted` are `final`
// Completers built once and never recycled (patrol-4.9.0
// patrol_app_service_io.dart:80,86), so a second runDartTest trips
//   assert(_testExecutionCompleted.isCompleted == false)   // line 163
// and the native side reports "Invalid response 500, Internal Server Error".
// See keepalive_test.dart for the full citation. Hence NOTIF-03/04/05 are
// sequenced as one flow below, with a `reason:` on every expect.
//
// Deny-then-grant sequencing note: Android shows the POST_NOTIFICATIONS
// system dialog again after a single plain "Deny" (no "don't ask again" was
// selected — denyPermission() taps the plain deny action), so one denial
// followed by one grant is exercised on the SAME fresh permission state,
// each via the real OS dialog. This also means NOTIF-04 (grant) must run
// strictly after NOTIF-05 (deny) in this file — reversing the order would
// leave no way to un-grant the permission again without device shell access.
//
// See .specs/features/local-notifications/spec.md (NOTIF-01..08) and
// .specs/features/local-notifications/design.md (notifications_test.dart
// component).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/debug_overlay.dart';
import 'package:popmundo_app/notifications/local_notifications_service.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'support/harness.dart';

void main() {
  patrolTest(
    'notifications: deny keeps the tray clean and the panel usable, grant '
    'posts the fixed notification',
    ($) async {
      final service = LocalNotificationsService();
      await service.initialize();

      // Do not closeNotifications() in tearDown. Patrol documents that call
      // as undefined unless the shade is visible (native impl: pressBack).
      // After the body already closed the shade, a second call hung as
      // native step 13 (Gradle exit 1, Successful:0/Failed:0). Leftover
      // tray content is replaced in place on the next grant (NOTIF-07).

      final bus = PopmundoEventBus();
      await pumpHarness(
        $,
        DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          notificationService: service,
          visible: true,
          child: const SizedBox.expand(),
        ),
      );

      // --- NOTIF-03 / NOTIF-05: first tap, deny the real OS dialog ---
      await $.tap(find.byKey(const Key('debug-send-notification')));
      await denyNotificationsIfAsked($);
      await $.pumpAndSettle();

      await $.platform.mobile.openNotifications();
      final afterDeny = await $.platform.mobile.getNotifications();
      expect(
        afterDeny.map((n) => n.title),
        isNot(contains(kTestNotificationTitle)),
        reason:
            'NOTIF-05: a denied permission must never post the test '
            'notification, but the tray contains one titled '
            '"$kTestNotificationTitle"',
      );
      await $.platform.mobile.closeNotifications();

      expect(
        find.byKey(const Key('debug-panel')),
        findsOneWidget,
        reason:
            'NOTIF-05: the debug panel must remain mounted after a '
            'permission denial',
      );
      final buttonAfterDeny = $.tester.widget<TextButton>(
        find.byKey(const Key('debug-send-notification')),
      );
      expect(
        buttonAfterDeny.onPressed,
        isNotNull,
        reason:
            'NOTIF-05: the button must not be left stuck-disabled after a '
            'denial — the panel must stay interactive',
      );

      // --- NOTIF-01 / NOTIF-03 / NOTIF-04 / NOTIF-07: second tap, grant ---
      await $.tap(find.byKey(const Key('debug-send-notification')));
      await grantNotificationsIfAsked($);
      await $.pumpAndSettle();

      await $.platform.mobile.openNotifications();
      final afterGrant = await $.platform.mobile.getNotifications();
      final posted = afterGrant.where((n) => n.title == kTestNotificationTitle);
      expect(
        posted,
        isNotEmpty,
        reason:
            'NOTIF-01/NOTIF-04: granting the permission must post exactly '
            'one notification titled "$kTestNotificationTitle" — an empty '
            'tray here means either the plugin never initialized (NOTIF-01) '
            'or showTestNotification() never fired after grant (NOTIF-04)',
      );
      expect(
        posted.first.content,
        kTestNotificationBody,
        reason:
            'NOTIF-04: the posted notification must carry the fixed body '
            'text "$kTestNotificationBody"',
      );
      expect(
        posted.length,
        1,
        reason:
            'NOTIF-07: the fixed notification id must replace rather than '
            'stack — the tray must never show more than one at once',
      );
      await $.platform.mobile.closeNotifications();
    },
  );
}
