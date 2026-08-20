# Popmundo Menu Notifications → Local Notifications Specification

## Problem Statement

The Popmundo game page already polls its own menu-notification badge (`POST /WebServices/A/Open.asmx/GetMenuNotificationCount`, response `{"d":"3"}`) on its own initiative. Popflutter observes every page-initiated request/response already (`hooks.js` → `NetworkEvent`), but nothing today reacts to this specific one. This feature turns that existing in-game signal into real OS local notifications: when the count changes, fetch the actual notification list (`GetMenuNotifications`) and surface one native notification per new item (item offers, contracts, rezoning requests, etc.), deduplicated by the item's `UID` across app restarts.

This is an observation/notification feature (mirrors an existing signal back to the user), not gameplay automation — no action is taken on the user's behalf, so it stays within the "observable foundation" scope `CLAUDE.md` establishes for this repo. It builds directly on the `local-notifications` MVP (`.specs/features/local-notifications/`), which deliberately scoped out "business-logic-triggered notifications... a separate future feature" — this is that feature.

## Goals

- [ ] The app observes the game's own `GetMenuNotificationCount` traffic passively (no new polling, no JS/bridge changes) and detects when the count changes.
- [ ] On a count change, the app fetches `GetMenuNotifications`, parses each item into a typed model, and shows exactly one OS local notification per item not already notified (by `UID`).
- [ ] Dedup state (last count + already-notified UIDs) survives app restarts.
- [ ] The permission needed for these notifications to actually appear is requested at app startup, not gated behind the unrelated debug panel.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Tap-to-open the in-game URL from the notification | Deferred by user decision; `Url` is retained on the model/payload for a future feature, but no navigation is wired now |
| Notification history/log UI | Not requested; OS notification tray is the only surface |
| Configurable/user-editable notification content or channel | Fixed content/channel for this feature, consistent with the existing debug-notification precedent |
| Independent app-side polling of `GetMenuNotificationCount` | The app never calls this endpoint itself — it only observes the game's own calls via the existing network-event stream |
| Batching multiple new items into one summary notification | Explicit user requirement: one local notification per game notification |
| Any gameplay-automation action (auto-accepting offers, auto-resolving contracts, etc.) | Repo-wide out of scope per `CLAUDE.md`; this feature only notifies, it never acts |

---

## Assumptions & Open Questions

Resolved during Plan-Mode research (three parallel Explore agents over `popmundo_utils`, the JS bridge, and the app's notification service, plus one Plan agent for architecture) and confirmed with the user via `AskUserQuestion` before this spec was written.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| First-run behavior (no persisted state yet) | Notify for **all** currently-outstanding items immediately | Explicit user choice — no baseline-suppression window | y |
| Notification content | Title = item's `Text`; body = `"$DateCreated $TimeCreated - $charName"` | Explicit user choice; `charName` via existing `Utils.getMyName()` | y |
| Tap action | Deferred — no navigation wired; `Url` stored on model/payload only | Explicit user choice; keeps scope small, matches `local-notifications` MVP's own deferral of tap/payload routing | y |
| Notification permission timing | Requested at app startup (`main.dart`, after `notificationService.initialize()`) | Explicit user choice — this feature has no manual UI trigger, so permission must not depend on the user opening the debug panel | y |
| Response-body capture for page-initiated requests | Already implemented (`hooks.js` fetch/XHR overrides → `NetworkEvent.body`) | Confirmed by research; no JS/bridge change needed | y |
| Cache bypass for `GetMenuNotifications` | `TimedFetch.fetch(..., useCache: false)` mandatory | `TimedFetch`'s cache key is `method:url` only — the changing `ts` body would otherwise return a stale cached response; `Notifications.getPageNotifications` already relies on this same flag for the same reason | y |
| Dedup persistence shape | One `KeyValueStore` JSON blob holding `{lastCount, notifiedUids}` | Avoids desync between the two values from a crash between two separate writes | y |
| `STATE.md` AD entry | Not added | This composes existing established patterns (`TimedFetch`, `KeyValueStore`, self-managed-subscription controller like `AutoLoginController`) — no new cross-cutting architecture, same reasoning `local-notifications` used to skip an AD | y |
| `GetMenuNotifications` JSON key casing | PascalCase (`UID`, `DateCreated`, `TimeCreated`, `Text`, `Url`, `Repeats`, `Type`, `Int1`) | Directly confirmed from the real HTTP response the user captured (browser devtools), not inferred | y |

**Open questions:** none — all resolved and logged above.

---

## User Stories

### P1: Game notification appears as a local notification ⭐ MVP

**User Story**: As a player using the app, I want a real OS notification to appear when the game has a new menu notification (item offer, contract, rezoning request, etc.), so I know about it without having the game page open and looking at it.

**Why P1**: This is the entire scope of the feature — there is no smaller vertical slice that delivers value.

**Acceptance Criteria**:

1. **MENUNOTIF-01** — WHEN the game page's own `POST .../WebServices/A/Open.asmx/GetMenuNotificationCount` call completes THEN the system SHALL observe its response body via the existing `NetworkEvent` stream and parse the count from `{"d": "<count>"}`.
2. **MENUNOTIF-02** — WHEN the parsed count is not a valid integer THEN the system SHALL ignore the event silently (no crash, no persisted-state change).
3. **MENUNOTIF-03** — WHEN the parsed count equals the last persisted count THEN the system SHALL take no further action (no fetch).
4. **MENUNOTIF-04** — WHEN the parsed count differs from the last persisted count (including the first-ever observation, where the last persisted count is absent) THEN the system SHALL fetch `POST /WebServices/A/Open.asmx/GetMenuNotifications` with body `{"ts": "<epoch-ms>"}` via `TimedFetch` with caching disabled.
5. **MENUNOTIF-05** — WHEN the fetch succeeds THEN the system SHALL parse the double-encoded `{"d": "<json-array-string>"}` envelope into a list of notification items, each with `uid`, `dateCreated`, `timeCreated`, `text`, `url`, `repeats`, `type`, `int1`.
6. **MENUNOTIF-06** — WHEN a parsed item's `uid` is not present in the persisted set of already-notified UIDs THEN the system SHALL show exactly one OS local notification for it, with title = `text` and body = `"$dateCreated $timeCreated - $charName"` (character name resolved once per batch via `Utils.getMyName()`).
7. **MENUNOTIF-07** — WHEN a parsed item's `uid` IS present in the persisted set of already-notified UIDs THEN the system SHALL NOT show a duplicate notification for it.
8. **MENUNOTIF-08** — WHEN the fetch-and-notify pass completes (success or failure) THEN the persisted state SHALL be updated to `{lastCount: <observed count>, notifiedUids: <current response's UID set>}` **only on success**; on failure, the previously persisted `lastCount` SHALL remain unchanged so the next differing count observation retries.
9. **MENUNOTIF-09** — WHEN a UID was previously in the persisted set but is no longer present in the latest `GetMenuNotifications` response THEN the system SHALL drop it from the persisted set (it is no longer outstanding in-game).
10. **MENUNOTIF-10** — WHEN the app starts THEN the system SHALL request OS notification permission (in addition to initializing the notification plugin), independent of whether the user ever opens the debug panel.
11. **MENUNOTIF-11** — WHEN the app is restarted THEN previously-notified UIDs SHALL NOT be re-notified (dedup state persists via `KeyValueStore`).

**Independent Test**: Unit/widget tests exercise MENUNOTIF-01 through -09 and -11 via `FakePopmundoRuntime`/`MemoryKeyValueStore`/`FakeNotificationService` (no device needed — this is app-observable business logic, not a platform API surface). MENUNOTIF-10 is exercised via a `flutter test` assertion that `main.dart`'s startup sequence calls `requestPermission()`; the underlying platform permission dialog itself is already covered by the existing `local-notifications` Patrol test and is not re-tested here.

No P2/P3 stories — everything beyond this vertical slice is listed in Out of Scope above.

---

## Edge Cases

- WHEN two `GetMenuNotificationCount` observations with different counts arrive before the first triggered `GetMenuNotifications` fetch resolves THEN the system SHALL ignore the second trigger (reentrancy guard) rather than firing two overlapping fetches; the dropped trigger is not lost — the game keeps re-polling the count endpoint, so a genuinely different state is re-observed and retried on the next poll.
- WHEN the observed count flaps back to the last-persisted value before a fetch for the intermediate value succeeds THEN the intermediate change is not recovered — accepted low-probability edge case, matches `GetPageNotifications`' own error tolerance.
- WHEN `notificationService` is not available (`null`, e.g. some test/composition-root configurations) THEN the watcher SHALL still run (persisted state stays correct) but no notification bridge SHALL be constructed — no crash.
- WHEN the response body exceeds the JS-side 32KB capture cap or is flagged binary THEN this is a pre-existing `NetworkEvent` constraint; irrelevant in practice for these small JSON payloads, no special handling added.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| MENUNOTIF-01 | P1 | Verified | Verified — `dart test`, mutation-proof (network-event filter) |
| MENUNOTIF-02 | P1 | Verified | Verified — `dart test` |
| MENUNOTIF-03 | P1 | Verified | Verified — `dart test` |
| MENUNOTIF-04 | P1 | Verified | Verified — `dart test`, mutation-proof (`useCache:false` flip killed by tests) |
| MENUNOTIF-05 | P1 | Verified | Verified — `dart test`, mutation-proof (double-decode removal killed by tests); PascalCase key casing cross-checked against real code |
| MENUNOTIF-06 | P1 | Verified | Verified — `dart test` + `flutter test` (repeat-batch no-duplicate case included) |
| MENUNOTIF-07 | P1 | Verified | Verified — `dart test` |
| MENUNOTIF-08 | P1 | Verified | Verified — `dart test`, mutation-proof (persist-on-failure bug killed by tests) |
| MENUNOTIF-09 | P1 | Verified | Verified — `dart test`, mutation-proof (UID-pruning bypass killed by tests) |
| MENUNOTIF-10 | P1 | Implementing | Wired (`main.dart` calls `requestPermission()` after `initialize()`); no automated test exists — Verifier-accepted documented gap, manual smoke test still pending (see validation.md) |
| MENUNOTIF-11 | P1 | Verified | Verified — `dart test` |

**ID format:** `MENUNOTIF-NN`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 11 total, 11 mapped to tasks (see `tasks.md`), 0 unmapped

---

## Success Criteria

- [ ] A real `GetMenuNotificationCount` change observed from the live game (manual smoke test) produces exactly one local notification per new outstanding item, with the expected title/body shape.
- [ ] Re-observing the same outstanding items (no new count change, or a count change with no new UIDs) never re-notifies.
- [ ] App restart preserves dedup state — no re-notification for already-seen UIDs.
- [ ] `dart test` (popmundo_utils) and `flutter test` (popmundo_app) both green, `flutter analyze` clean on both packages.
