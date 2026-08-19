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
}
