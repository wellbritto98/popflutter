import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/autologin/auto_login_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

void main() {
  late MemoryKeyValueStore kv;
  late MemorySecretStore secrets;
  late AutoLoginSettingsStore settingsStore;

  setUp(() {
    kv = MemoryKeyValueStore();
    secrets = MemorySecretStore();
    settingsStore = AutoLoginSettingsStore(kv);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AutoLoginScreen(
          settingsStore: settingsStore,
          secretStore: secrets,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saves settings to KV and password only to SecretStore',
      (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('autologin-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('autologin-enabled')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('autologin-username')),
      'troyfournier',
    );
    await tester.enterText(
      find.byKey(const Key('autologin-password')),
      'test-password-not-real',
    );
    await tester.enterText(
      find.byKey(const Key('autologin-character')),
      'Troy',
    );
    await tester.tap(find.byKey(const Key('autologin-save')));
    await tester.pumpAndSettle();

    final settings = await settingsStore.load();
    expect(settings.enabled, isTrue);
    expect(settings.username, 'troyfournier');
    expect(settings.characterName, 'Troy');

    final raw = await kv.get(AutoLoginSettingsStore.defaultStorageKey);
    expect(raw is Map, isTrue);
    expect((raw as Map).containsKey('password'), isFalse);
    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      'test-password-not-real',
    );
    expect(find.byKey(const Key('autologin-snackbar')), findsOneWidget);
  });

  testWidgets('empty password on save keeps previous secret', (tester) async {
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: true,
        username: 'user',
        characterName: 'Troy',
      ),
    );
    await secrets.write(AutoLoginSettingsStore.passwordSecretKey, 'keep-me');

    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(const Key('autologin-username')),
      'user2',
    );
    await tester.tap(find.byKey(const Key('autologin-save')));
    await tester.pumpAndSettle();

    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      'keep-me',
    );
    expect((await settingsStore.load()).username, 'user2');
  });

  testWidgets('status dropdown exposes Normal Busy Mobile Away Drunk (UI-02)',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('autologin-status')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('autologin-status-0')), findsWidgets);
    expect(find.byKey(const Key('autologin-status-1')), findsOneWidget);
    expect(find.byKey(const Key('autologin-status-2')), findsOneWidget);
    expect(find.byKey(const Key('autologin-status-4')), findsOneWidget);
    expect(find.byKey(const Key('autologin-status-3')), findsOneWidget);
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Busy'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Drunk'), findsOneWidget);
  });

  testWidgets('Save is disabled while save is in flight', (tester) async {
    final gate = Completer<void>();
    final slowSecrets = _GatedSecretStore(secrets, gate);

    await tester.pumpWidget(
      MaterialApp(
        home: AutoLoginScreen(
          settingsStore: settingsStore,
          secretStore: slowSecrets,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('autologin-password')),
      'secret',
    );
    await tester.tap(find.byKey(const Key('autologin-save')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('autologin-save')),
    );
    expect(button.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
  });
}

class _GatedSecretStore implements SecretStore {
  _GatedSecretStore(this.inner, this.gate);

  final SecretStore inner;
  final Completer<void> gate;

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    await gate.future;
    await inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);
}
