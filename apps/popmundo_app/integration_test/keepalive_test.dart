// Device-real assertions for the background keepalive (KA-01..KA-06).
//
// These exercise the REAL FlutterForegroundTaskPlatform, the REAL Android
// foreground service, and the REAL KeepaliveTaskHandler isolate. Nothing here
// is faked — that is the whole point of this tier. The fake-based tier in
// apps/popmundo_app/test/background_keepalive_test.dart covers the
// orchestration logic and stays as-is.
//
// ONE patrolTest PER FILE — DO NOT ADD A SECOND ONE.
// Patrol can only run a single Dart test per app process: PatrolAppService's
// `_testExecutionRequested` / `_testExecutionCompleted` are `final` Completers
// built once and never recycled (patrol-4.9.0 patrol_app_service_io.dart:80,86),
// so a second runDartTest trips
//   assert(_testExecutionCompleted.isCompleted == false)   // line 163
// and the native side reports "Invalid response 500, Internal Server Error".
// This is an open upstream bug, not a misconfiguration here:
//   https://github.com/leancodepl/patrol/issues/2005
//   https://github.com/leancodepl/patrol/issues/2380  (closed as not planned)
// Reported non-fixes: merging tests into one file, `--wait 1`, different
// emulator images. The only confirmed workaround is one test per run — hence
// all six criteria live in a single sequential test below, which also happens
// to mirror a real app session more closely than six isolated ones would.
//
// Battery optimisation note: bootstrap() may call
// requestIgnoreBatteryOptimization(), which fires an Intent and returns
// without waiting — it does NOT block the test (verified on device). It can
// still raise a settings screen that steals focus. If that ever destabilises
// the shade assertions, waive it after install with:
//   adb -s <device> shell dumpsys deviceidle whitelist +com.popmundo.popmundo_app
//
// See .specs/features/mobile-e2e-tests/spec.md (P1: Keepalive real em device).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/background/background_keepalive.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';

import 'support/harness.dart';

void main() {
  patrolTest('keepalive: real FGS starts once, ticks, and survives background', (
    $,
  ) async {
    initForegroundComms();
    final platform = FlutterForegroundTaskPlatform();
    final keepalive = BackgroundKeepalive(platform: platform);
    addTearDown(keepalive.dispose);
    addTearDown(stopKeepaliveService);

    await pumpHarness($, const Text('keepalive harness'));

    // bootstrap() raises the notification dialog mid-flight, so it cannot be
    // awaited before granting — start it, answer the OS, then await.
    final bootstrapping = keepalive.bootstrap();
    await grantNotificationsIfAsked($);
    // bootstrap() also asks Android to waive battery optimisation, which opens
    // a separate system dialog that is NOT a runtime permission — unanswered,
    // it covers the app and breaks the shade assertions below.
    await grantBackgroundExemptionIfAsked($);
    await bootstrapping;
    await $.pumpAndSettle();

    // KA-01: the facade observed the service come up.
    expect(
      keepalive.status.value.serviceRunning,
      isTrue,
      reason: 'KA-01: bootstrap() did not bring the foreground service up',
    );

    // KA-02: and the real plugin agrees — not just our own bookkeeping.
    expect(
      await platform.isRunningService(),
      isTrue,
      reason: 'KA-02: plugin reports no running service despite KA-01 passing',
    );

    // KA-04: a fresh facade (as on app relaunch) must adopt the running
    // service rather than starting a second one.
    final second = BackgroundKeepalive(platform: platform);
    addTearDown(second.dispose);
    await second.bootstrap();
    await $.pumpAndSettle();

    expect(
      second.status.value.serviceRunning,
      isTrue,
      reason: 'KA-04: a second bootstrap did not adopt the running service',
    );
    expect(await platform.isRunningService(), isTrue, reason: 'KA-04');

    // KA-03: two DISTINCT ticks, not one — a single heartbeat would also be
    // produced by a stuck clock or one stale delivery. eventAction is
    // repeat(5000), so 30s is ample; on failure waitForTicks reports how many
    // actually landed.
    final before = await waitForTicks(keepalive.status);
    expect(
      before.length,
      greaterThanOrEqualTo(2),
      reason: 'KA-03: fewer than two heartbeats crossed the isolate boundary',
    );
    expect(
      before[1].isAfter(before[0]),
      isTrue,
      reason: 'KA-03: heartbeats did not advance — clock or isolate is stuck',
    );
    final lastBeforeBackground = before.last;

    await $.platform.mobile.pressHome();

    // KA-05: the persistent notification must still be in the shade. This is
    // exactly what AD-013 broke: stopWithTask="true" tore the service down the
    // moment the app left the foreground.
    await $.platform.mobile.openNotifications();
    final notifications = await $.platform.mobile.getNotifications();
    expect(
      notifications.map((n) => n.title),
      contains(keepaliveNotificationTitle),
      reason:
          'KA-05: keepalive notification vanished after backgrounding — this is '
          'the AD-013 failure mode (stopWithTask must be false in both '
          'AndroidManifest.xml and FlutterForegroundTaskPlatform.initService)',
    );

    // MobileAutomator has no back primitive; pressHome closes the shade.
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();

    // KA-06: surviving in the shade is not enough — the service must still be
    // running and the isolate must still be ticking.
    expect(
      await platform.isRunningService(),
      isTrue,
      reason: 'KA-06: service died while the app was backgrounded',
    );

    final after = await waitForTicks(
      keepalive.status,
      count: before.length + 1,
    );
    expect(
      after.last.isAfter(lastBeforeBackground),
      isTrue,
      reason: 'KA-06: heartbeat stopped advancing after backgrounding',
    );
  });
}
