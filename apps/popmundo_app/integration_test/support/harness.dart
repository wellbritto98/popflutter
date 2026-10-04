// Shared support for the device-real test tier.
//
// This file is the single place that knows what `lib/main.dart` does at boot.
// Under integration_test/Patrol the Dart entrypoint is the TEST FILE, so
// `main()` in lib/main.dart never runs — anything it sets up must be redone
// here or the tests fail for reasons unrelated to what they assert.
//
// See .specs/features/mobile-e2e-tests/design.md (Architecture Overview).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/background/background_status.dart';

/// Title of the persistent keepalive notification, as posted by
/// [FlutterForegroundTaskPlatform.startService]. KA-05 asserts on this exact
/// string, so it lives in one place rather than being retyped per test.
const keepaliveNotificationTitle = 'Popmundo is running';

var _commsInitialised = false;

/// Mirrors `lib/main.dart:13` — `FlutterForegroundTask.initCommunicationPort()`.
///
/// The plugin requires this before any task-data callback can fire. Without it
/// the TaskHandler isolate sends heartbeats into a void and KA-03 fails for an
/// infrastructure reason rather than a real defect. Idempotent so every test
/// can call it without coordinating.
void initForegroundComms() {
  if (_commsInitialised) return;
  _commsInitialised = true;
  FlutterForegroundTask.initCommunicationPort();
}

/// Pumps [child] inside a minimal [MaterialApp].
///
/// Deliberately NOT `PopmundoApp` — that constructs `InAppPopmundoRuntime`,
/// which navigates to popmundo.com. The device tier never loads the live game
/// (CLAUDE.md hard constraint), and this is where that is enforced.
Future<void> pumpHarness(PatrolIntegrationTester $, Widget child) {
  return $.pumpWidgetAndSettle(MaterialApp(home: Scaffold(body: child)));
}

/// Grants the notification permission only if the OS actually asked.
///
/// `clearPackageData=true` resets runtime grants between runs, but an OEM skin
/// may auto-grant or present nothing. Guarding on visibility keeps the test
/// from hanging on a dialog that never appears.
Future<void> grantNotificationsIfAsked(PatrolIntegrationTester $) async {
  final permission = await FlutterForegroundTask.checkNotificationPermission()
      .timeout(const Duration(seconds: 5));
  if (permission == NotificationPermission.granted) return;
  if (await $.platform.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 15),
  )) {
    await $.platform.mobile.grantPermissionWhenInUse();
  }
}

/// Denies the notification permission only if the OS actually asked.
///
/// Mirror of [grantNotificationsIfAsked] for tests that need to prove the
/// denial path on the real OS dialog (e.g. NOTIF-05) rather than skip it.
/// Same visibility guard: a device that already resolved the permission (in
/// either direction) shows no dialog, and an unguarded await would hang.
Future<void> denyNotificationsIfAsked(PatrolIntegrationTester $) async {
  if (await $.platform.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 5),
  )) {
    await $.platform.mobile.denyPermission();
  }
}

/// Answers the battery-optimisation exemption dialog if Android raised one.
///
/// This is NOT a runtime permission, so `grantPermissionWhenInUse()` does not
/// cover it: `BackgroundKeepalive.bootstrap()` calls
/// `requestIgnoreBatteryOptimization()`, which fires
/// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, and Android answers with its
/// own system dialog ("Allow … to run in the background?"). Left unanswered it
/// sits on top of the app and breaks the notification-shade assertions.
///
/// Tries each known affirmative label in turn; a miss throws, which just means
/// "not this label, or no dialog at all", so it is swallowed. Fully absent
/// dialog (device already exempt) is skipped after checking actual OS state.
Future<void> grantBackgroundExemptionIfAsked(PatrolIntegrationTester $) async {
  final exempt = await FlutterForegroundTask.isIgnoringBatteryOptimizations
      .timeout(const Duration(seconds: 5));
  if (exempt) return;
  const labels = ['Allow', 'ALLOW', 'Permitir', 'PERMITIR'];
  for (final label in labels) {
    try {
      await $.platform.mobile.tap(
        Selector(text: label),
        timeout: const Duration(seconds: 3),
      );
      return;
    } catch (_) {
      // Not this label, or no dialog is showing — try the next one.
    }
  }
}

/// Stops the foreground service so the app process is free to terminate.
///
/// Patrol runs ONE Dart test per app process: `PatrolAppService` builds its
/// `_testExecutionRequested` / `_testExecutionCompleted` completers once as
/// `final` fields (patrol-4.9.0 `patrol_app_service_io.dart:80,86`) and never
/// recycles them, so a second `runDartTest` on the same instance trips
/// `assert(_testExecutionCompleted.isCompleted == false)` at line 163 and the
/// native side sees HTTP 500.
///
/// The keepalive service is configured to survive exactly that kind of
/// teardown (`stopWithTask: false`, `allowAutoRestart: true`), so without an
/// explicit stop the feature under test defeats the runner's per-test
/// isolation: test 1 passes, every later test dies instantly.
Future<void> stopKeepaliveService() async {
  await FlutterForegroundTask.stopService();
}

/// Waits until [status] has reported [count] **distinct** heartbeats.
///
/// Returns them in arrival order. Distinctness matters: a single tick would
/// also be produced by a stuck clock or one stale delivery, so KA-03 requires
/// two and asserts the second is strictly later.
///
/// Throws [TimeoutException] naming how many ticks arrived, so a failure is
/// diagnosable from the report alone (E2E-04) instead of hanging the suite.
Future<List<DateTime>> waitForTicks(
  ValueNotifier<BackgroundStatus> status, {
  int count = 2,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final ticks = <DateTime>[];

  void record(DateTime? tick) {
    if (tick == null) return;
    if (ticks.isNotEmpty && ticks.last == tick) return;
    ticks.add(tick);
  }

  record(status.value.lastHeartbeat);
  if (ticks.length >= count) return ticks;

  final completer = Completer<List<DateTime>>();
  void listener() {
    record(status.value.lastHeartbeat);
    if (ticks.length >= count && !completer.isCompleted) {
      completer.complete(List.of(ticks));
    }
  }

  status.addListener(listener);
  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Expected $count distinct heartbeats within ${timeout.inSeconds}s, '
        'received ${ticks.length}: $ticks',
      ),
    );
  } finally {
    status.removeListener(listener);
  }
}

/// Polls [probe] until it returns `true`, or throws [TimeoutException].
///
/// Used instead of a bare `await` on service state so a foreground service
/// that never starts fails the assertion within a bound rather than hanging.
Future<void> waitUntil(
  Future<bool> Function() probe, {
  required String description,
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await probe()) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException(
    'Timed out after ${timeout.inSeconds}s waiting for: $description',
  );
}

/// Bounds bootstrap after answering system prompts, with state diagnostics.
/// A frozen Android permission activity/SystemUI must fail instead of leaving
/// the instrumentation runner waiting indefinitely for its native callback.
Future<void> waitForKeepaliveBootstrap(
  Future<void> bootstrap,
  ValueNotifier<BackgroundStatus> status, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return bootstrap.timeout(
    timeout,
    onTimeout: () {
      final state = status.value;
      throw TimeoutException(
        "Keepalive bootstrap stalled; notification=${state.notifLabel}, "
        "battery=${state.batteryLabel}, service=${state.bgLabel}, "
        "lifecycle=${state.lifecycleLabel}. "
        "Check Android permission dialog or SystemUI ANR.",
        timeout,
      );
    },
  );
}
