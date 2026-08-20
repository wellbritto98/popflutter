# Tasks: Popmundo Menu Notifications → Local Notifications

Package column: **U** = `packages/popmundo_utils`, **A** = `apps/popmundo_app`. Each task = one atomic commit, gated by its package's test runner passing before commit. Tasks 1-5 must land before 6-11 (barrel export is a real dependency); 11 must land last (wires everything live).

| # | Task | Pkg | Covers | Verification (gate) |
| - | ---- | --- | ------ | -------------------- |
| 1 | `MenuNotification` model + `fromJson` (tolerant coercion, null on malformed) | U | MENUNOTIF-05 | `dart test` — valid/partial/malformed JSON maps → correct fields / null |
| 2 | `MenuNotificationsService.fetch()` + `parseMenuNotifications` (POST, `useCache:false`, double-decode `{d:...}` envelope) | U | MENUNOTIF-04, MENUNOTIF-05 | `dart test` via `FakePopmundoRuntime.fetchHandler`/`fetchCalls` — assert POST method, path, `useCache:false`, correct parse, mirrors `notifications_test.dart` |
| 3 | `MenuNotificationState` + `MenuNotificationStateStore` (one JSON blob, one key) | U | MENUNOTIF-08, MENUNOTIF-09, MENUNOTIF-11 | `dart test` — `MemoryKeyValueStore` save→load roundtrip equality, mirrors `storage_test.dart` |
| 4 | `MenuNotificationsWatcher` (network-event filter, count diff, fetch trigger, UID diff, persist-on-success, emit) | U | MENUNOTIF-01, -02, -03, -04, -06, -07, -08, -09 | `dart test` via `PopmundoEventBus.emitNetwork(...)` + virtual clock + `MemoryKeyValueStore` — cover: first-run notifies all, no-op on unchanged count, malformed count body ignored (no state change), fetch failure leaves `lastCount` untouched, UID pruning drops resolved items, reentrancy guard drops overlapping trigger |
| 5 | Barrel-export the four new files from `popmundo_utils.dart` | U | — | `dart test` / `flutter analyze packages/popmundo_utils` — package still compiles/resolves cleanly |
| 6 | `NotificationService.showNotification(...)` contract addition | A | — | `flutter analyze apps/popmundo_app` — interface compiles (implementers updated in 7-8) |
| 7 | `LocalNotificationsService.showNotification` implementation + new channel constants (`popflutter_game_notifications_channel`) | A | MENUNOTIF-06 | `flutter analyze` clean; no unit test needed beyond not-throwing-when-uninitialized (existing precedent) |
| 8 | `FakeNotificationService.showNotification` implementation + `shownNotifications` recorder | A | — | `flutter test` — asserting `shownNotifications` contents after a call |
| 9 | `menuNotificationIdFor(String uid)` hash helper | A | — | `flutter test` — deterministic, non-negative, distinct for distinct sample UIDs |
| 10 | `MenuNotificationsBridge` (subscribes `watcher.newNotifications`, resolves `Utils.getMyName()` once per batch, calls `showNotification` per item) | A | MENUNOTIF-06 | `flutter test` — fake `Utils`/stub stream + `FakeNotificationService`, assert `shownNotifications` count/content/id per batch |
| 11 | Wire `menuNotificationsService`/`Store`/`Watcher`/`Bridge` into `_PopmundoHomeState` (`app.dart`) + `requestPermission()` in `main.dart` | A | MENUNOTIF-10 | `flutter analyze` + `flutter test` (existing `app`/`main` tests, if any, stay green); manual smoke run per spec Success Criteria |
| 12 | `.specs` traceability update (mark all MENUNOTIF-* Verified after Verifier pass) + `docs/ARQUITETURA.md` webservices/notifications table + relevant module `README.md` updates | — | all | Docs-only, no test gate; reviewed for accuracy against what was actually built |

**Requirement coverage check:** MENUNOTIF-01…11 all mapped above (task 4 covers the watcher's core behaviors 01-03/06-09, task 2 covers 04-05's fetch shape, task 11 covers 10). 0 unmapped.

**Commit granularity:** tasks 1-5 as `popmundo_utils`-only commits (fully unit-tested, zero Flutter dependency touched), then 6-10 as `apps/popmundo_app` commits, then 11 wires them live, then 12 is docs. `dart test`/`flutter test` stays green after every commit.
