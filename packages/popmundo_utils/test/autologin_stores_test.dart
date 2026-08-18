import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('settings round-trip on KeyValueStore without password', () async {
    final store = MemoryKeyValueStore();
    final settingsStore = AutoLoginSettingsStore(store);
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: true,
        username: 'troyfournier',
        characterName: 'Troy',
        status: 2,
      ),
    );
    final loaded = await settingsStore.load();
    expect(loaded.enabled, isTrue);
    expect(loaded.username, 'troyfournier');
    expect(loaded.characterName, 'Troy');
    expect(loaded.status, 2);
    final raw = await store.get(AutoLoginSettingsStore.defaultStorageKey);
    expect(raw is Map, isTrue);
    expect((raw as Map).containsKey('password'), isFalse);
  });

  test('MemorySecretStore isolates password', () async {
    final secrets = MemorySecretStore();
    await secrets.write(AutoLoginSettingsStore.passwordSecretKey, 'secret');
    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      'secret',
    );
    await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      isNull,
    );
  });

  test('LastUrlStore rejects auth paths and accepts game paths', () async {
    final store = MemoryKeyValueStore();
    final last = LastUrlStore(store);

    await last.record('https://74.popmundo.com/');
    expect(await last.read(), isNull);

    await last.record('https://74.popmundo.com/Default.aspx');
    expect(await last.read(), isNull);

    await last.record(
      'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
    );
    expect(await last.read(), isNull);

    await last.record('https://74.popmundo.com/Login.aspx?t=x');
    expect(await last.read(), isNull);

    await last.record('https://74.popmundo.com/World/Popmundo.aspx/Character/1');
    expect(
      await last.read(),
      'https://74.popmundo.com/World/Popmundo.aspx/Character/1',
    );

    expect(LastUrlStore.isEligible('https://evil.com/x'), isFalse);
  });

  test('resolveInitialUrl uses last eligible or www default (NAV-04)', () {
    expect(
      LastUrlStore.resolveInitialUrl(
        'https://74.popmundo.com/World/Popmundo.aspx/Character/1',
      ),
      'https://74.popmundo.com/World/Popmundo.aspx/Character/1',
    );
    expect(
      LastUrlStore.resolveInitialUrl(null),
      HostTracker.defaultOrigin,
    );
    expect(
      LastUrlStore.resolveInitialUrl(''),
      HostTracker.defaultOrigin,
    );
  });
}
