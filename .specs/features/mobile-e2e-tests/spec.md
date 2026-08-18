# Mobile E2E Tests (Device-Real Tier) Specification

## Problem Statement

Every test in `apps/popmundo_app` substitutes a fake for the platform layer — `FakeBackgroundPlatform`, `MemoryKeyValueStore`, fake event streams. The tier is fast and device-free by design (CLAUDE.md), but it is structurally blind to runtime/platform behavior: no real Android API, no real isolate, no real keystore, no real socket is ever exercised.

AD-013 is the proof. `stopWithTask="true"` told Android to kill the foreground service the moment the app left Recents — defeating the entire point of AD-012 — and it shipped through a Verifier **PASS** with 54 green tests. It was found by a human noticing the notification vanish. `STATE.md` Handoff still lists that manual device UAT as the open next step.

We need a second, device-real test tier that catches exactly this class of bug, without touching popmundo.com.

## Goals

- [ ] A Patrol test tier runs on a real Android device and covers the three mobile-only areas — background keepalive, storage (secure + prefs), userscript import — with **zero** requests to popmundo.com
- [ ] The AD-013 regression is caught automatically: the FGS notification is asserted **present in the system shade after the app is backgrounded**, and the heartbeat is asserted **still advancing**
- [ ] First-ever coverage for the real platform implementations: `FlutterForegroundTaskPlatform`, `KeepaliveTaskHandler` (real isolate), `FlutterSecureSecretStore`, `SharedPreferencesStore`, `fetchUserScriptUrl` (real sockets)
- [ ] The pending device UAT in `STATE.md` Handoff is closed by an automated test, not a checklist

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| ------- | ------ |
| Any test that loads popmundo.com | CLAUDE.md hard constraint (instability, real auth, ToS). Tests pump minimal harness widgets, never `PopmundoApp`/`PopmundoWebView` pointed at the live game |
| Auto Login authenticating for real | Requires the live site. Only the storage/settings half of Auto Login is device-tested |
| Userscript injection into a live WebView | Requires the live site; `popmundo_webview` bridge stays on the fake tier |
| iOS device tests | No iOS device available. Patrol config is left iOS-ready (`bundle_id`) but no iOS test is written or claimed |
| Swipe-from-Recents task removal | User decision: no Patrol primitive; coordinate gestures are fragile across devices/skins. `stopWithTask="false"` stays asserted as config by `platform_config_test.dart` |
| CI wiring | No CI config exists in-repo today; the tier is invoked manually, same as `flutter test` |
| Replacing the existing fake-based tests | The two tiers are complementary — fast/device-free for logic, slow/device-real for platform |
| Performance / battery-drain measurement | Different discipline; this spec is about correctness only |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here — nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Runner | Patrol (`patrol_cli` + `patrolTest`) | Only option with `pressHome()` / `openNotifications()` — required to assert the AD-013 notification survives backgrounding | y (user) |
| Scope of first batch | All three mobile areas at once | User decision | y (user) |
| Depth of survival proof | `pressHome()` + notification visible in shade + heartbeat still advancing | User decision; Recents-swipe excluded above | y (user) |
| Patrol version | Resolve latest stable `patrol` + matching `patrol_cli` at implementation via Context7/pub | Pinning a version in the spec would go stale before Execute | n |
| Test entry widget | A minimal harness widget per area, never `PopmundoApp` | `PopmundoApp` constructs `InAppPopmundoRuntime` which navigates to popmundo.com — violates the hard constraint | n |
| `clearPackageData` | `true` in `testInstrumentationRunnerArguments` | Guarantees storage tests start from empty state. Consequence: runtime permissions reset per run, so each test grants via Patrol native rather than relying on a persisted grant | n |
| Userscript HTTP source | Loopback `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` started inside the test | Exercises the real `HttpClient` and real sockets while staying hermetic — no public-internet dependency to flake | n |
| Heartbeat assertion shape | Wait for **two distinct** ticks, assert strictly increasing, bounded ~30s timeout | `eventAction` is `repeat(5000)`; asserting one tick would pass on a stuck clock. Bounded wait keeps a broken FGS from hanging the suite | n |
| Password-leak assertion | Assert no `SharedPreferences` value equals the written password | Turns "password lives only in SecretStore" from a code-reading claim into an executable check | n |
| Existing `flutter test` suite | Untouched; the new tier is additive | Tiers are complementary; regressing the fast tier would be a net loss | n |
| Test directory | `apps/popmundo_app/integration_test/` | Patrol's default `test_directory`; keeps the app package self-contained | n |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Tier de teste em device real ⭐ MVP

**User Story**: As a developer of this repo, I want a Patrol test tier wired to the Android app, so that I can assert real platform behavior that the fake-based tier cannot reach.

**Why P1**: Every other story depends on it. Without the runner, nothing device-real can be asserted.

**Acceptance Criteria**:

1. WHEN `patrol test` is invoked from `apps/popmundo_app` against the connected Android device THEN the suite SHALL build, install, and execute on-device, reporting per-test pass/fail
2. WHEN the Android test bootstrap is configured THEN `build.gradle.kts` SHALL declare `testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"` with `clearPackageData = "true"`, and an `androidTest` JUnit bootstrap SHALL exist for package `com.popmundo.popmundo_app` referencing `MainActivity`
3. WHEN `pubspec.yaml` is read THEN it SHALL contain a `patrol:` section with `android.package_name = com.popmundo.popmundo_app` and an iOS `bundle_id`, and `patrol` SHALL be a `dev_dependency`
4. WHEN a device test fails THEN the failure output SHALL identify the failing test by name and carry the assertion message, so the cause is diagnosable without re-running manually
5. WHEN the existing fast tier is run (`flutter test` in `apps/popmundo_app`) THEN it SHALL still pass unchanged, and SHALL NOT attempt to execute anything under `integration_test/`

**Independent Test**: Run `patrol test` with a single trivial on-device test that pumps a `Text` widget and asserts it — green means the tier works.

---

### P1: Keepalive real em device ⭐ MVP

**User Story**: As a developer, I want the background keepalive exercised against the real Android foreground service and the real task isolate, so that a regression like AD-013 fails a test instead of reaching a user.

**Why P1**: This is the bug class that already escaped. It is the reason the feature exists, and it closes the open UAT in `STATE.md`.

**Acceptance Criteria**:

1. **KA-01** — WHEN `BackgroundKeepalive.bootstrap()` runs on-device against a real `FlutterForegroundTaskPlatform` THEN the notification permission SHALL be granted through the native dialog and `status.value.serviceRunning` SHALL become `true`
2. **KA-02** — WHEN the foreground service is running THEN `FlutterForegroundTaskPlatform.isRunningService()` SHALL return `true` (real plugin call, not a fake)
3. **KA-03** — WHEN the real `KeepaliveTaskHandler` isolate emits heartbeats THEN the main isolate SHALL receive **two distinct** ticks within 30s and the second tick SHALL be strictly later than the first
4. **KA-04** — WHEN `bootstrap()` is called a second time while the service is already running THEN no second service SHALL be started and `serviceRunning` SHALL remain `true`
5. **KA-05** — WHEN the app is backgrounded via `pressHome()` THEN the notification titled **"Popmundo is running"** SHALL still be present in the system notification shade *(AD-013 regression)*
6. **KA-06** — WHEN the app is backgrounded and then reopened via `openApp()` THEN the service SHALL still be running and the heartbeat SHALL have advanced past its pre-background value *(proves the FGS kept working, not merely that the notification lingered)*

**Independent Test**: Revert `stopWithTask` to `true` in the manifest and adapter — KA-05 must go red. That single mutation is the feature's reason for existing.

---

### P2: Storage real (secure + prefs)

**User Story**: As a developer, I want the real Keystore-backed and SharedPreferences-backed stores exercised on-device, so that I know the password never lands in plaintext and settings actually survive.

**Why P2**: Real security property, but no known active bug — ships right after keepalive.

**Acceptance Criteria**:

1. **STO-01** — WHEN a value is written through `FlutterSecureSecretStore.write` and read back on-device THEN the read SHALL return the exact value written (real Android Keystore / EncryptedSharedPreferences round-trip)
2. **STO-02** — WHEN `FlutterSecureSecretStore.delete` is called for an existing key THEN a subsequent `read` SHALL return `null`
3. **STO-03** — WHEN a password is saved through the Auto Login flow THEN **no** value stored in plain `SharedPreferences` SHALL equal that password
4. **STO-04** — WHEN a structured value is written through `SharedPreferencesStore.set` and read through a **freshly constructed** `SharedPreferencesStore` THEN `get` SHALL return an equal structure (real JSON round-trip through the platform channel)
5. **STO-05** — WHEN `SharedPreferencesStore.remove` is called THEN a subsequent `get` SHALL return `null`

**Independent Test**: Write a password via the harness, then dump `SharedPreferences` on-device and confirm the plaintext is absent while `SecretStore.read` returns it.

---

### P2: Import de userscript real

**User Story**: As a developer, I want userscript download and import exercised over real sockets, so that HTTP failure handling is proven rather than assumed.

**Why P2**: `fetchUserScriptUrl` uses `dart:io` `HttpClient`, which no current test touches — but the parsing/catalog logic above it is already well covered on the fast tier.

**Acceptance Criteria**:

1. **US-01** — WHEN a loopback `HttpServer` serves a valid userscript body and `fetchUserScriptUrl` requests it THEN the returned string SHALL equal the served body
2. **US-02** — WHEN the imported script is persisted through the catalog on real `SharedPreferences` THEN listing the catalog from a fresh instance SHALL include that script
3. **US-03** — WHEN the loopback server responds with a non-2xx status THEN `fetchUserScriptUrl` SHALL throw `UserScriptImportException` naming the status code
4. **US-04** — WHEN the loopback server accepts the connection but never responds and the configured timeout elapses THEN `fetchUserScriptUrl` SHALL throw `UserScriptImportException` indicating a timeout, within a bounded test duration

**Independent Test**: Point the harness at the in-test loopback server, import, and see the script appear in the list; then switch the server to 404 and see the typed exception.

---

### P3: Documentação do tier

**User Story**: As a future contributor (or agent), I want the device tier documented next to the existing commands, so that I know it exists and how to run it.

**Why P3**: Valuable but non-blocking; the tier works without it.

**Acceptance Criteria**:

1. **DOC-01** — WHEN `CLAUDE.md`'s Commands section is read THEN it SHALL document the `patrol test` invocation, the `patrol_cli` prerequisite, and the fact that the device tier never touches popmundo.com

---

## Edge Cases

- WHEN the notification permission dialog does not appear (already granted, or OEM skin differs) THEN the test SHALL proceed rather than hang — guard with `isPermissionDialogVisible()` before granting
- WHEN the foreground service fails to start on-device THEN KA-01 SHALL fail with a clear assertion within its bounded wait, never hang the suite
- WHEN the heartbeat never arrives THEN KA-03 SHALL fail on its 30s bound rather than await indefinitely
- WHEN `clearPackageData=true` wipes the runtime permission grant between tests THEN each test needing it SHALL re-grant via Patrol native rather than assume a persisted grant
- WHEN the loopback server port is already in use THEN binding to port `0` SHALL let the OS assign a free port — no hardcoded port anywhere
- WHEN no Android device is connected THEN `patrol test` SHALL fail fast with a device error; the fast tier SHALL remain runnable independently

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| E2E-01 | P1: Tier de teste em device real | Design | Pending |
| E2E-02 | P1: Tier de teste em device real | Design | Pending |
| E2E-03 | P1: Tier de teste em device real | Design | Pending |
| E2E-04 | P1: Tier de teste em device real | Design | Pending |
| E2E-05 | P1: Tier de teste em device real | Design | Pending |
| KA-01 | P1: Keepalive real em device | Design | Pending |
| KA-02 | P1: Keepalive real em device | Design | Pending |
| KA-03 | P1: Keepalive real em device | Design | Pending |
| KA-04 | P1: Keepalive real em device | Design | Pending |
| KA-05 | P1: Keepalive real em device | Design | Pending |
| KA-06 | P1: Keepalive real em device | Design | Pending |
| STO-01 | P2: Storage real | Design | Pending |
| STO-02 | P2: Storage real | Design | Pending |
| STO-03 | P2: Storage real | Design | Pending |
| STO-04 | P2: Storage real | Design | Pending |
| STO-05 | P2: Storage real | Design | Pending |
| US-01 | P2: Import de userscript real | Design | Pending |
| US-02 | P2: Import de userscript real | Design | Pending |
| US-03 | P2: Import de userscript real | Design | Pending |
| US-04 | P2: Import de userscript real | Design | Pending |
| DOC-01 | P3: Documentação do tier | - | Pending |

**ID format:** `[CATEGORY]-[NUMBER]`
**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 21 total, 0 mapped to tasks (Tasks phase pending)

---

## Implicit-Requirement Dimensions Sweep

Large scope — every dimension resolves to a requirement or an explicit `N/A because`.

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | US-03 (non-2xx), US-04 (timeout); every on-device wait is bounded (KA-03 at 30s) |
| Failure / partial-failure states | KA-01/KA-03 fail loudly within bounds instead of hanging; edge cases table |
| Idempotency / retry / duplicate handling | KA-04 — second `bootstrap()` starts no second service, verified against the real plugin |
| Auth boundaries & rate limits | **N/A because** no auth surface is exercised — popmundo.com login is out of scope and tests run as the app's own uid |
| Concurrency / ordering | KA-03 — heartbeat crosses a real isolate boundary; ordering asserted (tick₂ > tick₁), not mere presence |
| Data lifecycle / expiry | STO-02, STO-05 (delete/remove actually clear); `clearPackageData=true` gives each test empty initial state |
| Observability | E2E-04 — failing device tests must name the test and carry the assertion message |
| External-dependency failure | US-01/US-04 use a loopback server bound in-test — **no public-internet dependency exists to fail** |
| State-transition integrity | KA-06 — resumed → backgrounded → resumed, with the service asserted alive and the heartbeat advanced across the whole transition |

---

## Success Criteria

- [ ] `patrol test` runs green on the connected Android device with all P1 + P2 criteria asserted
- [ ] Reverting `stopWithTask` to `true` turns KA-05 red — the tier demonstrably catches the bug that escaped
- [ ] Zero network requests to `popmundo.com` originate from the device tier
- [ ] `flutter test` in `apps/popmundo_app` still passes, unchanged, and ignores `integration_test/`
- [ ] `STATE.md` Handoff's pending device UAT is replaced by an automated, repeatable test
