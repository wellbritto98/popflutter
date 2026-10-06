import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/game_credentials.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_environment.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scheduler_runtime_test.dart' show Store;

class Discovery implements GameActionsApi {
  final char = GameCharacter(id: 42, name: 'Saved Character');
  String? account;
  int? characterId;
  String? failure;
  @override
  Future<GameCharacterCatalog> discoverCharacters() async {
    if (failure != null) throw GameActionException(failure!);
    return GameCharacterCatalog(username: 'bound', characters: [char]);
  }

  @override
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  }) async {
    account = boundUsername;
    characterId = character.id;
    return [GameItemChoice(name: 'Exact Item')];
  }

  @override
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) async => GameCrewOptions(
    artistId: 77,
    artistName: 'Saved Band',
    bonuses: [GameBonusChoice(level: 14, label: 'notável', costMinor: 225000)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('DTO discovery RPC preserves account/character/options and never writes rules', () async {
    final discovery = Discovery();
    final store = Store();
    void Function(Object)? listener;
    final sent = <Map<String, Object?>>[];
    final runner = SchedulerRunner(
      coordinator: SchedulerCoordinator(
        store: store,
        executors: {},
        now: DateTime.now,
        zoneId: () => 'UTC',
      ),
      gameActions: discovery,
      refreshZone: () async {},
      configureBoot: (_) async {},
      notificationGranted: () async => true,
      send: (data) => listener!(data),
    );
    final client = SchedulerClient(
      send: (data) {
        sent.add(data);
        unawaited(runner.receive(data));
      },
      addListener: (cb) => listener = cb,
      removeListener: (_) {},
      ensureRunning: () async {},
    );
    final catalog = await client.discoverCharacters();
    expect(catalog.toJson(), {
      'username': 'bound',
      'characters': [
        {'id': 42, 'name': 'Saved Character'},
      ],
    });
    expect(
      (await client.discoverItems(
        boundUsername: catalog.username,
        character: catalog.characters.single,
      )).single.name,
      'Exact Item',
    );
    expect(discovery.account, 'bound');
    expect(discovery.characterId, 42);
    final crew = await client.discoverCrew(
      boundUsername: catalog.username,
      character: catalog.characters.single,
    );
    expect(crew.toJson(), {
      'artistId': 77,
      'artistName': 'Saved Band',
      'bonuses': [
        {'level': 14, 'label': 'notável', 'costMinor': 225000},
      ],
    });
    expect(store.raw, isNull);
    expect(jsonEncode(sent), isNot(contains('password')));
    discovery.failure = 'credentialsMissing';
    await expectLater(
      client.discoverCharacters(),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'credentialsMissing',
        ),
      ),
    );
    discovery.failure = 'raw-secret-from-platform';
    await expectLater(
      client.discoverCharacters(),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'runtimeUnavailable',
        ),
      ),
    );
    client.dispose();
    await runner.dispose();
  });
  test('credential reader reloads account and secret, independent from enabled toggle', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecretStore();
    await prefs.setString(
      AutoLoginSettingsStore.defaultStorageKey,
      jsonEncode({'username': 'first', 'enabled': false, 'status': 2}),
    );
    await secrets.write(
      AutoLoginSettingsStore.passwordSecretKey,
      'first-secret',
    );
    final first = await readSavedGameCredentials(prefs, secrets);
    expect(first.username, 'first');
    expect(first.password, 'first-secret');
    expect(first.status, 2);
    await prefs.setString(
      AutoLoginSettingsStore.defaultStorageKey,
      jsonEncode({'username': 'second', 'enabled': true, 'status': 1}),
    );
    await secrets.write(
      AutoLoginSettingsStore.passwordSecretKey,
      'second-secret',
    );
    final second = await readSavedGameCredentials(prefs, secrets);
    expect(second.username, 'second');
    expect(second.password, 'second-secret');
    expect(second.status, 1);
    await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
    expect((await readSavedGameCredentials(prefs, secrets)).password, '');
  });
  test(
    'secondary engine discovery uses the isolated service and does not write rules',
    () async {
      SharedPreferences.setMockInitialValues({
        AutoLoginSettingsStore.defaultStorageKey: jsonEncode({
          'username': 'bound',
          'enabled': false,
          'status': 1,
        }),
      });
      const foreground = MethodChannel('flutter_foreground_task/methods');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(foreground, (_) async => true);
      addTearDown(() {
        messenger.setMockMethodCallHandler(foreground, null);
      });
      final runner = await createSchedulerRunner();
      addTearDown(runner.dispose);
      await runner.receive({
        'type': 'scheduler.request',
        'requestId': 'discover',
        'command': 'discoverCharacters',
      });
      expect(
        runner.errorCode,
        anyOf('credentialsMissing', 'credentialsUnavailable'),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          SchedulerSnapshot.storageKey,
        ),
        isNull,
      );
    },
  );
}
