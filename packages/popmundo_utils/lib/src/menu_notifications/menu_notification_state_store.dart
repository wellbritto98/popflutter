import '../core/storage.dart';

/// Dedup state for the menu-notifications watcher: the last observed
/// `GetMenuNotificationCount` value plus the set of UIDs already notified.
///
/// Deliberately one immutable value holding both fields, persisted as a
/// single JSON blob under a single [KeyValueStore] key — [lastCount] and
/// [notifiedUids] can never desync from a crash between two separate writes,
/// because they are always written together.
class MenuNotificationState {
  const MenuNotificationState({
    this.lastCount,
    this.notifiedUids = const <String>{},
  });

  /// Null means "never observed" — always different from any real count,
  /// including `0`, so the first-ever observation always triggers a fetch.
  final int? lastCount;

  final Set<String> notifiedUids;

  Map<String, Object?> toJson() => {
        'lastCount': lastCount,
        'notifiedUids': notifiedUids.toList(),
      };

  /// Tolerant parse; defaults to the empty state on malformed input.
  factory MenuNotificationState.fromJson(Object? raw) {
    if (raw is! Map) return const MenuNotificationState();
    final map = Map<String, dynamic>.from(raw);

    final lastCountRaw = map['lastCount'];
    final lastCount = lastCountRaw == null
        ? null
        : (lastCountRaw is int ? lastCountRaw : int.tryParse('$lastCountRaw'));

    final uidsRaw = map['notifiedUids'];
    final notifiedUids =
        uidsRaw is List ? uidsRaw.map((e) => '$e').toSet() : const <String>{};

    return MenuNotificationState(lastCount: lastCount, notifiedUids: notifiedUids);
  }
}

/// Persists [MenuNotificationState] under one [KeyValueStore] key.
class MenuNotificationStateStore {
  MenuNotificationStateStore(this.store, {this.storageKey = defaultStorageKey});

  static const defaultStorageKey = 'menu_notifications.v1';

  final KeyValueStore store;
  final String storageKey;

  Future<MenuNotificationState> load() async {
    return MenuNotificationState.fromJson(await store.get(storageKey));
  }

  Future<void> save(MenuNotificationState state) async {
    await store.set(storageKey, state.toJson());
  }
}
