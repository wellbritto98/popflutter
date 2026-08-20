# Local Notifications MVP Tasks

## Execution Protocol (MANDATORY — do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/local-notifications/design.md`
**Status**: Done — all 9 tasks implemented and committed; independent Verifier ran (`.specs/features/local-notifications/validation.md`); T8's device run + mutation-proof completed against a real emulator (deny/grant/mutation all confirmed). One low-risk, Verifier-accepted gap remains: `LocalNotificationsService.initialize()`'s own failure branch (part of NOTIF-08) has no executed test in either tier — see validation.md's Next Steps.

---

## Test Coverage Matrix

> Generated from codebase sampling + project guidelines — confirmed before Execute. Guidelines found: `CLAUDE.md` (two-tier test policy: `flutter test` fast tier vs. Patrol `integration_test/` device-real tier), `.specs/STATE.md` AD-015 (device-real tier rules: one `patrolTest`/file, no `PopmundoApp` construction, `flutter analyze integration_test` before device runs), `.claude/agents/popmundo-e2e.md` (mutation-proof requirement). Samples: `apps/popmundo_app/test/debug_overlay_test.dart` (fast/widget), `apps/popmundo_app/integration_test/keepalive_test.dart` (device-real/Patrol) — both used as the style/location floor.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `DebugOverlay` notification-button logic (trigger, in-flight debounce, denial/init-error safety) | unit (widget) | 1:1 to NOTIF-05, NOTIF-06, NOTIF-08 using `FakeNotificationService`; asserts `Key('debug-send-notification')`, disabled-while-in-flight, no exception on denial/init-error | `apps/popmundo_app/test/debug_overlay_test.dart` | `cd apps/popmundo_app && flutter test test/debug_overlay_test.dart` |
| `LocalNotificationsService` (real `flutter_local_notifications` wiring) + real system-tray content | integration (device-real, Patrol) | NOTIF-01, NOTIF-03, NOTIF-04, NOTIF-05, NOTIF-07 proven against the real OS tray. **Structural, not deferred-for-convenience**: the plugin's platform channel is not exercised at all under `flutter test` — same precedent as `FlutterForegroundTaskPlatform`, which likewise has zero unit tests and is proven only by `keepalive_test.dart`'s Patrol test. Exactly one `patrolTest` per AD-015. | `apps/popmundo_app/integration_test/notifications_test.dart` | `cd apps/popmundo_app && patrol test --target integration_test/notifications_test.dart -d <device-id>` |
| `NotificationService` interface / `FakeNotificationService` test double | none | Pure contract / test double — no independent behavior to assert | `apps/popmundo_app/lib/notifications/` | build gate only |
| `main.dart` / `app.dart` composition-root wiring (constructor threading) | none | Thin parameter-passing, same shape as the existing `keepalive` wiring (never independently unit-tested in this codebase); exercised transitively by T7's widget test pumping a real `DebugOverlay` tree | `apps/popmundo_app/lib/main.dart`, `apps/popmundo_app/lib/app.dart` | `cd apps/popmundo_app && flutter analyze .` |
| `pubspec.yaml` dependency addition | none | Config/entity layer — build gate only | `apps/popmundo_app/pubspec.yaml` | `cd apps/popmundo_app && flutter pub get && flutter analyze .` |

## Gate Check Commands

> Generated from codebase — confirmed before Execute.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After tasks touching only fast-tier Dart/widget code | `cd apps/popmundo_app && flutter analyze . && flutter test test/debug_overlay_test.dart` |
| Full | After the Patrol integration-test task | `cd apps/popmundo_app && flutter analyze . && flutter analyze integration_test && flutter test test/debug_overlay_test.dart && patrol test --target integration_test/notifications_test.dart -d <device-id>` |
| Build | After config/wiring-only tasks | `cd apps/popmundo_app && flutter pub get && flutter analyze .` |

---

## Execution Plan

Phases are ordered and run sequentially — each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Notification service layer

```
T1 → T2 → T3
        ↳ T4
```

### Phase 2: UI wiring + fast tests

```
T5 → T6 → T7
```

### Phase 3: Device-real proof

```
T8
```

### Phase 4: Docs sync

```
T9
```

---

## Task Breakdown

### T1: Add `flutter_local_notifications` dependency

**What**: Add `flutter_local_notifications` to `apps/popmundo_app/pubspec.yaml` and run `flutter pub get`.
**Where**: `apps/popmundo_app/pubspec.yaml`
**Depends on**: None
**Reuses**: n/a
**Requirement**: NOTIF-01

**Tools**:
- MCP: NONE (version already known from Design's Context7 research)
- Skill: NONE

**Done when**:
- [x] Dependency present in `pubspec.yaml` under `dependencies:`
- [x] `flutter pub get` succeeds with no version-solver conflicts against `easy_localization`/`flutter_foreground_task`/`flutter_inappwebview`

**Tests**: none
**Gate**: build

**Commit**: `chore(app): add flutter_local_notifications dependency`

---

### T2: Create `NotificationService` interface

**What**: Define the abstract contract: `initialize()`, `requestPermission()`, `showTestNotification()`.
**Where**: `apps/popmundo_app/lib/notifications/notification_service.dart`
**Depends on**: T1
**Reuses**: shape of `apps/popmundo_app/lib/background/background_platform.dart`
**Requirement**: NOTIF-01, NOTIF-03, NOTIF-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Abstract class with the three methods from `design.md`'s Components section
- [x] No Flutter/plugin imports beyond `dart:async` (interface stays plugin-free)
- [x] `flutter analyze apps/popmundo_app` passes

**Tests**: none
**Gate**: build

**Commit**: `feat(notifications): add NotificationService interface`

---

### T3: Create `FakeNotificationService`

**What**: Test double implementing `NotificationService`, recording call counts, with configurable `permissionGranted`, `initializeError`, `showDelay`.
**Where**: `apps/popmundo_app/lib/notifications/fake_notification_service.dart`
**Depends on**: T2
**Reuses**: n/a (new, same spirit as existing fakes under `apps/popmundo_app/test/`)
**Requirement**: NOTIF-05, NOTIF-06, NOTIF-08 (enables their tests in T7)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Implements `NotificationService` fully
- [x] `showDelay` support lets a test hold `showTestNotification()` pending, to exercise the in-flight/debounce path
- [x] `flutter analyze apps/popmundo_app` passes

**Tests**: none
**Gate**: build

**Commit**: `feat(notifications): add FakeNotificationService test double`

---

### T4: Create `LocalNotificationsService` (real implementation)

**What**: Real `NotificationService` implementation wrapping `FlutterLocalNotificationsPlugin` per `design.md`'s Components section (Android/iOS init settings, `requestNotificationsPermission()`/`requestPermissions()`, fixed channel/id `show()`).
**Where**: `apps/popmundo_app/lib/notifications/local_notifications_service.dart`
**Depends on**: T2
**Reuses**: shape of `apps/popmundo_app/lib/background/flutter_foreground_task_platform.dart`
**Requirement**: NOTIF-01, NOTIF-03, NOTIF-04, NOTIF-07, NOTIF-08

**Tools**:
- MCP: `context7` (re-verify exact `flutter_local_notifications` API surface against the installed package version while writing, per lesson-candidate L-013)
- Skill: NONE

**Done when**:
- [x] `initialize()` builds Android/Darwin settings per design, catches its own errors (NOTIF-08), verified against a real launcher-icon resource path under `android/app/src/main/res/mipmap-*/`
- [x] `requestPermission()` branches Android/iOS per design; other platforms return `true`
- [x] `showTestNotification()` no-ops if not initialized; uses fixed channel id `popflutter_debug_channel` (distinct from keepalive's `popmundo_keepalive`) and fixed notification id so repeat calls replace, not stack (NOTIF-07)
- [x] `flutter analyze apps/popmundo_app` passes

**Tests**: integration — satisfied by T8's Patrol test (see Test Coverage Matrix: structural constraint, not deferral; matches the `FlutterForegroundTaskPlatform` precedent of zero unit tests)
**Gate**: build now; full gate re-run as part of T8

**Commit**: `feat(notifications): add LocalNotificationsService`

---

### T5: Wire `LocalNotificationsService` into `main.dart`

**What**: Instantiate `LocalNotificationsService()`, `await initialize()` before `runApp`, pass into `PopmundoApp`.
**Where**: `apps/popmundo_app/lib/main.dart`
**Depends on**: T4
**Reuses**: existing `keepalive` instantiation pattern at `main.dart:18-21`
**Requirement**: NOTIF-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `notificationService` constructed and initialized before `runApp`
- [x] Passed into `PopmundoApp(...)`
- [x] `flutter analyze apps/popmundo_app` passes

**Tests**: none
**Gate**: build

**Commit**: `feat(app): initialize LocalNotificationsService at startup`

---

### T6: Thread `notificationService` through `app.dart`

**What**: Add `NotificationService? notificationService` to `PopmundoApp` and `PopmundoHome`, forward it to `DebugOverlay`.
**Where**: `apps/popmundo_app/lib/app.dart`
**Depends on**: T5, T2
**Reuses**: existing `keepalive` param shape at `app.dart:31-37, 61-73, 327-334`
**Requirement**: NOTIF-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `PopmundoApp` and `PopmundoHome` both accept the optional param and forward it unchanged
- [x] `DebugOverlay(...)` call site passes `notificationService: widget.notificationService`
- [x] `flutter analyze apps/popmundo_app` passes

**Tests**: none
**Gate**: build

**Commit**: `feat(app): thread NotificationService into DebugOverlay`

---

### T7: Add debug button + trigger logic in `DebugOverlay`

**What**: New `Key('debug-send-notification')` row in `_panel()`; `_sendingNotification` state + `_sendTestNotification()` (request permission → show if granted, debounced via disabled button, try/catch never crashes) per `design.md`.
**Where**: `apps/popmundo_app/lib/debug_overlay.dart`
**Depends on**: T6, T3
**Reuses**: existing `debug-clear`/`debug-close` `TextButton`/`IconButton` row pattern at `debug_overlay.dart:113-124`
**Requirement**: NOTIF-02, NOTIF-05, NOTIF-06, NOTIF-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Button renders with the required key, fixed English label (AD-014 carve-out)
- [x] Denial path (fake returns `permissionGranted: false`): no notification call, no exception, panel stays interactive
- [x] In-flight repeat tap (fake with `showDelay`): second tap during the delay is a no-op (button disabled)
- [x] `initialize()`/`showTestNotification()` throwing (fake with `initializeError`/thrown error): caught, no crash
- [x] `flutter test test/debug_overlay_test.dart` passes, test count increases by the new cases above (no silent deletions of existing cases)

**Tests**: unit (widget)
**Gate**: quick

**Commit**: `feat(app): add debug-panel test-notification button`

---

### T8: Add Patrol device-real test

**What**: New `integration_test/notifications_test.dart` — exactly one `patrolTest` sequencing NOTIF-03/04/05 (grant path shows the expected title/body in the tray; if a fresh emulator surfaces the permission dialog, `grantNotificationsIfAsked($)` handles it) with a `reason:` per `expect`. Add any idempotent init helper `harness.dart` needs for the plugin (mirrors `initForegroundComms()`), only if the plugin requires explicit init under the Patrol entrypoint. Run the mandatory mutation-proof check (temporarily revert the trigger, confirm the test goes red, restore).
**Where**: `apps/popmundo_app/integration_test/notifications_test.dart` (new), `apps/popmundo_app/integration_test/support/harness.dart` (extended, only if needed)
**Depends on**: T7, T4
**Reuses**: `keepalive_test.dart`'s structure and `grantNotificationsIfAsked($)` verbatim
**Requirement**: NOTIF-01, NOTIF-03, NOTIF-04, NOTIF-05, NOTIF-07

**Tools**:
- MCP: NONE
- Skill: NONE (this task falls under the `popmundo-e2e` specialist agent's file ownership — dispatch via the Agent tool rather than editing inline, per CLAUDE.md)

**Done when**:
- [x] `flutter analyze integration_test` passes (mandatory before any device run, AD-015)
- [x] Exactly one `patrolTest` in the file
- [x] Test passes on a connected Android device/emulator, asserting the real tray contains the fixed title/body text (not just "no exception") — agent runs `patrol test --target integration_test/notifications_test.dart -d <device-id>`
- [x] Mutation-proof: `showTestNotification()` mutated to no-op, test failed at the exact NOTIF-01/NOTIF-04 assertion, then restored via `git checkout --` (confirmed clean, no diff vs HEAD)
- [x] No hanging shade teardown — `closeNotifications` only while the shade is open (body); leftover tray content is replaced in place (NOTIF-07)

**Tests**: integration
**Gate**: full

**Commit**: `test(e2e): add Patrol coverage for the debug notification button`

---

### T9: Docs sync

**What**: Update `docs/ARQUITETURA.md` (new `notifications/` module + composition-root wiring), `apps/popmundo_app/README.md` if one exists, and `.specs/features/local-notifications/spec.md`'s Requirement Traceability table (Status → `Implementing`, pending the Verifier's final `Verified`).
**Where**: `docs/ARQUITETURA.md`, `apps/popmundo_app/README.md` (if present), `.specs/features/local-notifications/spec.md`
**Depends on**: T8
**Reuses**: n/a
**Requirement**: all (NOTIF-01..08 — documentation coverage, not new behavior)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `docs/ARQUITETURA.md` describes the `notifications/` module and its wiring
- [x] Module README updated if one exists for `apps/popmundo_app`
- [x] `spec.md` traceability table's Status column updated

**Tests**: none
**Gate**: build

**Commit**: `docs: document local-notifications MVP module`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4

Phase 1:  T1 ──→ T2 ──┬──→ T3
                       └──→ T4
Phase 2:  T4 ──→ T5 ──→ T6 ──→ T7 (T7 also depends on T3)
Phase 3:  T7, T4 ──→ T8
Phase 4:  T8 ──→ T9
```

Execution is strictly sequential — there is no intra-phase parallelism. A single agent (or batch worker) works one task at a time, in order.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Add dependency | 1 file (config) | ✅ Granular |
| T2: `NotificationService` interface | 1 file, 1 concept | ✅ Granular |
| T3: `FakeNotificationService` | 1 file, 1 concept | ✅ Granular |
| T4: `LocalNotificationsService` | 1 file, 1 concept | ✅ Granular |
| T5: `main.dart` wiring | 1 file | ✅ Granular |
| T6: `app.dart` wiring | 1 file | ✅ Granular |
| T7: Debug button + logic | 1 file (2-3 cohesive pieces: button, state, handler) | ✅ Granular — cohesive, single widget |
| T8: Patrol test | 1-2 files (new test + optional harness addition), 1 concept | ✅ Granular — harness addition only exists to serve this test |
| T9: Docs sync | up to 3 doc files, 1 concept (documentation) | ✅ Granular — no code, single purpose |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (start) | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T2 | T2 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5, T2 | T5 → T6 (T2 already satisfied transitively via T4/T5's chain from T2) | ✅ Match |
| T7 | T6, T3 | T6 → T7, T3 → T7 | ✅ Match |
| T8 | T7, T4 | T7 → T8, T4 → T8 | ✅ Match |
| T9 | T8 | T8 → T9 | ✅ Match |

No task depends on a task in a later phase — all arrows point backward or within the same phase.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: Add dependency | `pubspec.yaml` dependency | none | none | ✅ OK |
| T2: `NotificationService` interface | interface layer | none | none | ✅ OK |
| T3: `FakeNotificationService` | test-double layer | none | none | ✅ OK |
| T4: `LocalNotificationsService` | real plugin wiring | integration | integration (satisfied by T8, structural — see matrix note) | ✅ OK — sanctioned "merge forward" per Tasks process, not silent deferral |
| T5: `main.dart` wiring | composition-root wiring | none | none | ✅ OK |
| T6: `app.dart` wiring | composition-root wiring | none | none | ✅ OK |
| T7: Debug button + logic | `DebugOverlay` button logic | unit (widget) | unit (widget) | ✅ OK |
| T8: Patrol test | device-real integration | integration | integration | ✅ OK |
| T9: Docs sync | documentation | none | none | ✅ OK |

All checks pass — no ❌ VIOLATION.

---

## Sub-Agent Delegation Offer

9 tasks total, packed into whole phases: Phase 1 (T1-T4) + Phase 2 (T5-T7) = 7 tasks, Phase 3 (T8) + Phase 4 (T9) = 2 tasks. This is a 2-batch split if delegated (Batch A: T1-T7, Batch B: T8-T9), or inline execution in the main thread if not. T8 specifically falls under the `popmundo-e2e` specialist agent's ownership regardless of batching (per CLAUDE.md, dispatched via the Agent tool either way).

---

## Tool Plan (per Tasks process step 6)

No exotic tooling needed beyond what Design already resolved:

- **Context7 MCP**: only T4, to re-verify the exact `flutter_local_notifications` API surface against the installed package version while writing the real implementation (lesson-candidate L-013: verify plugin APIs against the installed source, not memory/docs alone).
- **Agent tool**: T8 dispatches to the `popmundo-e2e` specialist agent (file ownership: `integration_test/`, `harness.dart`). T1-T7, T9 fall under `popmundo-app-shell` (now mirrored into `.claude/agents/`) and can be dispatched there or done inline — no other specialist agent's files are touched.
- No other skills or MCPs (no browser automation, no design/dataviz tooling — this is native mobile UI, not a web page).
