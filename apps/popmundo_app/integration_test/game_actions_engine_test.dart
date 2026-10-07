// One Patrol test; no visible game WebView and no live network destination.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/autologin/secure_secret_store.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/game_actions_fixture.dart';
import 'support/harness.dart';

void main() {
  patrolTest('secondary game engine: exact item and crew POSTs after Home', (
    $,
  ) async {
    initForegroundComms();
    await stopKeepaliveService();
    final prefs = await SharedPreferences.getInstance();
    final secrets = FlutterSecureSecretStore();
    addTearDown(() async {
      await stopKeepaliveService();
      await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
      for (final key in [
        fixtureOracleKey,
        fixtureHoldKey,
        AutoLoginSettingsStore.defaultStorageKey,
        SchedulerSnapshot.storageKey,
        'locale',
      ]) {
        await prefs.remove(key);
      }
      await FlutterLocalNotificationsPlugin().cancelAll();
    });
    await prefs.remove(fixtureOracleKey);
    await prefs.remove(SchedulerSnapshot.storageKey);
    await prefs.setBool(fixtureHoldKey, false);
    await prefs.setString('locale', 'en');
    await prefs.setString(
      AutoLoginSettingsStore.defaultStorageKey,
      jsonEncode({'username': fixtureUsername, 'enabled': false, 'status': 1}),
    );
    await secrets.write(
      AutoLoginSettingsStore.passwordSecretKey,
      fixturePassword,
    );
    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      fixturePassword,
      reason: 'SGA-10: real Keystore contains synthetic secret',
    );
    await pumpHarness($, const Text('Game engine loopback only'));
    final platform = FlutterForegroundTaskPlatform();
    await platform.initService();
    if (!await platform.isNotificationGranted()) {
      final asking = platform.requestNotificationPermission();
      await grantNotificationsIfAsked($);
      await asking;
    }
    expect(
      await platform.isNotificationGranted(),
      isTrue,
      reason: 'SGA-07: real Android notification grant',
    );
    await stopKeepaliveService();
    final started = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Game actions fixture',
      notificationText: 'Loopback only',
      callback: gameActionsFixtureCallback,
    );
    expect(
      started,
      isA<ServiceRequestSuccess>(),
      reason: 'SGA-10: real FGS starts secondary engine',
    );
    await waitUntil(
      () async => (await fixtureOracle())['boots'] == 1,
      description: 'FGS-owned loopback server',
      timeout: const Duration(seconds: 30),
    );
    final client = SchedulerClient(
      send: FlutterForegroundTask.sendDataToTask,
      addListener: FlutterForegroundTask.addTaskDataCallback,
      removeListener: FlutterForegroundTask.removeTaskDataCallback,
      ensureRunning: () async {},
    );
    addTearDown(client.dispose);
    await client.create(
      ScheduleDraft(
        name: 'Synthetic item',
        recurrence: IntervalRecurrence(
          quantity: 20,
          unit: IntervalUnit.seconds,
          anchorUtc: DateTime.now().toUtc(),
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
      id: 'e2e-item',
    );
    await FlutterLocalNotificationsPlugin().cancelAll();
    await $.platform.mobile.pressHome();
    await waitUntil(
      () async =>
          ((await fixtureOracle())['posts'] as List).length >= 2 &&
          (await fixtureSnapshot()).rules.single.lastResult.status ==
              ScheduleResultStatus.confirmed,
      description: 'two distinct confirmed item occurrences after Home',
      timeout: const Duration(seconds: 110),
    );
    final items = await fixtureOracle();
    final starts = items['starts'] as List;
    expect(
      starts.length,
      greaterThanOrEqualTo(2),
      reason: 'SGA-09/10: repeated execution needs two starts',
    );
    expect(
      starts[0]['slot'],
      isNot(starts[1]['slot']),
      reason: 'SGA-08: distinct planned slots, no replay',
    );
    expect(
      starts.every(
        (v) =>
            v['characterId'] == fixtureCharacterId &&
            v['notice'] == 'Executing Use item',
      ),
      isTrue,
      reason:
          'SGA-01/07: saved synthetic char and real start notice before HTTP',
    );
    expect(
      items['violations'],
      isEmpty,
      reason: 'SGA-03/04/05/07: empty jars, durable claim, exact POST and native start before every request',
    );
    final itemRule = (await fixtureSnapshot()).rules.single;
    expect(
      (itemRule.action as UseItemAction).character.name,
      fixtureCharacterName,
      reason: 'SGA-01: saved character label persists',
    );
    expect(
      jsonEncode(itemRule.toJson()).contains(fixturePassword),
      isFalse,
      reason: 'SGA-01: rule stores no secret',
    );
    final itemCards = await FlutterLocalNotificationsPlugin()
        .getActiveNotifications();
    final itemCard = itemCards.singleWhere(
      (n) => n.id == itemRule.notificationId,
    );
    expect(
      itemCard.title,
      'Use item: action confirmed',
      reason: 'SGA-07/08: same negative ID result replaces start',
    );
    expect(
      itemCard.body,
      'Character: Saved Character',
      reason: 'SGA-07: result names saved character',
    );
    await client.toggle(itemRule, false);
    await client.create(
      ScheduleDraft(
        name: 'Synthetic crew',
        recurrence: IntervalRecurrence(
          quantity: 20,
          unit: IntervalUnit.seconds,
          anchorUtc: DateTime.now().toUtc(),
        ),
        action: PayCrewAction(
          boundUsername: fixtureUsername,
          character: GameCharacter(
            id: fixtureCharacterId,
            name: fixtureCharacterName,
          ),
          artistId: 92002,
          artistName: 'Synthetic Band',
          bonusLevel: 20,
        ),
      ),
      id: 'e2e-crew',
    );
    await waitUntil(
      () async =>
          (await fixtureSnapshot()).rules
              .singleWhere((r) => r.id == 'e2e-crew')
              .lastResult
              .status ==
          ScheduleResultStatus.confirmed,
      description: 'crew bonus confirmed while Home',
      timeout: const Duration(seconds: 80),
    );
    final oracle = await fixtureOracle();
    expect(
      (oracle['posts'] as List).where((v) => v['kind'] == 'crew'),
      hasLength(1),
      reason: 'SGA-06: one exact chosen bonus 20 POST',
    );
    expect(
      oracle['violations'],
      isEmpty,
      reason: 'SGA-06/07: crew current full form, chosen quote and start card verified server-side',
    );
    final crewRule = (await fixtureSnapshot()).rules.singleWhere(
      (r) => r.id == 'e2e-crew',
    );
    final crew = crewRule.action as PayCrewAction;
    expect(
      [
        crew.boundUsername,
        crew.character.id,
        crew.artistId,
        crew.artistName,
        crew.bonusLevel,
        crew.maxCostMinor,
      ],
      [fixtureUsername, 91002, 92002, 'Synthetic Band', 20, null],
      reason: 'SGA-01/06: persisted chosen char, artist, default bonus and omitted cap',
    );
    final crewCards = await FlutterLocalNotificationsPlugin()
        .getActiveNotifications();
    expect(
      crewCards.singleWhere((n) => n.id == crewRule.notificationId).title,
      'Pay crew: action confirmed',
      reason: 'SGA-07: crew same-ID native result',
    );
    await client.toggle(crewRule, false);
  });
}
