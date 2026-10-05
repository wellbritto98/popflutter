// Standalone non-game entrypoint. Reboot kills instrumentation; ADB inspects
// production FGS callback, durable claim/result and Android tray without UI.
import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/background/background_keepalive.dart';
import 'package:popmundo_app/background/keepalive_task_handler.dart';
import 'package:popmundo_app/l10n.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_connection.dart';
import 'package:popmundo_app/scheduler/scheduler_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

const fixtureRuleId = 'e2e-lifecycle';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await EasyLocalization.ensureInitialized();
  final rawZone = await FlutterTimezone.getLocalTimezone().timeout(
    const Duration(seconds: 5),
  );
  debugPrint('scheduler.fixture rawZone=${rawZone.identifier}');
  final platform = FlutterForegroundTaskPlatform();
  final keepalive = BackgroundKeepalive(platform: platform);
  await platform.initService();
  if (!await platform.isRunningService()) {
    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Scheduler fixture running',
      notificationText: 'Non-game Android lifecycle evidence',
      callback: keepaliveStartCallback,
    );
    if (result is ServiceRequestFailure) throw result.error;
  }
  final client = SchedulerClient(
    send: FlutterForegroundTask.sendDataToTask,
    addListener: FlutterForegroundTask.addTaskDataCallback,
    removeListener: FlutterForegroundTask.removeTaskDataCallback,
    ensureRunning: () => waitForSchedulerService(keepalive, platform),
  );
  var snapshot = await client.list();
  if (!snapshot.rules.any((rule) => rule.id == fixtureRuleId)) {
    snapshot = await client.create(_draft(false), id: fixtureRuleId);
  }
  debugPrint(
    'scheduler.fixture stage=lifecycle-ready snapshot=${jsonEncode(snapshot.toJson())}',
  );
  runApp(
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
          home: Scaffold(
            appBar: AppBar(title: const Text('Fixture Android')),
            body: Column(
              children: [
                FilledButton(
                  onPressed: () => unawaited(_stageReboot(client)),
                  child: const Text('Preparar reboot'),
                ),
                FilledButton(
                  onPressed: () =>
                      unawaited(_stageWeekly(client, rawZone.identifier)),
                  child: const Text('Preparar semanal GMT'),
                ),
                Expanded(
                  child: SchedulerScreen(api: client, platform: platform),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

ScheduleDraft _draft(bool reboot) => ScheduleDraft(
  name: reboot ? 'Reboot fixture' : 'Lifecycle fixture',
  recurrence: IntervalRecurrence(
    quantity: reboot ? 180 : 10,
    unit: IntervalUnit.seconds,
    anchorUtc: DateTime.now().toUtc(),
  ),
  action: LocalNotificationAction(
    title: reboot ? 'Scheduler reboot fixture' : 'Scheduler lifecycle fixture',
    body: reboot
        ? 'Next future occurrence only'
        : 'Home lock and Recents evidence',
  ),
);

Future<void> _stageReboot(SchedulerClient client) async {
  final snapshot = await client.list();
  final rule = snapshot.rules.singleWhere((r) => r.id == fixtureRuleId);
  final updated = await client.update(rule, _draft(true));
  debugPrint(
    'scheduler.fixture stage=reboot-ready snapshot=${jsonEncode(updated.toJson())}',
  );
}

Future<void> _stageWeekly(SchedulerClient client, String nativeZone) async {
  if (nativeZone != 'GMT') {
    throw StateError('GMT fixture requires actual native GMT, got $nativeZone');
  }
  final now = DateTime.now().toUtc();
  final target = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 2));
  var catalog = await client.list();
  for (final rule in catalog.rules.where((rule) => rule.enabled)) {
    await client.toggle(rule, false);
  }
  catalog = await client.list();
  for (final rule in catalog.rules) {
    await FlutterLocalNotificationsPlugin().cancel(id: rule.notificationId);
  }
  for (final rule in catalog.rules.where(
    (rule) => rule.id == 'e2e-weekly-gmt',
  )) {
    await client.delete(rule);
  }
  final snapshot = await client.create(
    ScheduleDraft(
      name: 'Weekly GMT fixture',
      recurrence: WeeklyRecurrence(
        weekdays: {target.weekday},
        hour: target.hour,
        minute: target.minute,
      ),
      action: LocalNotificationAction(
        title: 'Scheduler weekly GMT fixture',
        body: 'GMT alias database evidence',
      ),
    ),
    id: 'e2e-weekly-gmt',
  );
  final rule = snapshot.rules.singleWhere(
    (rule) => rule.id == 'e2e-weekly-gmt',
  );
  if (rule.zoneId != nativeZone || rule.nextDueUtc != target) {
    throw StateError(
      'Weekly native GMT mismatch: expected $target / $nativeZone; '
      'got ${rule.nextDueUtc} / ${rule.zoneId}',
    );
  }
  debugPrint(
    'scheduler.fixture stage=weekly-ready expectedUtc=${target.toIso8601String()} '
    'nativeZone=$nativeZone snapshot=${jsonEncode(snapshot.toJson())}',
  );
}
