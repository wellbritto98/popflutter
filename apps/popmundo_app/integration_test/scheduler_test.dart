// One Patrol test. Real foreground engine/prefs/OS tray; never a game WebView.
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/background/background_keepalive.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/l10n.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_connection.dart';
import 'package:popmundo_app/scheduler/scheduler_screen.dart';
import 'package:popmundo_app/scheduler/scheduler_store.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

Future<SchedulerSnapshot> _durable() async {
  final raw = await PreferencesSchedulerStore(
    await SharedPreferences.getInstance(),
  ).read();
  if (raw == null) throw StateError('Scheduler snapshot was not persisted');
  return SchedulerSnapshot.decode(raw);
}

Future<void> _assertAndroidIds(Set<int> expected) async {
  final active = await FlutterLocalNotificationsPlugin()
      .getActiveNotifications();
  final scheduled = active.where((n) => n.id != null && n.id! < 0);
  expect(
    scheduled,
    hasLength(expected.length),
    reason: "SCHED-07/08: exact total scheduled OS records",
  );
  expect(
    scheduled.map((n) => n.id),
    unorderedEquals(expected),
    reason: "SCHED-07: complete distinct negative ID set",
  );
}

Future<void> _assertAndroidCard(
  ScheduledRule rule,
  String title,
  String body,
) async {
  final active = await FlutterLocalNotificationsPlugin()
      .getActiveNotifications();
  final card = active.where((n) => n.id == rule.notificationId);
  expect(
    card,
    hasLength(1),
    reason: "SCHED-07: one real NotificationManager record for signed ID",
  );
  expect(card.single.title, title, reason: "SCHED-07: real ID has exact title");
  expect(card.single.body, body, reason: "SCHED-07: real ID has exact body");
  expect(
    active.where((n) => n.title == title),
    hasLength(1),
    reason: "SCHED-07: no second OS record with same title",
  );
}

ScheduleDraft _draft(String title, String body, int seconds) => ScheduleDraft(
  name: title,
  recurrence: IntervalRecurrence(
    quantity: seconds,
    unit: IntervalUnit.seconds,
    anchorUtc: DateTime.now().toUtc(),
  ),
  action: LocalNotificationAction(title: title, body: body),
);

void main() {
  patrolTest('scheduler: durable seconds, Home, real cards and pause', (
    $,
  ) async {
    initForegroundComms();
    await EasyLocalization.ensureInitialized();
    final platform = FlutterForegroundTaskPlatform();
    final keepalive = BackgroundKeepalive(platform: platform);
    final client = SchedulerClient(
      send: FlutterForegroundTask.sendDataToTask,
      addListener: FlutterForegroundTask.addTaskDataCallback,
      removeListener: FlutterForegroundTask.removeTaskDataCallback,
      ensureRunning: () => waitForSchedulerService(keepalive, platform),
    );
    addTearDown(client.dispose);
    addTearDown(keepalive.dispose);
    addTearDown(() async {
      await stopKeepaliveService();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SchedulerSnapshot.storageKey);
      for (final id in [-1, -2, -3]) {
        await FlutterLocalNotificationsPlugin().cancel(id: id);
      }
    });
    await pumpHarness($, const Text('scheduler bootstrap fixture'));
    final bootstrap = keepalive.bootstrap();
    await grantNotificationsIfAsked($);
    await grantBackgroundExemptionIfAsked($);
    await waitForKeepaliveBootstrap(bootstrap, keepalive.status);
    expect(
      await platform.isRunningService(),
      isTrue,
      reason: 'SCHED-08: actual FGS',
    );
    await client.list();
    await $.pumpWidgetAndSettle(
      EasyLocalization(
        supportedLocales: supportedAppLocales,
        path: kTranslationsPath,
        fallbackLocale: fallbackAppLocale,
        startLocale: const Locale('pt'),
        saveLocale: false,
        useOnlyLangCode: true,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: SchedulerScreen(api: client, platform: platform),
          ),
        ),
      ),
    );
    expect(
      find.text('Agendamentos'),
      findsOneWidget,
      reason: 'SCHED-01: native Portuguese page',
    );
    await $(const Key('schedule-add')).tap();
    await $(const Key('schedule-name')).enterText('Lembrete pela tela');
    await $(const Key('schedule-enabled')).tap();
    await $.tester.ensureVisible(find.byKey(const Key('schedule-title')));
    await $(const Key('schedule-title')).enterText('Título salvo pela tela');
    await $.tester.ensureVisible(find.byKey(const Key('schedule-body')));
    await $(const Key('schedule-body')).enterText('Mensagem nativa persistida');
    await $(const Key('schedule-save')).tap();
    await $.pumpAndSettle();
    final ui = (await _durable()).rules.single;
    expect(
      ui.name,
      'Lembrete pela tela',
      reason: 'SCHED-03: real form persisted name',
    );
    expect(
      ui.action.title,
      'Título salvo pela tela',
      reason: 'SCHED-02/03: exact title',
    );
    expect(
      ui.action.body,
      'Mensagem nativa persistida',
      reason: 'SCHED-02/03: exact body',
    );
    expect(
      ui.enabled,
      isFalse,
      reason: 'SCHED-03: native switch saves paused rule',
    );
    debugPrint('scheduler.e2e stage=screen-ready');
    await Future<void>.delayed(const Duration(seconds: 10));

    await client.create(
      _draft('Scheduler Home A', 'Home first body', 10),
      id: 'e2e-a',
    );
    await client.create(
      _draft('Scheduler Home B', 'Independent second body', 13),
      id: 'e2e-b',
    );
    final saved = await _durable();
    final a = saved.rules.singleWhere((r) => r.id == 'e2e-a');
    final b = saved.rules.singleWhere((r) => r.id == 'e2e-b');
    expect(
      a.notificationId,
      lessThan(0),
      reason: 'SCHED-07: signed negative ID',
    );
    expect(
      b.notificationId,
      lessThan(0),
      reason: 'SCHED-07: signed negative ID',
    );
    expect(
      a.notificationId,
      isNot(b.notificationId),
      reason: 'SCHED-07: rule IDs differ',
    );
    expect(
      a.action.title,
      'Scheduler Home A',
      reason: 'SCHED-07: persisted exact title',
    );
    expect(
      a.action.body,
      'Home first body',
      reason: 'SCHED-07: persisted exact body',
    );
    await $.platform.mobile.pressHome();
    final homeAt = DateTime.now().toUtc();
    await waitUntil(
      () async {
        final r = (await _durable()).rules.singleWhere((r) => r.id == a.id);
        return r.lastResult.status == ScheduleResultStatus.submitted &&
            r.lastClaim!.plannedUtc.isAfter(homeAt);
      },
      description: 'first real occurrence while Home',
      timeout: const Duration(seconds: 35),
    );
    final first = (await _durable()).rules.singleWhere((r) => r.id == a.id);
    await waitUntil(
      () async {
        final r = (await _durable()).rules.singleWhere((r) => r.id == a.id);
        return r.lastResult.status == ScheduleResultStatus.submitted &&
            r.lastClaim!.plannedUtc.isAfter(first.lastClaim!.plannedUtc);
      },
      description: 'second distinct Home occurrence',
      timeout: const Duration(seconds: 35),
    );
    final second = (await _durable()).rules.singleWhere((r) => r.id == a.id);
    expect(
      second.lastClaim!.plannedUtc.isAfter(first.lastClaim!.plannedUtc),
      isTrue,
      reason: 'SCHED-04/08: seconds recurrence advances before reopening',
    );
    expect(
      second.lastResult.atUtc!.isAfter(first.lastResult.atUtc!),
      isTrue,
      reason: 'SCHED-08: distinct real background submissions',
    );
    await $.platform.mobile.openNotifications();
    var tray = await $.platform.mobile.getNotifications();
    await _assertAndroidIds({a.notificationId, b.notificationId});
    await _assertAndroidCard(a, "Scheduler Home A", "Home first body");
    await _assertAndroidCard(b, "Scheduler Home B", "Independent second body");
    final firstCards = tray.where((n) => n.title == 'Scheduler Home A');
    final secondCards = tray.where((n) => n.title == 'Scheduler Home B');
    expect(
      firstCards.map((n) => (n.title, n.content)).toSet(),
      hasLength(1),
      reason: 'SCHED-07: one actual card per rule',
    );
    expect(
      firstCards.first.content,
      'Home first body',
      reason: 'SCHED-07: Android exact body',
    );
    expect(
      secondCards.map((n) => (n.title, n.content)).toSet(),
      hasLength(1),
      reason: 'SCHED-07: separate second OS card',
    );
    expect(
      secondCards.first.content,
      'Independent second body',
      reason: 'SCHED-07: second body',
    );
    await $.platform.mobile.pressHome();
    debugPrint("scheduler.e2e stage=first-cards-ready");
    await Future<void>.delayed(const Duration(seconds: 8));
    final updated = (await client.update(
      second,
      _draft('Scheduler Home A updated', 'Updated same card body', 10),
    )).rules.singleWhere((r) => r.id == a.id);
    expect(
      updated.notificationId,
      a.notificationId,
      reason: 'SCHED-07: edit preserves ID',
    );
    expect(
      (updated.recurrence as IntervalRecurrence).anchorUtc,
      (a.recurrence as IntervalRecurrence).anchorUtc,
      reason: 'SCHED-03/04: text edit preserves cadence',
    );
    await waitUntil(
      () async {
        final r = (await _durable()).rules.singleWhere((r) => r.id == a.id);
        return r.lastClaim!.revision == updated.revision &&
            r.lastResult.status == ScheduleResultStatus.submitted;
      },
      description: 'edited real notification while Home',
      timeout: const Duration(seconds: 35),
    );
    await $.platform.mobile.openNotifications();
    tray = await $.platform.mobile.getNotifications();
    expect(
      tray.where((n) => n.title == 'Scheduler Home A'),
      isEmpty,
      reason: 'SCHED-07: prior card replaced',
    );
    await _assertAndroidIds({a.notificationId, b.notificationId});
    await _assertAndroidCard(
      updated,
      "Scheduler Home A updated",
      "Updated same card body",
    );
    final changed = tray.where((n) => n.title == 'Scheduler Home A updated');
    expect(
      changed.map((n) => (n.title, n.content)).toSet(),
      hasLength(1),
      reason: 'SCHED-07: updated same card',
    );
    expect(
      changed.first.content,
      'Updated same card body',
      reason: 'SCHED-07: exact edited payload',
    );
    debugPrint(
      'scheduler.e2e stage=cards-ready snapshot=${jsonEncode((await _durable()).toJson())}',
    );
    await Future<void>.delayed(const Duration(seconds: 8));
    await $.platform.mobile.pressHome();
    var current = await client.list();
    await client.toggle(current.rules.singleWhere((r) => r.id == a.id), false);
    current = await client.list();
    await client.toggle(current.rules.singleWhere((r) => r.id == b.id), false);
    final paused = await _durable();
    for (final r in paused.rules.where((r) => r.id == a.id || r.id == b.id)) {
      expect(r.enabled, isFalse, reason: 'SCHED-03/08: durable disable');
      expect(
        r.nextDueUtc,
        isNull,
        reason: 'SCHED-08: disabled rule has no armed due',
      );
      await FlutterLocalNotificationsPlugin().cancel(id: r.notificationId);
    }
    await Future<void>.delayed(const Duration(seconds: 28));
    await _assertAndroidIds({});
    final later = await _durable();
    for (final r in paused.rules) {
      final after = later.rules.singleWhere((other) => other.id == r.id);
      expect(
        after.lastClaim?.plannedUtc,
        r.lastClaim?.plannedUtc,
        reason: 'SCHED-03/10: disabled rule never claimed a later slot',
      );
      expect(
        after.lastResult.atUtc,
        r.lastResult.atUtc,
        reason: 'SCHED-08: disabled result never advanced',
      );
    }
    await $.platform.mobile.openNotifications();
    tray = await $.platform.mobile.getNotifications();
    expect(
      tray.where((n) => n.title.startsWith('Scheduler Home')),
      isEmpty,
      reason: 'SCHED-08: disabled rules post no new cards',
    );
    expect(
      await platform.isRunningService(),
      isTrue,
      reason: 'SCHED-08: stopping last rule preserves keepalive',
    );
    debugPrint(
      'scheduler.e2e stage=paused-ready snapshot=${jsonEncode(later.toJson())}',
    );
    await Future<void>.delayed(const Duration(seconds: 8));
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
  });
}
