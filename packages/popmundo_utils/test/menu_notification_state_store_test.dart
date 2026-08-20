// Imported directly (not via the barrel yet) — the barrel export lands in
// task 5, and this file switches to it then, matching the rest of test/.
import 'package:popmundo_utils/src/menu_notifications/menu_notification_state_store.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('default state has null lastCount and empty notifiedUids', () {
    const state = MenuNotificationState();
    expect(state.lastCount, isNull);
    expect(state.notifiedUids, isEmpty);
  });

  test('save then load round-trips lastCount and notifiedUids (MENUNOTIF-11)',
      () async {
    final store = MemoryKeyValueStore();
    final stateStore = MenuNotificationStateStore(store);

    await stateStore.save(const MenuNotificationState(
      lastCount: 3,
      notifiedUids: {'a', 'b', 'c'},
    ));
    final loaded = await stateStore.load();

    expect(loaded.lastCount, 3);
    expect(loaded.notifiedUids, {'a', 'b', 'c'});
  });

  test('load with nothing persisted yet returns the default state '
      '(first-run — MENUNOTIF-04)', () async {
    final store = MemoryKeyValueStore();
    final stateStore = MenuNotificationStateStore(store);

    final loaded = await stateStore.load();

    expect(loaded.lastCount, isNull);
    expect(loaded.notifiedUids, isEmpty);
  });

  test('fromJson is tolerant of malformed input and defaults to empty state',
      () {
    expect(MenuNotificationState.fromJson(null).lastCount, isNull);
    expect(MenuNotificationState.fromJson('nonsense').lastCount, isNull);
    expect(MenuNotificationState.fromJson(42).notifiedUids, isEmpty);

    final partial = MenuNotificationState.fromJson({'lastCount': '5'});
    expect(partial.lastCount, 5);
    expect(partial.notifiedUids, isEmpty);

    final badUids =
        MenuNotificationState.fromJson({'lastCount': 1, 'notifiedUids': 'x'});
    expect(badUids.lastCount, 1);
    expect(badUids.notifiedUids, isEmpty);
  });

  test('lastCount and notifiedUids live under one key (single-blob shape)',
      () async {
    final store = MemoryKeyValueStore();
    final stateStore = MenuNotificationStateStore(store);
    await stateStore.save(const MenuNotificationState(lastCount: 1));

    final raw = await store.get(MenuNotificationStateStore.defaultStorageKey);
    expect(raw, isA<Map>());
    expect((raw as Map).containsKey('lastCount'), isTrue);
    expect(raw.containsKey('notifiedUids'), isTrue);
  });

  test('custom storageKey is honored', () async {
    final store = MemoryKeyValueStore();
    final stateStore =
        MenuNotificationStateStore(store, storageKey: 'custom.key');
    await stateStore.save(const MenuNotificationState(lastCount: 9));

    expect(await store.get('custom.key'), isNotNull);
    expect(
      await store.get(MenuNotificationStateStore.defaultStorageKey),
      isNull,
    );
  });
}
