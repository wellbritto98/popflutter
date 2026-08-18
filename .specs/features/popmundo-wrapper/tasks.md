# Popmundo Wrapper Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/popmundo-wrapper/design.md`
**Status**: Done

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec — confirm before Execute. Guidelines found: none — strong defaults applied. Plan approved: unit tests with FakePopmundoRuntime; overlay widget tests; no live Popmundo e2e.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (`popmundo_utils`) | unit | All branches; 1:1 to spec ACs; all listed edge cases | `packages/popmundo_utils/test/**/*_test.dart` | `dart test` (cwd package) |
| Adapter (`popmundo_webview`) | unit | Policy wiring + script assets exist; no live site | `packages/popmundo_webview/test/**/*_test.dart` | `flutter test` (cwd package) |
| App overlay | unit/widget | Overlay ACs: collapsed hit-test, list events, eval, clear, hide cookie values | `apps/popmundo_app/test/**/*_test.dart` | `flutter test` (cwd app) |
| Platform config / Melos | none | — (build gate only) | — | `flutter analyze` |

## Gate Check Commands

> Generated from planned Flutter/Dart toolchain — confirm before Execute.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After utils unit tasks | `cd packages/popmundo_utils && dart test` |
| Full | After webview/app widget tasks | `cd packages/popmundo_utils && dart test` && `cd packages/popmundo_webview && flutter test` && `cd apps/popmundo_app && flutter test` |
| Build | After phase completion or config-only tasks | `dart analyze packages/popmundo_utils` && `flutter analyze packages/popmundo_webview apps/popmundo_app` && Full gate |

---

## Execution Plan

Phases are ordered and run sequentially — each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Foundation

```
T1 → T2 → T3 → T4 → T5 → T6
```

### Phase 2: Utils domain

```
T7 → T8 → T9 → T10 → T11
```

### Phase 3: WebView adapter

```
T12 → T13 → T14
```

### Phase 4: App shell

```
T15 → T16 → T17
```

---

## Task Breakdown

### T1: Scaffold Melos + licenses

**What**: Create Melos workspace, Flutter app (android+ios), Dart package `popmundo_utils`, Flutter package `popmundo_webview`, GPL-3 LICENSE + NOTICE.
**Where**: `melos.yaml`, `pubspec.yaml`, `apps/popmundo_app/`, `packages/popmundo_utils/`, `packages/popmundo_webview/`, `LICENSE`, `NOTICE`
**Depends on**: None
**Reuses**: none
**Requirement**: WRAP-01 (bootstrap)

**Tools**:

- MCP: NONE
- Skill: tlc-spec-driven

**Done when**:

- [ ] `flutter create` app with android+ios only
- [ ] Two packages exist and are referenced by the workspace
- [ ] LICENSE GPL-3.0-or-later and NOTICE citing Popmundo-Utils

**Tests**: none
**Gate**: build (packages exist; analyze when code lands)

---

### T2: HostTracker

**What**: Sticky origin + `isPopmundoHost` + `resolve` path helper.
**Where**: `packages/popmundo_utils/lib/src/host_tracker.dart`
**Depends on**: T1
**Reuses**: design HostTracker
**Requirement**: HOST-01, HOST-02, WRAP-01

**Done when**:

- [ ] Default origin `https://www.popmundo.com`
- [ ] Redirect to numeric host updates origin
- [ ] External host does not update origin
- [ ] `resolve('/x')` uses current host with leading/trailing slash rules from spec
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T3: ObservePolicy

**What**: Pure navigation decision + observe-only resource policy (`null` replacement).
**Where**: `packages/popmundo_utils/lib/src/observe_policy.dart`
**Depends on**: T2
**Reuses**: HostTracker allowlist
**Requirement**: HOST-03, INT-04

**Done when**:

- [ ] Popmundo URIs → `allowInWebView`
- [ ] Other http(s) → `openExternal`
- [ ] `observeOnlyResourceResponse()` is `null`
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T4: Events + body truncation

**What**: Network/Console/Navigation events, bus, 32 KiB truncate helper.
**Where**: `packages/popmundo_utils/lib/src/events.dart`
**Depends on**: T1
**Reuses**: none
**Requirement**: INT-01, INT-02, INT-03, INT-05

**Done when**:

- [ ] Truncate at 32768 bytes sets `bodyTruncated`
- [ ] Null/binary omitted flag helper
- [ ] Streams deliver emitted events
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T5: PopmundoRuntime + Fake

**What**: Abstract runtime + in-memory fake for tests (evaluate map, fetchInPage, ready).
**Where**: `packages/popmundo_utils/lib/src/popmundo_runtime.dart`, `test/fake_runtime.dart`
**Depends on**: T2, T4
**Reuses**: HostTracker, EventBus
**Requirement**: UTIL-04 (error surface)

**Done when**:

- [ ] Fake can script evaluate/fetch results and timeouts
- [ ] `waitUntilReady` respects timeout
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T6: Logger ring buffer

**What**: Bounded 200-entry warn/error buffer.
**Where**: `packages/popmundo_utils/lib/src/logger.dart`
**Depends on**: T1
**Reuses**: none
**Requirement**: LOG-01

**Done when**:

- [ ] Overflow drops oldest
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T7: StorageService

**What**: KeyValueStore + exclude-list APIs without chrome.
**Where**: `packages/popmundo_utils/lib/src/storage.dart`
**Depends on**: T1
**Reuses**: logical keys from utils.js
**Requirement**: STOR-01, STOR-02, STOR-03

**Done when**:

- [ ] Memory store persists across get/set in process
- [ ] toggleExclusion / getExcludedIds
- [ ] normalizeExcludeMap / excludeEntryId edge cases
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T8: TimedFetch

**What**: Serial 750 ms delay, cache METHOD:URL, relative URL vs current host, no cache on error.
**Where**: `packages/popmundo_utils/lib/src/timed_fetch.dart`
**Depends on**: T5
**Reuses**: Fake runtime + fake clock
**Requirement**: UTIL-01, UTIL-02, UTIL-03, UTIL-04, UTIL-05

**Done when**:

- [ ] All five TimedFetch ACs have tests
- [ ] Overlap does not double-fetch
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T9: Utils character + getServerLink

**What**: getMyID, getMyName, getServerLink via runtime evaluate / HostTracker.
**Where**: `packages/popmundo_utils/lib/src/utils.dart`
**Depends on**: T5
**Reuses**: Fake DOM scrape results
**Requirement**: UTIL-06, HOST-02

**Done when**:

- [ ] Missing node → 0 / ''
- [ ] Non-numeric idHolder → 0
- [ ] getServerLink uses current host
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T10: Notifications

**What**: DOM notification helpers + parse GetPageNotifications + POST via TimedFetch useCache false.
**Where**: `packages/popmundo_utils/lib/src/notifications.dart`
**Depends on**: T8
**Reuses**: TimedFetch
**Requirement**: UTIL-07, UTIL-08

**Done when**:

- [ ] Unknown level errors
- [ ] Missing container does not throw
- [ ] getPageNotifications hits path + cache false
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T11: CssSelector + Scoring API (no auto-apply)

**What**: CssSelectorHelper facade + Scoring methods that only evaluate when called; export flag that default scripts must not auto-run.
**Where**: `packages/popmundo_utils/lib/src/css_selector.dart`, `scoring.dart`
**Depends on**: T5
**Reuses**: Fake evaluate
**Requirement**: UTIL-09, SCORE-01, SCORE-02

**Done when**:

- [ ] getSingle/getAll return serialized maps
- [ ] applyScoringNumbers invokes evaluate
- [ ] `Scoring.autoApplyOnLoad == false`
- [ ] Gate: quick

**Tests**: unit
**Gate**: quick

---

### T12: UserScripts assets

**What**: hooks.js (fetch/XHR/console queue) + helpers.js (DOM APIs, no auto Scoring).
**Where**: `packages/popmundo_webview/assets/js/`
**Depends on**: T11
**Reuses**: common/ selectors
**Requirement**: INT-01, INT-02, SCORE-01

**Done when**:

- [ ] helpers.js does not call applyScoringNumbers on load
- [ ] hooks wrap fetch/XHR/console
- [ ] Asset listed in pubspec
- [ ] Gate: flutter test package (string/asset tests)

**Tests**: unit
**Gate**: full

---

### T13: PopmundoWebView + InAppPopmundoRuntime

**What**: Widget + runtime: settings non-incognito, observe-only intercepts, handler, host updates, url_launcher for external.
**Where**: `packages/popmundo_webview/lib/`
**Depends on**: T3, T12
**Reuses**: ObservePolicy, EventBus
**Requirement**: WRAP-01, SESS-01, INT-04, HOST-03

**Done when**:

- [ ] Settings `incognito: false`
- [ ] Fetch/ajax intercept returns request unchanged; resource intercept returns null
- [ ] Initial URL www.popmundo.com
- [ ] Gate: full

**Tests**: unit (settings/policy helpers; widget smoke if possible)
**Gate**: full

---

### T14: Android/iOS platform config

**What**: INTERNET permission, iOS ATS NSIncludesSubdomains for popmundo.com.
**Where**: `apps/popmundo_app/android/`, `apps/popmundo_app/ios/`
**Depends on**: T1
**Reuses**: inappwebview docs
**Requirement**: WRAP-01

**Done when**:

- [ ] Android INTERNET present
- [ ] Info.plist includes popmundo.com with subdomains
- [ ] Gate: build (file assertions in test or documented inspect)

**Tests**: none (config) + small unit reading plist/manifest if cheap
**Gate**: build

---

### T15: App composition root

**What**: MaterialApp, wire runtime, SharedPreferences KeyValueStore, PopmundoWebView fullscreen.
**Where**: `apps/popmundo_app/lib/main.dart`, `app.dart`
**Depends on**: T13, T7
**Reuses**: packages
**Requirement**: WRAP-01, SESS-01, STOR-01

**Done when**:

- [ ] App builds (`flutter analyze` app)
- [ ] Composition uses non-incognito webview
- [ ] Gate: build

**Tests**: none for main; analyze
**Gate**: build

---

### T16: Debug overlay

**What**: Collapsible overlay: host, network, console, eval, clear, cookie names hidden values.
**Where**: `apps/popmundo_app/lib/debug_overlay.dart`
**Depends on**: T15
**Reuses**: EventBus
**Requirement**: DBG-01, DBG-02, DBG-03, DBG-04, SESS-02

**Done when**:

- [ ] Widget tests for all overlay ACs
- [ ] Gate: full

**Tests**: unit/widget
**Gate**: full

---

### T17: README + barrel exports

**What**: README how to extend utils; public exports; update spec traceability In Tasks.
**Where**: `README.md`, `lib/popmundo_utils.dart`, `lib/popmundo_webview.dart`
**Depends on**: T16
**Reuses**: none
**Requirement**: (docs)

**Done when**:

- [ ] README explains packages, TimedFetch, host sticky, overlay
- [ ] Barrels export public API
- [ ] Gate: full

**Tests**: none
**Gate**: full

---

## Execution Diagram

```
T1 → T2 → T3 → T4 → T5 → T6
       └→ T7
T5 → T8 → T10
T5 → T9
T5 → T11 → T12 → T13 → T15 → T16 → T17
T3 → T13
T1 → T14
T7 → T15
```

## Diagram-Definition Cross-Check

| Task | Depends on (field) | Diagram | Match |
| ---- | ------------------ | ------- | ----- |
| T1 | None | root | PASS |
| T2 | T1 | T1→T2 | PASS |
| T3 | T2 | T2→T3 | PASS |
| T4 | T1 | T1→T4 | PASS |
| T5 | T2, T4 | T2/T4→T5 | PASS |
| T6 | T1 | T1→T6 | PASS |
| T7 | T1 | T1→T7 | PASS |
| T8 | T5 | T5→T8 | PASS |
| T9 | T5 | T5→T9 | PASS |
| T10 | T8 | T8→T10 | PASS |
| T11 | T5 | T5→T11 | PASS |
| T12 | T11 | T11→T12 | PASS |
| T13 | T3, T12 | T3/T12→T13 | PASS |
| T14 | T1 | T1→T14 | PASS |
| T15 | T13, T7 | T13/T7→T15 | PASS |
| T16 | T15 | T15→T16 | PASS |
| T17 | T16 | T16→T17 | PASS |

## Test Co-location Validation

| Task | Layer | Matrix type | Tests field | Match |
| ---- | ----- | ----------- | ----------- | ----- |
| T1 | config | none | none | PASS |
| T2 | domain | unit | unit | PASS |
| T3 | domain | unit | unit | PASS |
| T4 | domain | unit | unit | PASS |
| T5 | domain | unit | unit | PASS |
| T6 | domain | unit | unit | PASS |
| T7 | domain | unit | unit | PASS |
| T8 | domain | unit | unit | PASS |
| T9 | domain | unit | unit | PASS |
| T10 | domain | unit | unit | PASS |
| T11 | domain | unit | unit | PASS |
| T12 | adapter | unit | unit | PASS |
| T13 | adapter | unit | unit | PASS |
| T14 | config | none | none | PASS |
| T15 | app | none | none | PASS |
| T16 | overlay | widget | unit/widget | PASS |
| T17 | docs | none | none | PASS |

## Granularity Check

Each task is one deliverable (scaffold / one domain type / one adapter / overlay). Phases ≤ 7 tasks.

**Sub-agent note:** 17 tasks > ~8. User ordered full implementation without pause — execute **inline** sequentially (no auto-spawn).
