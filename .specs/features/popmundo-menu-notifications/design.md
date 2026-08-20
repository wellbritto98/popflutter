# Design: Popmundo Menu Notifications → Local Notifications

## Architecture

Dependency direction stays `popmundo_utils` ← `apps/popmundo_app` (no `popmundo_webview` change — page-initiated response bodies already flow through `hooks.js` → `NetworkEvent` end-to-end). All fetch/parse/watch/dedup logic lives in pure-Dart `popmundo_utils`; only "turn a parsed item into an OS notification" lives in `apps/popmundo_app`, keeping `popmundo_utils` free of `flutter_local_notifications`.

```
game page (own JS)              hooks.js patched fetch/XHR         popmundo_utils
──────────────────              ────────────────────────           ──────────────
POST GetMenuNotificationCount ─▶ {type:'network', payload:{body}} ─▶ NetworkEvent ─▶ PopmundoEventBus.network
                                                                              │
                                                                              ▼
                                                              MenuNotificationsWatcher (filters URL,
                                                              parses count, diffs vs persisted state)
                                                                              │ (on change)
                                                                              ▼
                                                              MenuNotificationsService.fetch()
                                                              (TimedFetch POST GetMenuNotifications,
                                                               useCache:false, double-decode envelope)
                                                                              │
                                                                              ▼
                                                              List<MenuNotification>  ──▶ diff vs
                                                              MenuNotificationState.notifiedUids
                                                                              │ (new items only)
                                                                              ▼
                                                              Stream<List<MenuNotification>> newNotifications
                                                                              │
apps/popmundo_app ────────────────────────────────────────────────────────────
                                                              MenuNotificationsBridge (Utils.getMyName()
                                                              once per batch, then per item)
                                                                              │
                                                                              ▼
                                                              NotificationService.showNotification(...)
                                                              → LocalNotificationsService (flutter_local_notifications)
```

## New files — `packages/popmundo_utils/lib/src/menu_notifications/`

### `menu_notification.dart`
```dart
class MenuNotification {
  const MenuNotification({
    required this.uid, required this.dateCreated, required this.timeCreated,
    required this.text, required this.url, required this.repeats,
    required this.type, required this.int1,
  });
  final String uid, dateCreated, timeCreated, text, url;
  final int repeats, type, int1;
  static MenuNotification? fromJson(Object? raw); // null on malformed entry, tolerant coercion
}
```
Coercion idiom matches `AutoLoginSettings.fromJson` (`'${x ?? ''}'`, `int.tryParse('$x') ?? 0`). Covers MENUNOTIF-05.

### `menu_notifications_service.dart`
```dart
class MenuNotificationsService {
  MenuNotificationsService(this.runtime, this.timedFetch, {ClockNow? now});
  Future<List<MenuNotification>> fetch();  // POST GetMenuNotifications, useCache:false
  static List<MenuNotification> parseMenuNotifications(String responseText); // unwrap {d:...}, double-decode
}
```
Mirrors `Notifications.getPageNotifications`/`parsePageNotifications` exactly (same envelope shape). `ClockNow` reused from `timed_fetch.dart` for a virtual-clock-friendly `ts`. Covers MENUNOTIF-04, MENUNOTIF-05.

### `menu_notification_state_store.dart`
```dart
class MenuNotificationState {
  const MenuNotificationState({this.lastCount, this.notifiedUids = const <String>{}});
  final int? lastCount;            // null = never observed
  final Set<String> notifiedUids;  // current outstanding + already-notified
  Map<String, Object?> toJson();
  factory MenuNotificationState.fromJson(Object? raw); // tolerant, defaults on malformed
}

class MenuNotificationStateStore {
  MenuNotificationStateStore(this.store, {this.storageKey = defaultStorageKey});
  static const defaultStorageKey = 'menu_notifications.v1';
  Future<MenuNotificationState> load();
  Future<void> save(MenuNotificationState state);
}
```
One JSON blob under one `KeyValueStore` key — `lastCount` and `notifiedUids` can never desync from a crash between two writes, because they're always written together. Same shape as `AutoLoginSettingsStore`. Covers MENUNOTIF-08, MENUNOTIF-09, MENUNOTIF-11.

### `menu_notifications_watcher.dart`
```dart
class MenuNotificationsWatcher {
  MenuNotificationsWatcher({required this.runtime, required this.service, required this.stateStore});
  void start();                                    // subscribes runtime.events.network
  Stream<List<MenuNotification>> get newNotifications; // broadcast, one emission per fetch batch
  Future<void> dispose();
}
```
- Filters: `event.method.toUpperCase() == 'POST' && event.url.contains('/WebServices/A/Open.asmx/GetMenuNotificationCount')` (suffix match — no `WS_ROOT_URL` constant exists; host varies by `HostTracker`'s sticky host). Covers MENUNOTIF-01.
- Parses `event.body` as `{"d":"<count>"}` → `int?`; unparsable → silently ignored (no state change). Covers MENUNOTIF-02.
- `count == state.lastCount` → no-op. Covers MENUNOTIF-03.
- Otherwise, reentrancy-guarded (`_checking` bool — a second trigger arriving mid-fetch is dropped, self-corrects on the game's next poll), calls `service.fetch()`, computes `currentUids = notifications.map((n) => n.uid).toSet()`, `newOnes = notifications.where((n) => !state.notifiedUids.contains(n.uid))`, emits `newOnes` on `newNotifications` if non-empty, then persists `MenuNotificationState(lastCount: count, notifiedUids: currentUids)` — **only reached on fetch success** (a thrown exception skips the `save()` call entirely, so `lastCount` stays at its last-successful value and the next differing count retries). Covers MENUNOTIF-04, MENUNOTIF-06, MENUNOTIF-07, MENUNOTIF-08, MENUNOTIF-09.
- First-run: `lastCount` starts `null` (`null == count` is always false for a real count, including `0`), `notifiedUids` starts empty, so the very first observation always fetches and every currently-outstanding UID is "new" — matches the confirmed "notify all immediately on first run" decision with no special-casing.

Self-managed subscription idiom copied from `AutoLoginController` (`packages/popmundo_utils/lib/src/autologin/auto_login_controller.dart`) — a pure-Dart facade owning its own `StreamSubscription`, not the Flutter app layer.

Export all four files from `packages/popmundo_utils/lib/popmundo_utils.dart` (barrel), alongside the existing `autologin/` exports.

## App-side changes — `apps/popmundo_app`

### `lib/notifications/notification_service.dart`
Add to the abstract contract:
```dart
Future<void> showNotification({required int id, required String title, required String body, String? payload});
```

### `lib/notifications/local_notifications_service.dart`
New constants: `kGameNotificationChannelId = 'popflutter_game_notifications_channel'` (+ name/description) — distinct from `popmundo_keepalive` (foreground service) and `popflutter_debug_channel` (debug MVP). Implementation mirrors `showTestNotification()`'s `AndroidNotificationDetails`/`NotificationDetails` construction, then `_plugin.show(id:, title:, body:, notificationDetails:, payload:)` (named params, per the existing `flutter_local_notifications` 22.3.0 API note in this file). No-ops if `!_initialized`, matching existing behavior.

### `lib/notifications/fake_notification_service.dart`
Records calls into `List<ShownNotification> shownNotifications` (small class: `id`, `title`, `body`, `payload`) for test assertions.

### `lib/notifications/menu_notifications_bridge.dart` (new file)
```dart
int menuNotificationIdFor(String uid) => uid.hashCode & 0x7fffffff;

class MenuNotificationsBridge {
  MenuNotificationsBridge({required this.watcher, required this.utils, required this.notificationService});
  void start();      // listens watcher.newNotifications
  Future<void> dispose();
}
```
Per batch: resolves `await utils.getMyName()` **once**, then for each item calls `notificationService.showNotification(id: menuNotificationIdFor(n.uid), title: n.text, body: '${n.dateCreated} ${n.timeCreated} - $charName', payload: n.url)`. GUID strings aren't valid plugin ids; the hash only satisfies the plugin's `int id` requirement — actual dedup already happened upstream in the watcher via `notifiedUids`. Covers MENUNOTIF-06.

### `lib/app.dart` (`_PopmundoHomeState`)
Add alongside the existing `late final` block (~line 95-126, reusing the already-constructed `timedFetch`):
```dart
late final menuNotificationsService = MenuNotificationsService(widget.runtime, timedFetch);
late final menuNotificationsStateStore = MenuNotificationStateStore(widget.store);
late final menuNotificationsWatcher = MenuNotificationsWatcher(
  runtime: widget.runtime, service: menuNotificationsService, stateStore: menuNotificationsStateStore,
);
late final menuNotificationsBridge = widget.notificationService == null ? null : MenuNotificationsBridge(
  watcher: menuNotificationsWatcher, utils: Utils(widget.runtime), notificationService: widget.notificationService!,
);
```
`initState()` (alongside `autoLogin.start()`): `menuNotificationsWatcher.start(); menuNotificationsBridge?.start();`. `dispose()` (alongside `autoLogin.dispose()`): `unawaited(menuNotificationsWatcher.dispose()); unawaited(menuNotificationsBridge?.dispose());`. No new UI, no `DebugOverlay` change.

### `lib/main.dart`
Right after `await notificationService.initialize();`, add `await notificationService.requestPermission();`. Covers MENUNOTIF-10.

## Testing strategy

- `popmundo_utils`: `FakePopmundoRuntime` + `PopmundoEventBus.emitNetwork(...)` + virtual clock + `MemoryKeyValueStore`, mirroring `events_test.dart`/`notifications_test.dart`/`storage_test.dart`/`timed_fetch_test.dart` idioms.
- `apps/popmundo_app`: `FakeNotificationService` + a stub `Utils`/runtime + a controllable `Stream<List<MenuNotification>>` for `MenuNotificationsBridge`, and direct unit tests for `menuNotificationIdFor`.
- No Patrol/device-real test added — this feature is app-observable business logic (network-event reaction, persistence, notification-service call), not a platform API surface; the underlying `flutter_local_notifications` plumbing itself is already Patrol-covered by `local-notifications`.

## Risks / edge cases (see spec.md Edge Cases for the requirement-facing versions)

1. Reentrancy: a second count-change arriving mid-fetch is dropped, not queued — acceptable because the game keeps re-polling.
2. Failed fetch never corrupts persisted state (only writes on success) — self-healing retry on the next differing count.
3. `NotificationService` optionality (`widget.notificationService == null`) is respected — no crash if absent.
4. GUID→int hashing can theoretically collide across two different UIDs (extremely unlikely, 31-bit space) — acceptable since dedup correctness never depends on the hash, only on the persisted `notifiedUids` string set.
