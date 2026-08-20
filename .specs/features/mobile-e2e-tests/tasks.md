# Mobile E2E Tests (Device-Real Tier) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/mobile-e2e-tests/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec — confirm before Execute.
> **Guidelines found**: `CLAUDE.md` (per-package analyze/test commands; "No live-site e2e tests" constraint), `apps/popmundo_app/analysis_options.yaml`. No coverage thresholds, no CI config, no `CONTRIBUTING.md` exist in-repo.

**Note — this feature is unusual: the deliverable *is* test code.** "Tests for the tests" would be ceremony. Instead, a device test is considered covered when (a) it asserts a spec AC on real hardware and (b) its failure mode is proven — the Verifier's discrimination sensor mutates production code and confirms the device test goes red. That mutation check is the real coverage gate here, and it is why the P1 Independent Test (revert `stopWithTask` → KA-05 red) is the feature's acceptance bar.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Device test suites (deliverable) | e2e (on-device) | Every P1/P2 AC has an on-device assertion; every listed edge case handled; failure mode proven by mutation | `apps/popmundo_app/integration_test/*_test.dart` | `patrol test -d emulator-5554` |
| Test support / harness | e2e (via consumers) | Exercised by ≥1 device test **in the same task** — never landed unused | `apps/popmundo_app/integration_test/support/*.dart` | same as above |
| Build & instrumentation config | none — build gate only | Proven by the smoke test actually executing on device | `android/app/build.gradle.kts`, `android/app/src/androidTest/**`, `pubspec.yaml` | `patrol test --target integration_test/smoke_test.dart` |
| Existing app `lib/` + fast tier | unit (existing, unchanged) | Must not regress — E2E-05 | `apps/popmundo_app/test/**` | `flutter test` |
| Docs | none | — | `CLAUDE.md`, `.specs/STATE.md` | build gate only |

## Gate Check Commands

> Generated from codebase — confirm before Execute. Device id `emulator-5554` = sdk_gphone64_x86_64 emulator (physical device retired at user request).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After config-only or Dart-only tasks | `cd apps/popmundo_app && flutter analyze lib test integration_test` |
| **Pre-device (mandatory)** | **Before any device run** | `cd apps/popmundo_app && flutter analyze integration_test` — must report `No issues found!` |
| Full | After any task that adds a device test | Quick, then Pre-device, then `cd apps/popmundo_app && patrol test --target integration_test/<file>.dart -d emulator-5554` |
| Build | End of each phase | Quick, then `flutter test`, then `patrol test -d emulator-5554` (whole device suite) |

The agent **runs** `patrol test` and any Gradle/`flutter build` step itself. Do not hand a paste-ready command to the user as a substitute for execution.

**The Pre-device gate is not optional.** T2's first device run was burned on two Dart compile errors (`expect` / `findsOneWidget` undefined — missing `package:flutter_test/flutter_test.dart` import) that `flutter analyze integration_test` catches locally in under 2s. Never spend a device cycle on an error the analyzer can find for free.

> **Analyze scoping note:** `flutter analyze` on the whole package already exits 1 today on a pre-existing `info` (`unnecessary_brace_in_string_interps`) at `test/userscripts_screen_test.dart:198` — recorded as Fix 3 in the previous feature's `validation.md`. It is not this feature's to fix. Gates treat that specific pre-existing info as known; any **new** analyze issue in changed paths fails the gate.

---

## Execution Plan

### Phase 1: Patrol foundation

Highest-risk phase — if the runner will not stand up, nothing downstream can. Fails fast by design.

```
T1 → T2
```

### Phase 2: Keepalive on real hardware

The reason the feature exists. Closes the open UAT in `STATE.md` and the AD-013 regression.

```
T3 → T4 → T5
```

### Phase 3: Storage on real hardware

```
T6 → T7 → T8
```

### Phase 4: Userscripts over real sockets

```
T9 → T10
```

### Phase 5: Docs & decision record

```
T11
```

---

## Task Breakdown

### T1: Add Patrol dependency and pubspec config

**What**: Add `patrol` as a dev_dependency and the `patrol:` configuration section to the app's pubspec.
**Where**: `apps/popmundo_app/pubspec.yaml`
**Depends on**: None
**Reuses**: Existing `dev_dependencies` block
**Requirement**: E2E-03

**Tools**:
- MCP: `context7` (resolve current stable `patrol` version + config schema)
- Skill: NONE

**Done when**:
- [ ] `patrol` present under `dev_dependencies` with a pinned version resolved via Context7/pub (not guessed)
- [ ] `patrol:` section declares `app_name`, `android.package_name = com.popmundo.popmundo_app`, `ios.bundle_id`
- [ ] `flutter pub get` resolves at the workspace root with no version conflict against `flutter_foreground_task ^11.0.0` / `flutter_inappwebview ^6.1.5`
- [ ] **Spike recorded**: whether a read-only notification API (e.g. `getNotifications`) exists in the resolved Patrol version. Finding written into `design.md` Risks row 1. If it exists, T5 uses it; if not, T5 uses `tapOnNotificationBySelector` as designed
- [ ] Gate passes: `cd apps/popmundo_app && flutter analyze lib test`

**Tests**: none (config layer — build gate only, per matrix)
**Gate**: quick

**Commit**: `test(e2e): add patrol dependency and pubspec config`

---

### T2: Wire Android instrumentation and prove the tier runs

**What**: Add the Patrol JUnit runner to Gradle, create the `androidTest` bootstrap, and add a smoke test that proves the tier executes on the device.
**Where**: `apps/popmundo_app/android/app/build.gradle.kts`, `apps/popmundo_app/android/app/src/androidTest/java/com/popmundo/popmundo_app/MainActivityTest.java`, `apps/popmundo_app/integration_test/smoke_test.dart`
**Depends on**: T1
**Reuses**: `MainActivity` (`android/app/src/main/kotlin/com/popmundo/popmundo_app/MainActivity.kt`)
**Requirement**: E2E-01, E2E-02, E2E-04, E2E-05

**Merged deliberately**: Gradle wiring and the JUnit bootstrap produce no verifiable outcome on their own — the smoke test is what proves them. Splitting would land unverified config (see Tasks §"Resolving compilation dependencies").

**Tools**:
- MCP: `context7` (Patrol Android setup; **translate Groovy docs → Kotlin DSL**)
- Skill: NONE

**Done when**:
- [ ] `build.gradle.kts` `defaultConfig` sets `testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"` and `testInstrumentationRunnerArguments["clearPackageData"] = "true"` — **Kotlin DSL syntax**, not the Groovy from the docs
- [ ] `MainActivityTest.java` exists under package `com.popmundo.popmundo_app`, parameterized per Patrol docs, referencing `MainActivity.class`
- [ ] `smoke_test.dart` pumps a trivial widget and asserts it — imports nothing from `lib/` and constructs no runtime
- [x] `patrol test --target integration_test/smoke_test.dart` is **green on device** (verified on the physical device before it was retired; target is now `emulator-5554`)
- [ ] A deliberately failing assertion in the smoke test produces output naming the test and carrying the message (E2E-04), then is reverted
- [ ] `flutter test` still passes with its existing count and does not pick up `integration_test/` (E2E-05)

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): wire patrol android instrumentation with smoke test`

---

### T3: Test harness + keepalive service lifecycle on device

**What**: Create the shared support harness and the first keepalive device test covering real service startup and idempotency.
**Where**: `apps/popmundo_app/integration_test/support/harness.dart`, `apps/popmundo_app/integration_test/keepalive_test.dart`
**Depends on**: T2
**Reuses**: `BackgroundKeepalive`, `FlutterForegroundTaskPlatform`, `BackgroundStatus`
**Requirement**: KA-01, KA-02, KA-04

**Tools**:
- MCP: `context7` (`flutter_foreground_task` API confirmation)
- Skill: NONE

**Done when**:
- [ ] `harness.dart` exposes `initForegroundComms()`, `pumpHarness()`, `waitForTicks()`, `grantNotificationsIfAsked()` per design
- [ ] `initForegroundComms()` calls `FlutterForegroundTask.initCommunicationPort()` — **the step `lib/main.dart:13` performs that does not run under `integration_test`**
- [ ] KA-01: bootstrap against the real platform → notification granted via native dialog (guarded by `isPermissionDialogVisible()`), `serviceRunning` becomes `true`
- [ ] KA-02: real `FlutterForegroundTaskPlatform.isRunningService()` returns `true`
- [ ] KA-04: second `bootstrap()` starts no second service; `serviceRunning` stays `true`
- [ ] No harness member is unused — every one is exercised by this task's tests or a later one in the same phase
- [ ] Gate passes: `patrol test --target integration_test/keepalive_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert real foreground service lifecycle on device`

---

### T4: Heartbeat across the real isolate boundary

**What**: Add the device test asserting the real `KeepaliveTaskHandler` isolate delivers heartbeats to the main isolate.
**Where**: `apps/popmundo_app/integration_test/keepalive_test.dart` (modify)
**Depends on**: T3
**Reuses**: `waitForTicks()` from T3, `KeepaliveTaskHandler`
**Requirement**: KA-03

**Isolated deliberately**: design Risks row 2 — if the FGS isolate cannot resolve the `@pragma('vm:entry-point')` entry point in a test build, this fails for infrastructure reasons rather than a real defect. Keeping it as its own task makes that failure unambiguous.

**Tools**:
- MCP: `context7` (`flutter_foreground_task` isolate/entry-point behavior if the entry point does not resolve)
- Skill: NONE

**Done when**:
- [ ] KA-03: **two distinct** heartbeats received within 30s, second strictly later than the first — one tick alone must not satisfy the assertion
- [ ] `waitForTicks` timeout message names ticks received vs expected (E2E-04)
- [ ] Test completes in bounded time even when no heartbeat ever arrives — it fails, never hangs
- [ ] Gate passes: `patrol test --target integration_test/keepalive_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert heartbeat crosses the real isolate boundary`

---

### T5: FGS survives backgrounding (AD-013 regression)

**What**: Add the device test that backgrounds the app and asserts the keepalive notification and heartbeat both survive.
**Where**: `apps/popmundo_app/integration_test/keepalive_test.dart` (modify)
**Depends on**: T4
**Reuses**: harness, `waitForTicks()`
**Requirement**: KA-05, KA-06

**This is the feature's reason for existing.** It is the automated form of the UAT still open in `STATE.md` Handoff.

**Tools**:
- MCP: `context7` (Patrol notification API — use the T1 spike result)
- Skill: NONE

**Done when**:
- [ ] KA-05: after `pressHome()` + `openNotifications()`, a notification matching `textContains: 'Popmundo is running'` is asserted present (reader API if the T1 spike found one; otherwise `tapOnNotificationBySelector` with a 5s timeout)
- [ ] KA-06: after returning to the app, the service is still running **and** the heartbeat advanced past its pre-background value
- [ ] **Mutation proof recorded**: with `stopWithTask` reverted to `true` in both the manifest and the adapter, KA-05 goes **red**; the revert is undone and the tree left clean. Evidence pasted into the commit body or `validation.md`
- [ ] Gate passes: `patrol test --target integration_test/keepalive_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert FGS survives backgrounding (AD-013 regression)`

---

### T6: Secure storage round-trip on real Keystore

**What**: Device test for `FlutterSecureSecretStore` write/read/delete against the real Android Keystore.
**Where**: `apps/popmundo_app/integration_test/storage_test.dart`
**Depends on**: T2
**Reuses**: `FlutterSecureSecretStore`
**Requirement**: STO-01, STO-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] STO-01: `write` then `read` returns the exact value (real Keystore / EncryptedSharedPreferences)
- [ ] STO-02: `delete` then `read` returns `null`
- [ ] Test cleans up its own keys so repeated runs are idempotent even if `clearPackageData` is disabled
- [ ] Gate passes: `patrol test --target integration_test/storage_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert secure storage round-trip on real keystore`

---

### T7: SharedPreferences round-trip on device

**What**: Device test for `SharedPreferencesStore` JSON round-trip and removal through the real platform channel.
**Where**: `apps/popmundo_app/integration_test/storage_test.dart` (modify)
**Depends on**: T6
**Reuses**: `SharedPreferencesStore`
**Requirement**: STO-04, STO-05

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] STO-04: a structured value written via `set` is returned equal by `get` from a **freshly constructed** `SharedPreferencesStore` — proving the real channel, not an in-memory cache
- [ ] STO-05: `remove` then `get` returns `null`
- [ ] Gate passes: `patrol test --target integration_test/storage_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert shared preferences round-trip on device`

---

### T8: Password never lands in plain SharedPreferences

**What**: Device test asserting a saved Auto Login password is absent from plain SharedPreferences while readable from the secret store.
**Where**: `apps/popmundo_app/integration_test/storage_test.dart` (modify)
**Depends on**: T7
**Reuses**: `FlutterSecureSecretStore`, `SharedPreferencesStore`, `AutoLoginSettingsStore`
**Requirement**: STO-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] A password is saved through the Auto Login storage path (settings via `KeyValueStore`, password via `SecretStore`)
- [ ] Every key from `SharedPreferences.getKeys()` is read and **no** stored value equals the password, nor contains it as a substring
- [ ] The same password **is** readable via `SecretStore.read` — proving the test would catch a store swap rather than trivially passing on an empty store
- [ ] Gate passes: `patrol test --target integration_test/storage_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert password never reaches plain shared preferences`

---

### T9: Userscript download over real sockets

**What**: Device test that serves a userscript from an in-test loopback server and imports it into the catalog.
**Where**: `apps/popmundo_app/integration_test/userscripts_test.dart`
**Depends on**: T2
**Reuses**: `fetchUserScriptUrl`, `UserScriptCatalog`, `UserScriptImporter`, `SharedPreferencesStore`
**Requirement**: US-01, US-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] A loopback `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` is started per test and closed in `addTearDown` — port `0`, nothing hardcoded
- [ ] US-01: `fetchUserScriptUrl` returns exactly the served body
- [ ] US-02: the imported script is listed by a **freshly constructed** catalog over real `SharedPreferences`
- [ ] No request leaves the device — assertion targets loopback only
- [ ] Gate passes: `patrol test --target integration_test/userscripts_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert userscript download and import over real sockets`

---

### T10: Userscript download failure paths

**What**: Device tests for non-2xx and timeout handling in `fetchUserScriptUrl`.
**Where**: `apps/popmundo_app/integration_test/userscripts_test.dart` (modify)
**Depends on**: T9
**Reuses**: loopback server helper from T9
**Requirement**: US-03, US-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] US-03: a non-2xx response throws `UserScriptImportException` whose message names the status code
- [ ] US-04: a server that accepts but never responds triggers `UserScriptImportException` indicating a timeout, using a short injected `timeout` so the test stays bounded
- [ ] Both assert the exception **type and message**, not merely that something threw
- [ ] Gate passes: `patrol test --target integration_test/userscripts_test.dart -d emulator-5554`

**Tests**: e2e (device)
**Gate**: full

**Commit**: `test(e2e): assert userscript download failure paths`

---

### T11: Document the device tier and record AD-014

**What**: Document the tier in `CLAUDE.md` Commands and append the project-level decision to `STATE.md`.
**Where**: `CLAUDE.md`, `.specs/STATE.md`
**Depends on**: T5, T8, T10
**Reuses**: Existing `CLAUDE.md` Commands section format
**Requirement**: DOC-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `CLAUDE.md` Commands documents `patrol test`, the `patrol_cli` global prerequisite, and the device-id flag
- [ ] `CLAUDE.md` states the device tier never touches popmundo.com and explains **why it structurally cannot** (test file is the Dart entrypoint; `lib/main.dart` does not run)
- [ ] The existing "No live-site e2e tests" bullet is updated so it no longer reads as "no device tests exist" — it must stay accurate about the live-site ban while acknowledging the new tier
- [ ] `.specs/STATE.md` gains **AD-014** (device-real tier exists; Patrol is its runner; boundary against popmundo.com) with the standard Decision/Reason/Trade-off/Scope/Date/Status fields
- [ ] `.specs/STATE.md` Handoff updated — the pending device UAT is now automated by KA-05/KA-06
- [ ] Gate passes: build gate (`flutter analyze` scoped, `flutter test`, full `patrol test`)

**Tests**: none (docs layer — per matrix)
**Gate**: build

**Commit**: `docs(e2e): document device test tier and record AD-014`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Phase 1:  T1 ──→ T2
Phase 2:  T3 ──→ T4 ──→ T5
Phase 3:  T6 ──→ T7 ──→ T8
Phase 4:  T9 ──→ T10
Phase 5:  T11
```

T3, T6 and T9 each depend on T2 (the tier must run before any device test can). Phases 2–4 are ordered by risk, highest first.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: Patrol dep + pubspec config | 1 file, 1 concept | ✅ Granular |
| T2: Gradle + androidTest + smoke | 3 files, 1 indivisible deliverable | ⚠️ OK — config is unverifiable without the smoke test; splitting would land unverified code |
| T3: Harness + service lifecycle | 2 files, cohesive (infra + first consumer) | ⚠️ OK — harness must not land unused |
| T4: Heartbeat isolate | 1 file, 1 criterion | ✅ Granular |
| T5: Backgrounding survival | 1 file, 1 scenario | ✅ Granular |
| T6: Secure store | 1 file, 1 store | ✅ Granular |
| T7: Prefs store | 1 file, 1 store | ✅ Granular |
| T8: Password isolation | 1 file, 1 property | ✅ Granular |
| T9: Userscript happy path | 1 file, 1 flow | ✅ Granular |
| T10: Userscript failures | 1 file, 2 error paths | ✅ Granular |
| T11: Docs + AD-014 | 2 files, 1 concept | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (body) | Diagram Shows | Status |
| ---- | ----------------- | ------------- | ------ |
| T1 | None | (phase entry) | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | Phase 1 → Phase 2 entry | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T2 | Phase 1 → Phase 3 entry | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T7 | T7 → T8 | ✅ Match |
| T9 | T2 | Phase 1 → Phase 4 entry | ✅ Match |
| T10 | T9 | T9 → T10 | ✅ Match |
| T11 | T5, T8, T10 | Phases 2–4 → Phase 5 | ✅ Match |

No task depends on a later phase. ✅

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Build & instrumentation config | none (build gate) | none | ✅ OK |
| T2 | Build config + device test suite | e2e | e2e | ✅ OK |
| T3 | Test support + device test suite | e2e | e2e | ✅ OK |
| T4 | Device test suite | e2e | e2e | ✅ OK |
| T5 | Device test suite | e2e | e2e | ✅ OK |
| T6 | Device test suite | e2e | e2e | ✅ OK |
| T7 | Device test suite | e2e | e2e | ✅ OK |
| T8 | Device test suite | e2e | e2e | ✅ OK |
| T9 | Device test suite | e2e | e2e | ✅ OK |
| T10 | Device test suite | e2e | e2e | ✅ OK |
| T11 | Docs | none | none | ✅ OK |

No violations. ✅

---

## Requirement Coverage

| Requirement | Task |
| ----------- | ---- |
| E2E-01, E2E-02, E2E-04, E2E-05 | T2 |
| E2E-03 | T1 |
| KA-01, KA-02, KA-04 | T3 |
| KA-03 | T4 |
| KA-05, KA-06 | T5 |
| STO-01, STO-02 | T6 |
| STO-04, STO-05 | T7 |
| STO-03 | T8 |
| US-01, US-02 | T9 |
| US-03, US-04 | T10 |
| DOC-01 | T11 |

**Coverage:** 21 total, 21 mapped to tasks, 0 unmapped ✅
