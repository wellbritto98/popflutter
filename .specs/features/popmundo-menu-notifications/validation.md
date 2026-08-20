# Popmundo Menu Notifications Validation

**Date**: 2026-08-20
**Spec**: `.specs/features/popmundo-menu-notifications/spec.md`
**Diff range**: `923d9bc..a0dc009` (9 commits)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| 1    | ✅ Done | `MenuNotification.fromJson` — `packages/popmundo_utils/lib/src/menu_notifications/menu_notification.dart` |
| 2    | ✅ Done | `MenuNotificationsService.fetch()`/`parseMenuNotifications` |
| 3    | ✅ Done | `MenuNotificationState`/`MenuNotificationStateStore` |
| 4    | ✅ Done | `MenuNotificationsWatcher` |
| 5    | ✅ Done | Barrel export in `popmundo_utils.dart` |
| 6    | ✅ Done | `NotificationService.showNotification` contract |
| 7    | ✅ Done | `LocalNotificationsService.showNotification` + `kGameNotificationChannelId` |
| 8    | ✅ Done | `FakeNotificationService.showNotification` + `shownNotifications` |
| 9    | ✅ Done | `menuNotificationIdFor` hash |
| 10   | ✅ Done | `MenuNotificationsBridge` |
| 11   | ✅ Done | Wired in `app.dart` (`_PopmundoHomeState`) + `requestPermission()` in `main.dart` |
| 12   | ⚠️ Partial | Docs updated (`docs/ARQUITETURA.md`, both READMEs) and accurate; `spec.md`'s own Requirement Traceability table still reads "Implementing" for all MENUNOTIF-* rows — not yet flipped to "Verified" (expected to happen as the close-out step after this validation lands) |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| MENUNOTIF-01 — observe `GetMenuNotificationCount` response via `NetworkEvent`, parse `{"d":"<count>"}` | Count parsed from JSON body's `d` field | `packages/popmundo_utils/test/menu_notifications_watcher_test.dart:53-75` — `h.runtime.events.emitNetwork(_countEvent(2))` → `expect(h.runtime.fetchCalls, hasLength(1))` (only fires on real count events at the right URL/method) | ✅ PASS |
| MENUNOTIF-02 — invalid count → ignore silently, no state change | No fetch, `lastCount` stays `null`, `notifiedUids` stays empty | `.../menu_notifications_watcher_test.dart:91-113` — 3 malformed bodies, then `expect(state.lastCount, isNull); expect(state.notifiedUids, isEmpty); expect(h.runtime.fetchCalls, isEmpty)` | ✅ PASS |
| MENUNOTIF-03 — count equals last persisted → no fetch | `fetchCalls` empty | `.../menu_notifications_watcher_test.dart:77-89` — `expect(h.runtime.fetchCalls, isEmpty)` after emitting the same count as persisted | ✅ PASS |
| MENUNOTIF-04 — count differs (incl. first-ever) → POST `GetMenuNotifications` with `{"ts": "<epoch-ms>"}`, `useCache:false` | Exact POST shape, cache disabled | `packages/popmundo_utils/test/menu_notifications_service_test.dart:14-50` — asserts URL contains path, `method=='POST'`, `body['ts']` matches clock, plus `:52-69` proves a changed `ts` always hits network (`useCache:false` behavior) | ✅ PASS |
| MENUNOTIF-05 — parse double-encoded `{"d":"<json-array-string>"}` into typed items | Each field mapped correctly, malformed entries dropped | `.../menu_notifications_service_test.dart:71-101` — full field-by-field assertion + drops a no-UID entry and a non-map entry; `packages/popmundo_utils/test/menu_notification_test.dart:5-57` covers `fromJson` coercion/null cases directly | ✅ PASS |
| MENUNOTIF-06 — new UID → exactly one notification, title=`text`, body=`"$dateCreated $timeCreated - $charName"`, name resolved once/batch | Exact title/body shape, single `getMyName()` call per batch | `apps/popmundo_app/test/notifications/menu_notifications_bridge_test.dart:90-122` — `expect(shown.title, 'Item offer'); expect(shown.body, '2026-08-19 10:00 - Ada')`; `:124-139` — `expect(h.getMyNameCalls, 1)` for a 3-item batch | ✅ PASS |
| MENUNOTIF-07 — already-notified UID → no duplicate | Second batch with a repeat UID shows it exactly once total | `.../menu_notifications_bridge_test.dart:141-179` — two count changes, second batch re-includes `u1`; `expect(...where(id==u1id), hasLength(1))` | ✅ PASS |
| MENUNOTIF-08 — persist only on fetch success; failure leaves `lastCount` untouched, later differing count retries | `lastCount` stays at prior value after a thrown fetch; a later differing count still triggers and succeeds | `.../menu_notifications_watcher_test.dart:115-143` — fetch throws → `expect(state.lastCount, isNull, reason: 'save() must be skipped on failure')`; same count re-emitted, fetch now succeeds → `expect(state.lastCount, 7); expect(h.runtime.fetchCalls, hasLength(2))` | ✅ PASS |
| MENUNOTIF-09 — UID no longer in latest response → dropped from persisted set | Two fetches, one item disappears, `notifiedUids` shrinks | `.../menu_notifications_watcher_test.dart:145-171` — first fetch `{u1,u2}`, second fetch `{u1}` only → `expect(state.notifiedUids, {'u1'})` | ✅ PASS |
| MENUNOTIF-10 — permission requested at startup, independent of debug panel | `main.dart` calls `requestPermission()` after `initialize()` | `apps/popmundo_app/lib/main.dart:22-26` (code present, confirmed by read) — **no automated test exists**; `spec.md`'s own Requirement Traceability table already records this as "wired, no automated test... manual smoke pending" | ⚠️ Documented gap (see below) |
| MENUNOTIF-11 — restart preserves dedup state (no re-notify) | Save→load round-trip returns identical `lastCount`/`notifiedUids` | `packages/popmundo_utils/test/menu_notification_state_store_test.dart:11-24` — `expect(loaded.lastCount, 3); expect(loaded.notifiedUids, {'a','b','c'})` | ✅ PASS |
| Reentrancy guard (edge case, not a numbered AC) | Second trigger mid-fetch dropped, not queued; only first trigger's count persisted | `.../menu_notifications_watcher_test.dart:173-204` — `expect(fetchCallCount, 1, reason: 'the overlapping trigger must be dropped, not queued')`; `expect(state.lastCount, 1)` | ✅ PASS |

**Status**: ✅ 10/11 ACs fully covered with spec-precise assertions. MENUNOTIF-10 is a documented, pre-acknowledged gap (see Gaps).

---

## Discrimination Sensor

All mutations applied directly to the working tree, run against the real test suite, confirmed killed, then reverted (`git diff` on the 4 touched files is empty after revert — verified).

| # | File:line | Mutation | Killed? |
| - | --------- | -------- | ------- |
| 1 | `packages/popmundo_utils/lib/src/menu_notifications/menu_notifications_service.dart:33` | `useCache: false` → `useCache: true` | ✅ Killed — `menu_notifications_service_test.dart`: "useCache:false means a changed ts always hits the network" fails (`hasLength(2)` actual `1`) |
| 2 | `packages/popmundo_utils/lib/src/menu_notifications/menu_notifications_watcher.dart` (catch block) | Made the watcher call `stateStore.save(...)` on fetch **failure** too (previously a no-op) | ✅ Killed — `menu_notifications_watcher_test.dart`: "a fetch failure leaves the persisted lastCount unchanged..." fails (`Expected: null, Actual: <7>`) |
| 3 | `packages/popmundo_utils/lib/src/menu_notifications/menu_notifications_watcher.dart` (persist line) | Changed `notifiedUids: currentUids` (replace) → `notifiedUids: state.notifiedUids.union(currentUids)` (never prunes) | ✅ Killed — `menu_notifications_watcher_test.dart`: "UID pruning drops items..." fails (`Expected: {'u1'}, Actual: {'u1','u2'}`) |
| 4 | `packages/popmundo_utils/lib/src/menu_notifications/menu_notifications_service.dart:43` | Removed the second `jsonDecode` (double-decode step) from `parseMenuNotifications` | ✅ Killed — 2 tests in `menu_notifications_service_test.dart` fail (`Expected: length 1, Actual: []`) |

**Sensor depth**: lightweight (4 targeted behavior-level mutations on the highest-risk new logic)
**Result**: 4/4 killed — PASS ✅

---

## Interactive UAT Results

Not performed — this is backend/business-logic feature work (network-event reaction, persistence, notification-service call) per `spec.md`'s own Independent Test note; no manual UI flow to walk through beyond the already-deferred live-device smoke test noted in Success Criteria.

---

## Code Quality

| Principle | Status |
| --- | --- |
| No features beyond what was asked | ✅ — scope matches spec exactly (no tap-navigation, no batching, no history UI, matching Out of Scope table) |
| No abstractions for single-use code | ✅ |
| No unnecessary "flexibility" added | ✅ — `MenuNotificationStateStore(store, {storageKey})` mirrors the existing `AutoLoginSettingsStore` pattern, not new |
| Only touched files required for task | ✅ — diff is additive; only `app.dart`/`main.dart`/`notification_service.dart`/barrel/READMEs/ARQUITETURA.md touched among existing files, all directly required |
| Didn't "improve" unrelated code | ✅ |
| Matches existing patterns/style | ✅ — mirrors `Notifications.getPageNotifications`/`parsePageNotifications` envelope handling and `AutoLoginController`'s self-managed-subscription idiom, as the design doc claims |
| Tests map to acceptance criteria and are non-shallow (spot-checked P1) | ✅ — see AC table; assertions target exact values (title/body strings, exact sets, exact call counts), not just "doesn't throw" |
| Spec-anchored outcome check | ✅ — see AC table |
| Per-layer coverage: domain logic (`popmundo_utils`) has ~1:1 AC mapping; app layer covers the notification-shaping behavior | ✅ |
| Every test in scope maps to a spec AC, edge case, or Done-when criterion | ✅ — no stray/unclaimed tests found across the 4 new `popmundo_utils` test files and 3 new `popmundo_app` test files |
| Documented project guidelines followed | ✅ — `CLAUDE.md` dependency-direction rule (`popmundo_utils` has zero Flutter imports — confirmed via `grep -rl "package:flutter" packages/popmundo_utils/lib/src/menu_notifications/` → no matches) |

---

## Edge Cases (from spec.md)

- [x] Two count changes before the first fetch resolves → second dropped, not queued — `menu_notifications_watcher_test.dart:173-204`
- [x] Count flaps back to last-persisted before the intermediate fetch resolves — accepted low-probability edge case per spec, no test required, none added (consistent)
- [x] `notificationService` is `null` → watcher still runs, no bridge constructed, no crash — **implemented** (`app.dart:140-146`, ternary null-guard) but **not exercised by any test** (no `PopmundoHome`/`_PopmundoHomeState` widget test constructs it with `notificationService: null`). Low-risk: the guard is a one-line ternary identical in shape to the pre-existing `notificationService: widget.notificationService` pass-through already used elsewhere in `app.dart` for `DebugOverlay`.
- [x] Response body exceeds 32KB cap / binary-flagged → pre-existing `NetworkEvent` constraint, correctly left unhandled (no special-casing needed or added)

---

## Gate Check

- **Gate commands**: `dart test` (popmundo_utils), `flutter analyze packages/popmundo_utils`, `flutter test` (apps/popmundo_app), `flutter analyze apps/popmundo_app` — all re-run fresh by this Verifier, not taken on faith
- **Result**:
  - `packages/popmundo_utils`: `dart test` → **213 passed, 0 failed**; `flutter analyze` → **No issues found**
  - `apps/popmundo_app`: `flutter test` → **95 passed, 0 failed**; `flutter analyze` → **No issues found**
- **Test count delta**: +4 test files / ~24 new test cases in `popmundo_utils` (`menu_notification_test.dart`, `menu_notifications_service_test.dart`, `menu_notification_state_store_test.dart`, `menu_notifications_watcher_test.dart`); +3 test files / ~13 new test cases in `apps/popmundo_app` (`menu_notification_id_test.dart`, `menu_notifications_bridge_test.dart`, `notification_service_test.dart`) plus 1 extended existing file (`debug_overlay_test.dart`, interface-compliance addition only). No test file was deleted or shrunk; `git diff --stat` on `*_test.dart` in this range is purely additive.
- **Skipped tests**: none
- **Failures**: none

---

## Sanity Checks (task-specific)

**JSON key casing** (spec.md Assumptions row: "Directly confirmed from the real HTTP response... not inferred"): `MenuNotification.fromJson` (`packages/popmundo_utils/lib/src/menu_notifications/menu_notification.dart:44-55`) does exact-case `Map` lookups for `UID`, `DateCreated`, `TimeCreated`, `Text`, `Url`, `Repeats`, `Type`, `Int1` — all match the spec's claimed PascalCase exactly, no case-insensitive or mismatched-case lookup found. Confirmed correct.

**Dependency direction**: `grep -rl "package:flutter" packages/popmundo_utils/lib/src/menu_notifications/` → no matches. `packages/popmundo_utils` stays Flutter-free; `flutter_local_notifications` is only imported in `apps/popmundo_app/lib/notifications/local_notifications_service.dart`, as designed.

**Docs accuracy**: `docs/ARQUITETURA.md`, `packages/popmundo_utils/README.md`, and `apps/popmundo_app/README.md` diffs were read in full and cross-checked against the actual code — class names (`MenuNotificationsWatcher`, `MenuNotificationsBridge`, `MenuNotificationStateStore`), file paths (`menu_notifications/`), behavior description (persist-only-on-success, reentrancy drop, single-blob storage, GUID→int hash rationale), and the test-file-count claim ("29 arquivos" in `popmundo_utils/test/`) were all verified to match reality. No drift found.

---

## Fix Plans

None required — no surviving mutants, no failing gates, no incorrect AC coverage.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status (recommended) |
| --- | --- | --- |
| MENUNOTIF-01 | Implementing | ✅ Verified |
| MENUNOTIF-02 | Implementing | ✅ Verified |
| MENUNOTIF-03 | Implementing | ✅ Verified |
| MENUNOTIF-04 | Implementing | ✅ Verified |
| MENUNOTIF-05 | Implementing | ✅ Verified |
| MENUNOTIF-06 | Implementing | ✅ Verified |
| MENUNOTIF-07 | Implementing | ✅ Verified |
| MENUNOTIF-08 | Implementing | ✅ Verified |
| MENUNOTIF-09 | Implementing | ✅ Verified |
| MENUNOTIF-10 | Implementing | ⚠️ Verified (wired) — automated test gap accepted, see Gaps |
| MENUNOTIF-11 | Implementing | ✅ Verified |

`spec.md`'s own traceability table was not edited by this Verifier pass (out of scope for this validation run); the table above is a recommendation for whoever performs the close-out edit.

---

## Summary

**Overall**: ✅ Ready (PASS, with one pre-acknowledged, low-severity documentation gap)

**Spec-anchored check**: 10/11 ACs matched spec outcome precisely; 1 (MENUNOTIF-10) has a documented coverage gap, not a precision gap
**Sensor**: 4/4 mutations killed
**Gate**: 308 total tests passed (213 + 95), 0 failed, both packages `flutter analyze`-clean

**What works**: The full observe → diff → fetch → parse → dedup → persist → notify pipeline is implemented exactly as designed, with tests that assert spec-precise outcomes (exact title/body strings, exact UID sets, exact call counts) rather than shallow "doesn't throw" checks. The persist-only-on-success self-healing retry, UID pruning, and reentrancy guard — the three subtlest behaviors in the feature — each have a dedicated test that was independently confirmed to fail under a targeted fault injection. Dependency direction (`popmundo_utils` stays Flutter-free) and the JSON PascalCase key-casing assumption were both cross-checked against the actual code and confirmed correct. Docs accurately describe the shipped implementation.

**Issues found**:
1. (Minor / documented) MENUNOTIF-10 — no automated test asserts `main.dart` calls `requestPermission()` at startup, despite `spec.md`'s own "Independent Test" prose describing one. `spec.md`'s Requirement Traceability table already discloses this ("wired, no automated test... manual smoke pending"), so this is a pre-existing, self-acknowledged gap rather than a hidden one. Root cause: `main()` constructs `LocalNotificationsService` concretely and isn't structured for dependency injection, so a `flutter test` can't easily intercept the call without refactoring `main.dart` for testability — a reasonable trade-off for a 4-line startup addition. Not blocking; recommend either (a) accepting as a permanent manual-smoke-only requirement, matching MENUNOTIF-10's `Independent Test` fallback clause about the underlying permission dialog already being Patrol-covered, or (b) a small follow-up task extracting `main()`'s startup sequence into a testable function if this pattern recurs for future startup-time requirements.
2. (Minor / low-risk, uncovered edge case) The `widget.notificationService == null` branch in `app.dart` (no crash, watcher runs without a bridge) has no test exercising it directly. Low risk — it's a one-line ternary matching an existing pass-through pattern already used for `DebugOverlay` in the same file.

**Next steps**: No fix tasks required to close this feature. Optionally: (1) flip `spec.md`'s Requirement Traceability table from "Implementing" to "Verified" per the table above, (2) if a manual/live smoke test of MENUNOTIF-10 and the Success Criteria (real `GetMenuNotificationCount` change → real OS notification) hasn't been run yet, that remains the one manual step spec.md's own Success Criteria still calls for.
