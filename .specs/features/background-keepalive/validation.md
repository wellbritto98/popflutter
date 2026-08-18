# Background Keepalive Validation

**Date**: 2026-08-18
**Spec**: `.specs/features/background-keepalive/spec.md`
**Diff range**: `a5202ca..30632bf` (7 commits; T7 bind folded into `1551fed`; no separate T8 gate commit)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | ✅ Done | `10f13fb` BackgroundStatus + labels |
| T2 | ✅ Done | `4ab8bed` facade + fake |
| T3 | ✅ Done | `e6596ca` manifest/plist + platform_config_test |
| T4 | ✅ Done | `ccbc15d` adapter + TaskHandler (+ AppDelegate plugin registrant) |
| T5 | ✅ Done | `1551fed` main initCommunicationPort + post-frame bootstrap + lifecycle |
| T6 | ✅ Done | `30632bf` DebugOverlay lines + keys |
| T7 | ✅ Done | Folded into `1551fed` / `app.dart` (`backgroundStatus` → overlay) |
| T8 | ⚠️ Partial | No dedicated commit; Verifier ran gate (see Gate Check) |

---

## Spec-Anchored Acceptance Criteria

### P1: Bootstrap de permissões

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| BG-01: first frame → request notification without blocking WebView | `requestNotificationPermission` once per bootstrap | `test/background_keepalive_test.dart:23` — `expect(platform.notificationRequestCount, 1)`; wiring `lib/app.dart:108-110` `addPostFrameCallback` → `bootstrap()` | ✅ PASS (facade); ⚠️ Spec-precision gap: no assertion that WebView bootstrap is unaffected |
| BG-02: Android + battery still enforced → request ignore-battery | battery request invoked on Android | `test/background_keepalive_test.dart:24` — `expect(platform.batteryRequestCount, 1)` | ✅ PASS |
| BG-03: user denies → continue, no crash, debug shows denied | `notif: denied`, `battery: optimized`, service may still run | `test/background_keepalive_test.dart:61-65` — `notifLabel == 'denied'`, `batteryLabel == 'optimized'`, `serviceRunning == isTrue` | ✅ PASS |
| BG-04: relaunch after denial → no forced re-prompt every launch | second bootstrap does not re-request | `test/background_keepalive_test.dart:93-95` — `notificationRequestCount == 1`, `batteryRequestCount == 1` after double `bootstrap()` | ✅ PASS (instance-level `_bootstrapped`; OS owns dialog re-show) |

### P1: Foreground Service Android

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| FGS-01: bootstrap Android + !running → start FGS `dataSync` + persistent notif titled app is running | start when stopped; type dataSync; title e.g. “Popmundo is running” | `test/background_keepalive_test.dart:26` — `startCount == 1`; `test/platform_config_test.dart:38` — `foregroundServiceType="dataSync"`; title only in prod `lib/background/flutter_foreground_task_platform.dart:74` — **no test assertion** | ✅ PASS (start + type); ⚠️ Spec-precision gap: notification title string unasserted |
| FGS-02: service running → `serviceRunning` true + `bg: running` | labels `running` | `test/background_keepalive_test.dart:29-30` — `serviceRunning isTrue`, `bgLabel == 'running'`; `test/debug_overlay_test.dart:93` — `find.text('bg: running')` | ✅ PASS |
| FGS-03: already running → no second start | `startCount == 0` | `test/background_keepalive_test.dart:43` — `expect(platform.startCount, 0)` | ✅ PASS |
| FGS-04: manifest declares FGS perms + ForegroundService dataSync | all listed permission/service strings | `test/platform_config_test.dart:19-38` — contains `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `WAKE_LOCK`, `ForegroundService`, `dataSync` | ✅ PASS |

### P1: Debug panel

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| DBG-01: visible panel → dense lines under host | `bg`/`notif`/`battery`/`lifecycle`/`heartbeat` text | `test/debug_overlay_test.dart:93-98` — `find.text('bg: running')`, `notif: granted`, `battery: unrestricted`, `lifecycle: resumed`, `find.textContaining('heartbeat:')` | ✅ PASS |
| DBG-02: lines findable by keys | five `debug-bg-*` keys | `test/debug_overlay_test.dart:88-92` — `find.byKey(Key('debug-bg-service'|notif|battery|lifecycle|heartbeat))` | ✅ PASS |
| DBG-03: TaskHandler heartbeat → `lastHeartbeat` updates; line not stuck at never | tick applied; relative label | `test/background_keepalive_test.dart:125-128` — `lastHeartbeat == tick`, `heartbeatLabel(tick) == 'just now'`; overlay `test/debug_overlay_test.dart:98` — `find.textContaining('ago')` | ✅ PASS |
| DBG-04: iOS → battery `n/a` | `battery: n/a` | `test/background_status_test.dart:71-72` — `batteryLabel == 'n/a'`; `test/debug_overlay_test.dart:122` — `find.text('battery: n/a')`; keepalive iOS `test/background_keepalive_test.dart:111` | ✅ PASS |

### P2: iOS

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| IOS-01: first open iOS → request notification | notification request count 1; battery skipped | `test/background_keepalive_test.dart:108-109` — `batteryRequestCount == 0`, `notificationRequestCount == 1` | ✅ PASS |
| IOS-02: Info.plist → `UIBackgroundModes` fetch + BGTaskScheduler id | plist strings | `test/platform_config_test.dart:55-60` — `UIBackgroundModes`, `<string>fetch</string>`, `BGTaskSchedulerPermittedIdentifiers`, `com.pravera.flutter_foreground_task.refresh` | ✅ PASS |
| IOS-03: backgrounded → non-`resumed` lifecycle + heartbeat stops advancing | display allows paused / never; live UAT for freeze | `test/debug_overlay_test.dart:125-126` — `lifecycle: paused`, `heartbeat: never`; live suspend UAT **not run** by Verifier | ✅ PASS (display path); ⚠️ Spec-precision gap: “stops advancing” deferred to device UAT per Independent Test |

**Status**: ⚠️ Spec-precision gaps flagged (BG-01 WebView non-block, FGS-01 title string, IOS-03 live freeze). No blocking AC without facade/widget/config evidence.

---

## Discrimination Sensor

Scratch: temp backup under `/tmp` + mutate working files → restore via `cp` (tree left clean).

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 | `lib/background/background_keepalive.dart` (~70-74) | Always call `startService` (break idempotent `if (!running)`) | ✅ Killed — `background_keepalive_test.dart:43` `startCount == 0` |
| 2 | `lib/background/background_status.dart` (~31) | `batteryLabel` null → `'na'` instead of `'n/a'` | ✅ Killed — `background_status_test.dart:71` + `debug_overlay_test.dart:122` |
| 3 | `lib/debug_overlay.dart` (~186-189) | Omit `Key('debug-bg-heartbeat')` | ✅ Killed — `debug_overlay_test.dart:92` |

**Sensor depth**: lightweight (3 mutations)
**Result**: 3/3 killed — PASS ✅

---

## Interactive UAT Results

Not performed (Verifier automated pass only). Spec Independent Test for IOS-03 explicitly allows live UAT for suspend.

| # | Test | Result | Details |
| - | ---- | ------ | ------- |
| — | Device suspend / system dialogs | ⏭️ Skip | Manual / out of Verifier scope |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns | ✅ (shell-only; AD-012) |
| Spec-anchored outcome check | ⚠️ title + WebView-nonblock + freeze UAT |
| Per-layer Coverage Expectation met | ✅ domain 1:1 for BG/FGS/DBG; config FGS-04/IOS-02 |
| Every test maps to a spec requirement — no unclaimed tests | ✅ |
| Documented guidelines followed | ✅ `CLAUDE.md` / tasks matrix (`flutter test` in app; fake platform; platform_config_test) |

---

## Edge Cases

- [x] Notification denied → FGS may start; debug `notif: denied` — `background_keepalive_test.dart:61-65`
- [x] Battery exemption denied → service may start; `battery: optimized` — same
- [x] `startService` while running → no second start — `background_keepalive_test.dart:43`
- [ ] TaskHandler isolate cannot reach main → heartbeat stays previous/never, UI no crash — **no automated evidence** (prod `_onTaskData` ignores unparseable payloads; untested)
- [x] Bootstrap before WebView attach unaffected — by architecture (`postFrameCallback` + optional keepalive); no dedicated assertion (see BG-01 precision gap)

---

## Gate Check

- **Gate command**: `cd apps/popmundo_app && flutter analyze lib test && flutter test`
- **Analyze (`lib test`)**: exit **1** — 1× `info` `unnecessary_brace_in_string_interps` in `test/userscripts_screen_test.dart:198` (**outside** feature surface)
- **Analyze (feature-scoped paths)**: No issues found
- **Result (tests)**: **54** passed, **0** failed, **0** skipped
- **Test count before feature** (`a5202ca^`): **36** `test`/`testWidgets`
- **Test count after feature** (`30632bf` / HEAD suite): **54**
- **Delta**: **+18** new tests
- **Skipped tests**: none
- **Failures**: none (tests)

---

## Fix Plans (if issues found)

### Fix 1: Assert FGS notification title (optional strengthen)

- **Root cause**: Spec e.g. title “Popmundo is running” lives only in adapter; Independent Test did not require it, but evidence-or-zero leaves a precision gap
- **Fix task**: Add thin unit/adapter constant test or string assert on `notificationTitle` / extracted constant
- **Priority**: Minor

### Fix 2: Heartbeat channel failure edge

- **Root cause**: No test emits garbage / no callback after bootstrap and asserts `lastHeartbeat` unchanged + no throw
- **Fix task**: In `background_keepalive_test.dart`, emit non-map payload / skip emit; expect prior heartbeat / `never` and bootstrap completes
- **Priority**: Minor

### Fix 3: Full analyze noise (unrelated)

- **Root cause**: Pre-existing `info` in `userscripts_screen_test.dart` fails default fatal-infos analyze
- **Fix task**: Remove unnecessary braces OR run analyze with `--no-fatal-infos` in gate docs
- **Priority**: Cosmetic (not keepalive)

### Fix 4: IOS-03 device UAT

- **Root cause**: Suspend freeze not automatable in CI
- **Fix task**: Manual checklist — background app, confirm lifecycle non-resumed and heartbeat stops advancing
- **Priority**: Minor (P2)

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| BG-01 | Pending | ✅ Verified (⚠️ WebView non-block precision) |
| BG-02 | Pending | ✅ Verified |
| BG-03 | Pending | ✅ Verified |
| BG-04 | Pending | ✅ Verified |
| FGS-01 | Pending | ✅ Verified (⚠️ title unasserted) |
| FGS-02 | Pending | ✅ Verified |
| FGS-03 | Pending | ✅ Verified |
| FGS-04 | Pending | ✅ Verified |
| DBG-01 | Pending | ✅ Verified |
| DBG-02 | Pending | ✅ Verified |
| DBG-03 | Pending | ✅ Verified |
| DBG-04 | Pending | ✅ Verified |
| IOS-01 | Pending | ✅ Verified |
| IOS-02 | Pending | ✅ Verified |
| IOS-03 | Pending | ✅ Verified (⚠️ UAT freeze pending) |

---

## Summary

**Overall**: ✅ Ready (minor gaps / precision notes)

**Spec-anchored check**: 15/15 ACs have primary evidence; 3 Spec-precision gaps flagged
**Sensor**: 3/3 mutations killed
**Gate**: 54 passed; analyze exit 1 on unrelated `info` only

**What works**: Facade bootstrap (notif/battery/deny/idempotent/iOS n/a), FGS manifest/plist, debug keys+labels+heartbeat, shell post-frame wiring, discrimination sensor strong.

**Issues found**: Unasserted notification title; untested heartbeat-channel-miss edge; full analyze blocked by unrelated userscripts info; IOS-03 live UAT not run.

**Next steps**: Optional Fix 1–2 for test strength; Fix 3 if gate must be exit 0; schedule device UAT for IOS-03.
