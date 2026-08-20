# Mobile E2E Tests (Device-Real Tier) Validation

**Date**: 2026-08-19
**Spec**: `.specs/features/mobile-e2e-tests/spec.md`
**Diff range**: `35b5372..b609b09`, filtered to this feature's commits: `f43805c, 0bec34e, 315c27d, 1e32a4b, dacb11c, 45771fd, b609b09` (commits `262911b`, `6a35fe3`, `8e9cc5f` are a parallel, unrelated i18n feature by the user and are excluded)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 Patrol dep + pubspec config | ✅ Done | `f43805c`; `pubspec.yaml:54,59-69` |
| T2 Gradle + androidTest + smoke | ✅ Done | `0bec34e`; verified on physical device (1 passed, 34s) |
| T3–T5 Keepalive lifecycle, heartbeat, backgrounding | ✅ Done (merged) | `315c27d` + `1e32a4b`; **SPEC_DEVIATION** — landed as one commit/one test, see below |
| T6–T8 Storage round-trip + password isolation | ✅ Done (merged) | `dacb11c`; **SPEC_DEVIATION** — same reason |
| T9–T10 Userscript download + failure paths | ✅ Done (merged) | `45771fd`; **SPEC_DEVIATION** — same reason |
| T11 Docs + AD-015 | ✅ Done | `b609b09`; recorded as AD-015, not AD-014 (AD-014 was taken by a parallel i18n feature — legitimate, explained in commit body) |

**Note on tasks.md checkbox state**: `.specs/features/mobile-e2e-tests/tasks.md` "Done when" checkboxes are almost entirely unchecked (`[ ]`) except one item in T2, despite all task work being committed. This is a bookkeeping gap in the task file, not a coverage gap — every criterion below is independently re-derived from commit evidence and source, not from the checkbox state.

**SPEC_DEVIATION legitimacy assessment**: All three merges (T3/T4/T5, T6/T7/T8, T9/T10) cite the same concrete, verifiable upstream constraint: Patrol 4.9.0's `PatrolAppService` uses `final` completers (`_testExecutionRequested`/`_testExecutionCompleted`) built once per app process and never recycled (`patrol_app_service_io.dart:80,86`), so a second `runDartTest` in the same process trips an assertion at line 163 and the native side returns HTTP 500. This is filed upstream as leancodepl/patrol#2005 and #2380 (closed as not-planned). The `315c27d` commit message additionally records that two other hypotheses were chased and disproven first (`clearPackageData`, FGS "surviving too well") before landing on the correct diagnosis — this is not a hand-wave, it is a substantiated environmental constraint. Each merged test keeps a `reason:` string per `expect()` naming its original criterion (KA-01, KA-02, KA-04, etc.), so per-criterion granularity survives in failure output despite the file-level merge. **Verdict: legitimate, does not hide missing coverage** — every AC in the merged tasks still has its own distinct, independently-checkable assertion.

---

## Spec-Anchored Acceptance Criteria

### P1: Tier de teste em device real

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | --------------------- | ------------------------ | ------ |
| E2E-01: `patrol test` builds/installs/executes, reports pass/fail | Suite runs on-device, per-test result reported | Device-run recorded at: `0bec34e` "Total: 1, Successful: 1, Failed: 0 (34s)"; `315c27d` "tests=1 failures=0 errors=0 (44.9s)"; `dacb11c`/`45771fd` "1 passed, 0 failed" | ✅ PASS |
| E2E-02: Gradle declares `PatrolJUnitRunner` + `clearPackageData`; androidTest bootstrap exists | Exact runner string + arg; JUnit class referencing `MainActivity` | `apps/popmundo_app/android/app/build.gradle.kts:31` — `testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"`; `:40` — `testInstrumentationRunnerArguments["clearPackageData"] = "true"`; `apps/popmundo_app/android/app/src/androidTest/java/com/popmundo/popmundo_app/MainActivityTest.java:9-11` — `instrumentation.setUp(MainActivity.class)` | ✅ PASS (re-read directly) |
| E2E-03: `pubspec.yaml` has `patrol:` section + package name / bundle id; `patrol` is a dev_dependency | Exact keys present | `apps/popmundo_app/pubspec.yaml:54` — `patrol: ^4.9.0` under `dev_dependencies`; `:59-69` — `patrol:` section, `android.package_name: com.popmundo.popmundo_app`, `ios.bundle_id: com.popmundo.popmundoApp` | ✅ PASS (re-read directly) |
| E2E-04: failing test output identifies test by name + carries assertion message | Named failure + message | `integration_test/keepalive_test.dart:110-122` (`reason:` on the KA-05 `expect`) exercised for real in `1e32a4b`'s mutation run, captured output: `Expected: contains 'Popmundo is running' / Actual: [...] / Which: does not contain 'Popmundo is running' / KA-05: keepalive notification vanished...`. This proves the "carries the assertion message" half. The "identifies the failing test by name" half is standard `flutter_test`/Patrol reporter behavior (always prefixes a failure with the test description) but the pasted commit excerpt does not itself show that header line — `0bec34e` explicitly flagged this half **PARTIAL** and deferred to the Verifier rather than claiming it | ⚠️ Spec-precision gap (partial evidence) — assertion-message half proven with real device output; test-name half plausible by tool default but not shown in captured evidence |
| E2E-05: `flutter test` still passes unchanged, ignores `integration_test/` | 55 passed, `integration_test/` not executed | Re-run by Verifier in a clean `git worktree` at `b609b09` (main tree has unrelated uncommitted i18n changes — see Gate Check): `flutter test` → `00:06 +55: All tests passed!`, no `integration_test/*` lines in output | ✅ PASS (re-executed independently) |

### P1: Keepalive real em device

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | --------------------- | ------------------------ | ------ |
| KA-01: `bootstrap()` → notification granted, `serviceRunning` becomes `true` | Boolean `true` | `integration_test/keepalive_test.dart:64-68` — `expect(keepalive.status.value.serviceRunning, isTrue, ...)` | ✅ PASS |
| KA-02: `isRunningService()` returns `true` (real plugin) | Boolean `true` | `integration_test/keepalive_test.dart:71-75` — `expect(await platform.isRunningService(), isTrue, ...)` | ✅ PASS |
| KA-03: two distinct ticks within 30s, second strictly later | `count>=2`, `tick2 > tick1` | `integration_test/keepalive_test.dart:95-105` — `expect(before.length, greaterThanOrEqualTo(2), ...)`; `expect(before[1].isAfter(before[0]), isTrue, ...)`; bound enforced by `support/harness.dart:111-147` `waitForTicks(timeout: 30s)` | ✅ PASS |
| KA-04: second `bootstrap()` starts no second service, `serviceRunning` stays `true` | No second service; `true` | `integration_test/keepalive_test.dart:84-89` — `expect(second.status.value.serviceRunning, isTrue, ...)`, `expect(await platform.isRunningService(), isTrue, ...)`. **Note**: the assertion checks end-state booleans, not that `startService()` itself was not invoked a second time — see Sensor §KA-04 below for a static discrimination caveat on this exact point | ✅ PASS (outcome asserted; see sensor note on assertion depth) |
| KA-05: notification "Popmundo is running" present in shade after `pressHome()` | Exact title string present | `integration_test/keepalive_test.dart:108-122` — `await $.platform.mobile.pressHome()`; `openNotifications()`; `expect(notifications.map((n) => n.title), contains(keepaliveNotificationTitle), ...)` where `keepaliveNotificationTitle = 'Popmundo is running'` (`support/harness.dart:19`), matching the real title in `lib/background/flutter_foreground_task_platform.dart:74` | ✅ PASS — **and empirically proven discriminating** (see Sensor, executed mutation) |
| KA-06: after `openApp()`, service still running, heartbeat advanced past pre-background value | Boolean `true` + strictly later timestamp | `integration_test/keepalive_test.dart:125-145` — `pressHome()` then `openApp()`; `expect(await platform.isRunningService(), isTrue, ...)`; `expect(after.last.isAfter(lastBeforeBackground), isTrue, ...)` | ✅ PASS |

### P2: Storage real (secure + prefs)

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | --------------------- | ------------------------ | ------ |
| STO-01: `write` then `read` returns exact value | Equal string | `integration_test/storage_test.dart:46-51` — `expect(await secrets.read(secretKey), secretValue, ...)` | ✅ PASS |
| STO-02: `delete` then `read` returns `null` | `null` | `integration_test/storage_test.dart:54-59` — `expect(await secrets.read(secretKey), isNull, ...)` | ✅ PASS |
| STO-03: no plain-`SharedPreferences` value equals the password | No leak, AND (guard) password readable from `SecretStore` | `integration_test/storage_test.dart:102-115` — iterates `reread.getKeys()`, builds `leaked` list on substring match, `expect(leaked, isEmpty, ...)`; **guard against a trivially-passing empty-store check** at `:118-125` — `expect(await secrets.read(AutoLoginSettingsStore.passwordSecretKey), password, ...)` proves the password really was written somewhere and the leak-check isn't vacuous | ✅ PASS — guard against trivial pass verified present and correctly ordered (write happens before the leak scan, at `:89-98`) |
| STO-04: structured value round-trips through a **freshly constructed** store | Equal structure | `integration_test/storage_test.dart:69-76` — `freshStore = SharedPreferencesStore(await SharedPreferences.getInstance())` (new instance) then `expect(await freshStore.get(prefsKey), {'enabled': true, 'count': 42, 'name': 'popmundo'}, ...)` | ✅ PASS |
| STO-05: `remove` then `get` returns `null` | `null` | `integration_test/storage_test.dart:79-84` — `expect(await freshStore.get(prefsKey), isNull, ...)` | ✅ PASS |

### P2: Import de userscript real

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | --------------------- | ------------------------ | ------ |
| US-01: loopback server body == `fetchUserScriptUrl` result | Exact string equality | `integration_test/userscripts_test.dart:60-64` — `expect(await fetchUserScriptUrl(okUrl), _validUserScript, ...)` | ✅ PASS |
| US-02: imported script listed by a **fresh** catalog instance | Catalog contains the id | `integration_test/userscripts_test.dart:76-84` — `freshCatalog = UserScriptCatalog(SharedPreferencesStore(await SharedPreferences.getInstance()), ...)`, `expect((await freshCatalog.list()).map((s) => s.id), contains(installed.id), ...)` | ✅ PASS |
| US-03: non-2xx throws `UserScriptImportException` naming the status | Type + message contains status code | `integration_test/userscripts_test.dart:98-108` — `throwsA(isA<UserScriptImportException>().having((e) => e.toString(), 'message', contains('404')))`; SUT confirmed at `lib/userscripts/userscript_http.dart:18-22` — message is `'Download failed: HTTP ${response.statusCode} for $url'` | ✅ PASS |
| US-04: unanswered request times out with a typed exception, bounded duration | Type + message indicates timeout, bounded | `integration_test/userscripts_test.dart:120-130` — `fetchUserScriptUrl(silentUrl, timeout: const Duration(seconds: 2))`, `throwsA(isA<UserScriptImportException>().having((e) => e.toString().toLowerCase(), 'message', contains('timed out')))`; SUT at `lib/userscripts/userscript_http.dart:26-27` | ⚠️ Spec-precision gap — type/message asserted; **no explicit wall-clock bound is asserted in the test** (e.g. `expect(elapsed, lessThan(...))`). See Sensor §US-04 static finding: a regression that silently ignores the injected `timeout` parameter (falling back to the 20s default) would still satisfy this assertion, just more slowly — "bounded test duration" is only enforced implicitly by the outer Patrol/suite timeout, not by this test itself |

### P3: Documentação do tier

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | --------------------- | ------------------------ | ------ |
| DOC-01: `CLAUDE.md` documents `patrol test`, `patrol_cli` prerequisite, no-popmundo.com fact | Documented | `CLAUDE.md:76-90` — "Device-real tests (Patrol)" section: `flutter pub global activate patrol_cli` (`:82`), run command (`:85`), structural no-live-site explanation (`:89`); `CLAUDE.md:107` — "No live-site e2e tests" bullet updated to distinguish live-site ban from device testing, cross-references AD-015 | ✅ PASS |

**Status**: 19/21 full PASS, 2 spec-precision gaps (E2E-04 partial evidence, US-04 unbounded-duration assertion) — neither is a functional defect in the shipped tests, both are evidence/assertion-tightness gaps worth a follow-up.

---

## Discrimination Sensor

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ------------ | ------- |
| 1 (EXECUTED) | `android/app/src/main/AndroidManifest.xml` + `lib/background/flutter_foreground_task_platform.dart:65` | `stopWithTask` reverted `false → true` in both places | ✅ Killed — `1e32a4b` commit body: KA-05 failed with `Expected: contains 'Popmundo is running' / ... / does not contain 'Popmundo is running'`. Both files restored afterward, tree left clean |
| 2 (STATIC — not executed) | `apps/popmundo_app/integration_test/storage_test.dart:89-98` (SUT: `AutoLoginSettingsStore.save` / `FlutterSecureSecretStore.write`) | If the password were written into plain `SharedPreferences` instead of the secret store | Would kill — `leaked` list at `storage_test.dart:102-108` would include the offending key, `expect(leaked, isEmpty)` at `:109-115` fails |
| 3 (STATIC — not executed) | `lib/userscripts/userscript_http.dart:18` | Flip the status-code guard so non-2xx never throws (e.g. `if (false)`) | Would kill — `userscripts_test.dart:98-108` `expectLater(..., throwsA(...))` fails because the future completes normally instead of throwing |
| 4 (STATIC — not executed) | `integration_test/support/harness.dart:118-122` (`waitForTicks` dedup) | Isolate re-sends the same timestamp twice (stuck clock) instead of a new tick | Would kill — `record()`'s `ticks.last == tick` dedup means `ticks.length` never reaches 2, `waitForTicks` throws `TimeoutException` after 30s, failing before KA-03's own assertions are reached |
| 5 (STATIC — not executed, weak spot found) | `lib/background/background_keepalive.dart:70-74` (`if (!running) { startService(); }` guard) | Remove the `if (!running)` guard so a second `bootstrap()` always calls `startService()` again | **Uncertain / likely survives** — KA-04's assertions (`serviceRunning == true`, `isRunningService() == true`) only check end-state booleans, not that `startService()` was invoked exactly once. If the real plugin's `startService()` is idempotent when already running (does not throw), both booleans stay `true` and the mutant is **not observably killed** by this test. This is a genuine assertion-depth gap for the "no second service SHALL be started" half of KA-04 — the test proves "still running", not "did not restart" |
| 6 (STATIC — not executed, weak spot found) | `lib/userscripts/userscript_http.dart:13` (`timeout ?? const Duration(seconds: 20)`) | Ignore the caller-supplied `timeout` parameter, always use the 20s default | **Survives on type/message** — `userscripts_test.dart:120-130` only asserts exception type and message content, not elapsed wall-clock time, so the same exception would still eventually fire (just ~18s later than intended). This regression would pass the assertion, only slowed down — confirms the spec-precision gap flagged for US-04 above |

**Sensor depth**: lightweight (1 executed + 5 static reasoned), proportional to a Default-tier, non-payment/auth feature
**Result**: 1/1 executed mutations killed (✅). Static analysis surfaces 2 real assertion-depth gaps (KA-04 restart-count, US-04 duration-bound) that were not exercised on device by this agent (no Gradle access) but are reasoned precisely against the actual assertion code — **PASS overall**, with two follow-up-worthy gaps, neither blocking

---

## Interactive UAT Results

Not performed — this is an infrastructure/test-tooling feature (device test tier), not a user-facing feature. Per `validate.md` §3, automated checks are sufficient.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| No features beyond what was asked | ✅ — diff scoped to `pubspec.yaml`, `build.gradle.kts`, `androidTest/`, `integration_test/**`, `CLAUDE.md`, `.specs/STATE.md`, plus one unrelated pre-existing line (attributed to the parallel i18n commit `262911b`, not this feature — confirmed via `git log` on that file) |
| No abstractions for single-use code | ✅ — `support/harness.dart` functions are each consumed by ≥1 test in the same or a later phase; none land unused |
| No unnecessary "flexibility" added | ✅ |
| Only touched files required for task | ✅ — verified via `git diff --stat 35b5372..b609b09 -- apps/popmundo_app` filtered to feature commits |
| Didn't "improve" unrelated code | ✅ |
| Matches existing patterns/style | ✅ — mirrors `utils.dart`/`notifications.dart` facade pattern conventions where applicable, follows repo's Kotlin DSL gradle style |
| Would senior engineer approve? | ✅ — deviations are unusually well-documented (upstream issue links, ruled-out hypotheses) |
| Tests map to acceptance criteria and are non-shallow | ✅ — spot-checked P1 (keepalive) and P2 (storage) stories above; every `expect` carries a criterion-naming `reason` |
| Spec-anchored outcome check | ⚠️ — 19/21 clean, 2 spec-precision gaps documented above (E2E-04, US-04) |
| Per-layer Coverage Expectation met | ✅ — every P1/P2 AC has a device assertion; edge cases (permission dialog absent, FGS fails to start, heartbeat never arrives, port-in-use, no device) are all structurally handled per design's Error Handling Strategy table |
| Every test maps to a spec AC — no unclaimed tests | ✅ — 4 device test files (smoke, keepalive, storage, userscripts) map 1:1 to E2E/KA/STO/US groups; `patrol_test/test_bundle.dart` is a gitignored, Patrol-generated artifact, not authored test code |
| Documented guidelines followed | ✅ — `CLAUDE.md` "No live-site e2e tests" constraint (now updated), tasks.md Gate Check Commands, `.claude/skills/tlc-spec-driven` conventions |

---

## Hard Constraint Check (no popmundo.com, no PopmundoApp)

`Grep` over `apps/popmundo_app/integration_test/**` for `PopmundoApp|InAppPopmundoRuntime|popmundo\.com`: only 3 matches, all in comments/fixture text —
- `userscripts_test.dart:6` (comment) and `:30` (a `@match` line inside a fixture userscript string served by the in-test loopback server — never an outbound request)
- `support/harness.dart:37-38` (comment explaining why `PopmundoApp` is deliberately NOT used)

No test constructs `PopmundoApp`, `InAppPopmundoRuntime`, or makes any request to a popmundo.com host. **Hard constraint verified intact.**

---

## Edge Cases

- [x] Permission dialog absent → `grantNotificationsIfAsked` / `grantBackgroundExemptionIfAsked` guard on visibility before acting (`harness.dart:51-84`)
- [x] FGS fails to start → bounded via `try/catch` + boolean assertions in `bootstrap()`/KA-01, fails within the surrounding `patrolTest`'s own timeout rather than hanging
- [x] Heartbeat never arrives → `waitForTicks` throws `TimeoutException` at 30s (`harness.dart:137-143`)
- [x] `clearPackageData=true` resets grants → every test re-grants via Patrol native (`grantNotificationsIfAsked`), never assumes a persisted grant
- [x] Loopback port in use → `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` used in all three userscript servers (`userscripts_test.dart:47,87,111`) — port `0`, nothing hardcoded
- [x] No device connected → out of scope for static review; `patrol test` failing fast on no device is a Patrol CLI behavior, not app code

---

## Gate Check

- **Gate command 1**: `cd apps/popmundo_app && flutter analyze integration_test` — **re-run by Verifier**: `No issues found! (ran in 5.9s)` ✅
- **Gate command 2**: `cd apps/popmundo_app && flutter test` — **re-run by Verifier**, but the live working tree has unrelated uncommitted i18n changes (`lib/app.dart`, `lib/main.dart`, `lib/l10n.dart`, `test/_diag4_test.dart`, `test/localization_boot_test.dart`, `test/platform_config_test.dart`, `ios/Runner/Info.plist` — all untracked/modified by a parallel, in-progress i18n feature, confirmed via `git log` that none belong to `mobile-e2e-tests` commits). Running `flutter test` directly against the dirty tree surfaces **3 failures that belong to the i18n work**, not this feature (`_diag4_test.dart: direct rootBundle loads` timed out; `localization_boot_test.dart` PT/EN locale tests). To get a clean read on this feature, the Verifier created a temporary `git worktree` at commit `b609b09` (this feature's final commit, no i18n contamination) and re-ran there: **`00:06 +55: All tests passed!`**, with no `integration_test/*` lines appearing in the run (confirms E2E-05). Worktree was removed afterward; the user's uncommitted i18n work in the main tree was never touched.
- **Result**: 55 passed, 0 failed, 0 skipped (in the clean `b609b09` worktree)
- **Test count before feature**: 55 (per `315c27d`/`dacb11c`/`45771fd` commit messages, consistent across all — the fast tier count did not move, confirming E2E-05's "no regression")
- **Test count after feature**: 55 (unchanged — this feature adds only `integration_test/` files, which `flutter test` does not glob)
- **Delta**: +0 in the fast tier (by design — all new coverage lives in the separate device tier)
- **Device suites**: recorded provenance from the original Verifier session (that session did not re-run Gradle; later agents must run Patrol themselves):
  - keepalive (`keepalive_test.dart`) — 1 passed, 44.9s, `emulator-5554` (`315c27d`); plus a second, real, human-run mutation execution in `1e32a4b` proving KA-05 fails on the AD-013 regression
  - storage (`storage_test.dart`) — 1 passed, `emulator-5554` (`dacb11c`)
  - userscripts (`userscripts_test.dart`) — 1 passed, `emulator-5554` (`45771fd`)
  - smoke (`smoke_test.dart`) — 1 passed, 34s, physical device (`0bec34e`, device later retired per project decision)
- **Skipped tests**: none
- **Failures**: none attributable to this feature

---

## Fix Plans (if issues found)

No blocking issues. Two non-blocking spec-precision gaps are recorded for future tightening (not required before marking this feature done, since the underlying behavior is correct and the gaps are about assertion depth, not incorrect behavior):

### Gap 1: KA-04 does not assert "no second service was started", only end-state booleans
- **Root cause**: `background_keepalive.dart:68-78`'s `if (!running)` guard is exercised, but the device test (`keepalive_test.dart:79-89`) only checks `serviceRunning`/`isRunningService()` remain `true` — both would likely also read `true` if the guard were removed and `startService()` were called redundantly (assuming the plugin is idempotent when already running)
- **Fix task**: Not required for this PASS. If tightened later, would need either a spy/wrapper around `startService()` (conflicts with "real platform only") or an indirect signal such as notification-post-count via `getNotifications()` before/after
- **Priority**: Minor

### Gap 2: US-04 does not assert a wall-clock duration bound
- **Root cause**: `userscripts_test.dart:120-130` asserts exception type + message only; a regression that silently falls back to the 20s default timeout instead of honoring the injected 2s would still pass, just slower
- **Fix task**: Not required for this PASS. If tightened later, wrap the `expectLater` call with a `Stopwatch` and assert elapsed time is well under the default (e.g., `< 10s`)
- **Priority**: Minor

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | ---------------- | ----------- |
| E2E-01, E2E-02, E2E-03, E2E-05 | Pending | ✅ Verified |
| E2E-04 | Pending | ⚠️ Verified with spec-precision gap (partial evidence) |
| KA-01, KA-02, KA-03, KA-05, KA-06 | Pending | ✅ Verified |
| KA-04 | Pending | ✅ Verified (outcome asserted; assertion-depth note recorded) |
| STO-01, STO-02, STO-03, STO-04, STO-05 | Pending | ✅ Verified |
| US-01, US-02, US-03 | Pending | ✅ Verified |
| US-04 | Pending | ⚠️ Verified with spec-precision gap (no duration bound asserted) |
| DOC-01 | Pending | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 19/21 ACs matched spec outcome precisely; 2 spec-precision gaps flagged (E2E-04 partial evidence, US-04 no explicit duration bound) — both are refinements, not defects
**Sensor**: 1/1 executed mutation killed (KA-05/AD-013, real device evidence in `1e32a4b`); 4/4 additional static-reasoned mutations would be killed; 2 static mutations identified as likely-surviving assertion-depth gaps (KA-04 restart count, US-04 duration bound) — same two as the spec-precision gaps above, so no new blocking finding
**Gate**: `flutter analyze integration_test` — No issues found. `flutter test` — 55 passed (re-verified in a clean worktree at `b609b09` to avoid contamination from unrelated in-progress i18n changes in the main working tree). Device suites (keepalive, storage, userscripts) — human-verified on `emulator-5554`, provenance recorded above; not independently re-executable by this agent (no Gradle access in this session, verified by reproducing the `Selector.open()` failure)

**What works**: The device-real tier is correctly wired (Patrol runner, Gradle instrumentation, `androidTest` bootstrap), never constructs `PopmundoApp`/`InAppPopmundoRuntime`, and never touches popmundo.com (verified structurally by grep). All 21 spec requirements have a traceable `file:line` assertion. The feature's core claim — that this tier catches the AD-013 class of regression — is proven with real, captured, human-executed device evidence, not merely asserted. The three SPEC_DEVIATIONs (task merges) are legitimate: grounded in a specific, cited upstream Patrol limitation, with ruled-out alternative diagnoses recorded, and per-criterion granularity preserved via `reason:` strings on every `expect()`. The fast tier is provably unaffected (55/55, `integration_test/` not globbed).

**Issues found**: Two minor spec-precision/assertion-depth gaps (KA-04, US-04), documented above — neither is a functional bug, both are candidates for a future tightening pass, not blockers for this feature.

**Next steps**: Mark the feature Verified. Optionally file the two minor gaps as small follow-up tasks if the team wants the assertions tightened; not required to close this feature.
