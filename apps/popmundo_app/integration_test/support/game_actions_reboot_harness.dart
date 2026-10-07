// Standalone: real reboot ends Patrol instrumentation. ADB inspects only the
// synthetic package, persisted sanitized oracle, FGS, Activities and notices.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:popmundo_app/autologin/secure_secret_store.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_actions_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final prefs = await SharedPreferences.getInstance();
  final platform = FlutterForegroundTaskPlatform();
  await platform.initService();
  final client = SchedulerClient(
    send: FlutterForegroundTask.sendDataToTask,
    addListener: FlutterForegroundTask.addTaskDataCallback,
    removeListener: FlutterForegroundTask.removeTaskDataCallback,
    ensureRunning: () async {},
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Game engine fixture')),
        body: Column(
          children: [
            FilledButton(
              onPressed: () => unawaited(_prepare(prefs, client, false)),
              child: const Text('Prepare Recents'),
            ),
            FilledButton(
              onPressed: () => unawaited(_prepare(prefs, client, true)),
              child: const Text('Prepare interrupted reboot'),
            ),
            FilledButton(
              onPressed: () => unawaited(_cleanup(prefs)),
              child: const Text('Clean synthetic data'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _prepare(
  SharedPreferences prefs,
  SchedulerClient client,
  bool hold,
) async {
  await FlutterForegroundTask.stopService();
  await prefs.remove(fixtureOracleKey);
  await prefs.remove(SchedulerSnapshot.storageKey);
  await prefs.setBool(fixtureHoldKey, hold);
  await prefs.setString('locale', 'en');
  await prefs.setString(
    AutoLoginSettingsStore.defaultStorageKey,
    jsonEncode({'username': fixtureUsername, 'enabled': false, 'status': 1}),
  );
  await FlutterSecureSecretStore().write(
    AutoLoginSettingsStore.passwordSecretKey,
    fixturePassword,
  );
  await FlutterLocalNotificationsPlugin().cancelAll();
  final start = await FlutterForegroundTask.startService(
    serviceTypes: const [ForegroundServiceTypes.specialUse],
    notificationTitle: 'Game actions fixture',
    notificationText: 'Loopback only',
    callback: gameActionsFixtureCallback,
  );
  if (start is ServiceRequestFailure) throw start.error;
  var ready = false;
  for (var attempt = 0; attempt < 60; attempt++) {
    if ((await fixtureOracle())["boots"] == 1) {
      ready = true;
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (!ready) throw TimeoutException("Secondary fixture engine not ready");
  await client.create(
    ScheduleDraft(
      name: hold ? 'Interrupted reboot' : 'Removed Recents',
      recurrence: IntervalRecurrence(
        quantity: hold ? 90 : 20,
        unit: IntervalUnit.seconds,
        anchorUtc: DateTime.now().toUtc().subtract(
          Duration(seconds: hold ? 70 : 0),
        ),
      ),
      action: UseItemAction(
        boundUsername: fixtureUsername,
        character: GameCharacter(
          id: fixtureCharacterId,
          name: fixtureCharacterName,
        ),
        itemName: fixtureItemName,
      ),
    ),
    id: hold ? 'e2e-reboot' : 'e2e-recents',
  );
  debugPrint('game.fixture ready=${hold ? "reboot" : "recents"}');
}

Future<void> _cleanup(SharedPreferences prefs) async {
  await FlutterForegroundTask.stopService();
  await FlutterSecureSecretStore().delete(
    AutoLoginSettingsStore.passwordSecretKey,
  );
  await FlutterLocalNotificationsPlugin().cancelAll();
  for (final key in [
    fixtureOracleKey,
    fixtureHoldKey,
    AutoLoginSettingsStore.defaultStorageKey,
    SchedulerSnapshot.storageKey,
    'locale',
  ]) {
    await prefs.remove(key);
  }
}
