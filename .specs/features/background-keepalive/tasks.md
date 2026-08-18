# Background Keepalive Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path.

**Design**: `.specs/features/background-keepalive/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Guidelines found: `CLAUDE.md` / `AGENTS.md` / `.cursor/agents/popmundo-app-shell.md` (flutter test in `apps/popmundo_app`; widget tests with fakes; no live popmundo.com e2e; platform_config_test for manifest/plist).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| BackgroundKeepalive / BackgroundStatus / fake platform | unit | 1:1 to BG/FGS ACs + listed edges (denied, idempotent start, heartbeat) | `apps/popmundo_app/test/background_*_test.dart` | `cd apps/popmundo_app && flutter test` |
| DebugOverlay background lines | widget | DBG-01–04 keys + labels | `apps/popmundo_app/test/debug_overlay_test.dart` | `cd apps/popmundo_app && flutter test test/debug_overlay_test.dart` |
| AndroidManifest / Info.plist | unit (file assert) | FGS-04, IOS-02 | `apps/popmundo_app/test/platform_config_test.dart` | `cd apps/popmundo_app && flutter test test/platform_config_test.dart` |
| Live device UAT (suspend / dialogs) | none | Manual | — | device only |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After unit/widget tasks | `cd apps/popmundo_app && flutter test` |
| Full | After wiring / platform | `cd apps/popmundo_app && flutter test` |
| Build | Phase / feature complete | `cd apps/popmundo_app && flutter analyze && flutter test` |

---

## Execution Plan

Phases run sequentially. **8 tasks → single batch** (Execute inline, no sub-agent offer).

### Phase 1: Domain facade (testable without plugin)

```
T1 → T2
```

### Phase 2: Platform config + real adapter

```
T3 → T4
```

### Phase 3: Shell wiring + debug UI

```
T5 → T6 → T7
```

### Phase 4: Gate polish

```
T8
```

---

## Task Breakdown

### T1: BackgroundStatus model + display labels

**What**: Immutable status + English labels for debug (`running|stopped`, `granted|denied`, `unrestricted|optimized|n/a`, lifecycle name, relative heartbeat).
**Where**: `apps/popmundo_app/lib/background/background_status.dart`, `apps/popmundo_app/test/background_status_test.dart`
**Depends on**: None
**Reuses**: AppLifecycleState from Flutter
**Requirement**: DBG-01, DBG-03, DBG-04

**Done when**:

- [ ] Labels match spec strings for all enum-like states
- [ ] iOS battery null → `n/a`
- [ ] Heartbeat null → `never`; recent → contains `ago` or `just now`
- [ ] Unit tests cover those outcomes

**Tests**: unit
**Gate**: quick
**Commit**: `feat(app): add BackgroundStatus labels for debug keepalive`

---

### T2: BackgroundPlatform port + BackgroundKeepalive + fake

**What**: Port interface, fake platform, keepalive bootstrap orchestration (notif → battery on Android → init → start if !running), lifecycle + heartbeat updates, denial without throw.
**Where**: `apps/popmundo_app/lib/background/background_platform.dart`, `background_keepalive.dart`, `test/background_keepalive_test.dart`, `test/fake_background_platform.dart`
**Depends on**: T1
**Reuses**: BackgroundStatus
**Requirement**: BG-01, BG-02, BG-03, BG-04, FGS-01, FGS-02, FGS-03, DBG-03, IOS-01

**Done when**:

- [ ] Bootstrap requests notification; on Android also battery
- [ ] Denied paths do not throw; status reflects denied/optimized
- [ ] `startService` called only when `!isRunning`
- [ ] Heartbeat callback updates `lastHeartbeat`
- [ ] Lifecycle updates status
- [ ] Unit tests cover above (fake only)

**Tests**: unit
**Gate**: quick
**Commit**: `feat(app): add BackgroundKeepalive facade with fake platform`

---

### T3: Android manifest + iOS Info.plist declarations

**What**: Declare FGS permissions/service and iOS background fetch keys; extend platform_config_test.
**Where**: `apps/popmundo_app/android/app/src/main/AndroidManifest.xml`, `apps/popmundo_app/ios/Runner/Info.plist`, `apps/popmundo_app/test/platform_config_test.dart`
**Depends on**: None (can parallel with T1 conceptually; execute after T2 for linear commits)
**Reuses**: existing INTERNET / ATS asserts
**Requirement**: FGS-04, IOS-02

**Done when**:

- [ ] Manifest has FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, POST_NOTIFICATIONS, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, WAKE_LOCK, and ForegroundService dataSync
- [ ] Plist has UIBackgroundModes fetch + BGTaskSchedulerPermittedIdentifiers entry
- [ ] platform_config_test asserts those strings

**Tests**: unit (file)
**Gate**: quick
**Commit**: `feat(app): declare Android FGS and iOS background fetch keys`

---

### T4: FlutterForegroundTask adapter + TaskHandler + pubspec

**What**: Add dependency; implement real platform adapter and keepalive TaskHandler (heartbeat-only); entry callback.
**Where**: `apps/popmundo_app/pubspec.yaml`, `lib/background/flutter_foreground_task_platform.dart`, `lib/background/keepalive_task_handler.dart`
**Depends on**: T2, T3
**Reuses**: BackgroundPlatform
**Requirement**: FGS-01, DBG-03, IOS-01

**Done when**:

- [ ] `flutter_foreground_task` in pubspec; `flutter pub get` succeeds
- [ ] Adapter maps plugin APIs to port
- [ ] TaskHandler sends ISO-8601 heartbeat map; no TimedFetch/WebView
- [ ] Analyze clean for new files

**Tests**: none (covered by fake in T2; adapter is thin)
**Gate**: build (`flutter analyze` on app)
**Commit**: `feat(app): wire flutter_foreground_task adapter and heartbeat TaskHandler`

---

### T5: main.dart initCommunicationPort + home bootstrap wiring

**What**: Init communication port; construct keepalive with real platform; post-frame bootstrap; lifecycle observer; do not block WebView.
**Where**: `apps/popmundo_app/lib/main.dart`, `apps/popmundo_app/lib/app.dart`
**Depends on**: T4
**Reuses**: PopmundoHome bootstrap pattern
**Requirement**: BG-01, BG-02, BG-03, FGS-01, FGS-03, IOS-01

**Done when**:

- [ ] `initCommunicationPort` before runApp
- [ ] Post-frame `bootstrap()`; optional injectable keepalive for tests
- [ ] WidgetsBindingObserver updates lifecycle
- [ ] Existing app tests still pass (inject no-op/fake if needed)

**Tests**: existing app tests green (quick)
**Gate**: full
**Commit**: `feat(app): bootstrap background keepalive after first frame`

---

### T6: DebugOverlay background status lines

**What**: Render five dense lines under host when `backgroundStatus` provided; keys per spec.
**Where**: `apps/popmundo_app/lib/debug_overlay.dart`, `apps/popmundo_app/test/debug_overlay_test.dart`
**Depends on**: T1
**Reuses**: host ListTile pattern
**Requirement**: DBG-01, DBG-02, DBG-04

**Done when**:

- [ ] Keys and label text match spec
- [ ] Absent status → no bg lines (no crash)
- [ ] Widget tests assert keys + sample values

**Tests**: widget
**Gate**: quick
**Commit**: `feat(app): show keepalive status and heartbeat in debug panel`

---

### T7: Pass BackgroundStatus from home into DebugOverlay

**What**: Listen to keepalive status and pass into DebugOverlay so panel updates live.
**Where**: `apps/popmundo_app/lib/app.dart`
**Depends on**: T5, T6
**Reuses**: ValueListenable / setState pattern
**Requirement**: DBG-01, DBG-03, FGS-02, IOS-03 (display path)

**Done when**:

- [ ] Overlay receives current status from keepalive
- [ ] Status changes trigger rebuild
- [ ] App tests green

**Tests**: covered by overlay + keepalive tests; app smoke
**Gate**: full
**Commit**: `feat(app): bind keepalive status to debug overlay`

---

### T8: Full analyze + test gate

**What**: Run full app analyze + test; fix any wiring leftovers (MainActivity only if required by plugin).
**Where**: as needed under `apps/popmundo_app`
**Depends on**: T7
**Requirement**: all

**Done when**:

- [ ] `flutter analyze` clean for app
- [ ] `flutter test` green for app
- [ ] MainActivity changed only if plugin docs require it

**Tests**: full suite
**Gate**: build
**Commit**: `chore(app): verify background keepalive analyze and tests`

---

## Requirement → Task map

| ID | Tasks |
| -- | ----- |
| BG-01 | T2, T5 |
| BG-02 | T2, T5 |
| BG-03 | T2, T5 |
| BG-04 | T2 |
| FGS-01 | T2, T4, T5 |
| FGS-02 | T2, T7 |
| FGS-03 | T2, T5 |
| FGS-04 | T3 |
| DBG-01 | T1, T6, T7 |
| DBG-02 | T6 |
| DBG-03 | T1, T2, T4, T7 |
| DBG-04 | T1, T6 |
| IOS-01 | T2, T4, T5 |
| IOS-02 | T3 |
| IOS-03 | T7 (display), UAT manual |

---

## Diagram–Definition Cross-Check

| Edge | Matches Depends on? |
| ---- | ------------------- |
| T1 → T2 | T2 depends T1 ✅ |
| T2 → T4 | T4 depends T2 ✅ |
| T3 → T4 | T4 depends T3 ✅ |
| T4 → T5 | T5 depends T4 ✅ |
| T1 → T6 | T6 depends T1 ✅ |
| T5 → T7 | T7 depends T5 ✅ |
| T6 → T7 | T7 depends T6 ✅ |
| T7 → T8 | T8 depends T7 ✅ |

## Test Co-location Validation

| Task | Layer | Tests field | Matrix match? |
| ---- | ----- | ----------- | ------------- |
| T1 | status labels | unit | ✅ |
| T2 | keepalive | unit | ✅ |
| T3 | config | file unit | ✅ |
| T4 | thin adapter | none + analyze | ✅ |
| T5 | wiring | existing suite | ✅ |
| T6 | overlay | widget | ✅ |
| T7 | wiring | smoke/full | ✅ |
| T8 | gate | full | ✅ |
