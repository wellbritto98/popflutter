# Popmundo Wrapper Validation

**Date**: 2026-08-17
**Spec**: `.specs/features/popmundo-wrapper/spec.md`
**Diff range**: working tree (initial implementation)
**Verifier**: independent spec-anchored pass + discrimination sensor (mutations restored)

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | Done | Melos workspace, GPL-3 LICENSE, NOTICE |
| T2 | Done | HostTracker unit tests |
| T3 | Done | ObservePolicy unit tests |
| T4 | Done | Events + BodyCapture |
| T5 | Done | FakePopmundoRuntime |
| T6 | Done | Logger ring buffer 200 |
| T7 | Done | StorageService / MemoryKeyValueStore |
| T8 | Done | TimedFetch delay, cache, serialize |
| T9 | Done | Utils getMyID/getMyName/getServerLink |
| T10 | Done | Notifications + GetPageNotifications |
| T11 | Done | CssSelector + Scoring.autoApplyOnLoad false |
| T12 | Done | hooks.js / helpers.js assets |
| T13 | Done | PopmundoWebView + InAppPopmundoRuntime |
| T14 | Done | INTERNET + ATS subdomains |
| T15 | Done | App composition + SharedPreferencesStore |
| T16 | Done | Debug overlay widget tests |
| T17 | Done | README + barrel exports |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| App starts → load www.popmundo.com | `https://www.popmundo.com` | `packages/popmundo_webview/test/popmundo_webview_test.dart:97` — `expect(HostTracker.defaultOrigin, 'https://www.popmundo.com')` | PASS |
| Redirect to `*.popmundo.com` updates origin | host `73.popmundo.com` | `packages/popmundo_utils/test/host_tracker_test.dart:13` — `expect(host.currentOrigin.host, '73.popmundo.com')` | PASS |
| Helpers use current host not hardcoded www | resolve uses 73 | `packages/popmundo_utils/test/host_tracker_test.dart:14` — `expect(..., 'https://73.popmundo.com/...')` | PASS |
| External host does not replace session origin | origin stays www | `packages/popmundo_utils/test/host_tracker_test.dart:21` — `expect(..., 'www.popmundo.com')` | PASS |
| External links → OS browser (policy) | `NavDecision.openExternal` | `packages/popmundo_utils/test/observe_policy_test.dart:13` — `expect(..., NavDecision.openExternal)` | PASS |
| WebView non-incognito | `incognito == false` | `packages/popmundo_webview/test/popmundo_webview_test.dart:38` — `expect(settings.incognito, isFalse)` | PASS |
| Process kill keeps same cookie store | OS WebView cookie jar | Setting `incognito: false` only; no relaunch e2e | Spec-precision gap |
| Overlay hides cookie values | name@domain, no value | `apps/popmundo_app/test/debug_overlay_test.dart:44-45` — `expect(find.text('session@popmundo.com')...)` / `secret-value` nothing | PASS |
| fetch/XHR emit NetworkEvent | method/url/status | `packages/popmundo_webview/test/popmundo_webview_test.dart:91` — `expect(networks.single.method, 'POST')` | PASS |
| console emit ConsoleEvent | level + message | `packages/popmundo_webview/test/popmundo_webview_test.dart:93` — `expect(consoles.single.message, 'boom')` | PASS |
| navigation emit NavigationEvent | url | `packages/popmundo_utils/test/events_test.dart:21` — `expect(navs.single.url, 'https://www.popmundo.com/')` | PASS |
| observe-only never replaces response | `null` | `packages/popmundo_utils/test/observe_policy_test.dart:20` — `expect(..., isNull)` | PASS |
| body > 32768 truncated | truncated true | `packages/popmundo_utils/test/events_test.dart:28` — `expect(result.truncated, isTrue)` | PASS |
| binary body omitted | omitted true, body null | `packages/popmundo_utils/test/events_test.dart:35-36` | PASS |
| TimedFetch serialize | maxInFlight == 1 | `packages/popmundo_utils/test/timed_fetch_test.dart:30` — `expect(maxInFlight, 1)` | PASS |
| TimedFetch delay >= 750ms | duration >= 750ms | `packages/popmundo_utils/test/timed_fetch_test.dart:49` | PASS |
| TimedFetch cache METHOD:URL | fetchCalls.length == 1 | `packages/popmundo_utils/test/timed_fetch_test.dart:61` | PASS |
| useCache false hits network | fetchCalls.length == 2 | `packages/popmundo_utils/test/timed_fetch_test.dart:73` | PASS |
| non-2xx error, not cached | TimedFetchException then second fetch | `packages/popmundo_utils/test/timed_fetch_test.dart:86-87` | PASS |
| relative path uses sticky host | 84.popmundo.com, not www | `packages/popmundo_utils/test/timed_fetch_test.dart:99-101` | PASS |
| getMyID integer | 42 | `packages/popmundo_utils/test/utils_test.dart:10` | PASS |
| getMyID missing/non-numeric | 0 | `packages/popmundo_utils/test/utils_test.dart:16-18` | PASS |
| getMyName missing | `''` | `packages/popmundo_utils/test/utils_test.dart:24` | PASS |
| unknown notification level | ArgumentError | `packages/popmundo_utils/test/notifications_test.dart:18` | PASS |
| missing #notifications | null, no throw | `packages/popmundo_utils/test/notifications_test.dart:29` | PASS |
| getPageNotifications POST no cache | success/Welcome, POST, current host | `packages/popmundo_utils/test/notifications_test.dart:50-58` | PASS |
| CssSelector serialized maps | id `x` | `packages/popmundo_utils/test/css_scoring_test.dart:20` | PASS |
| Storage persist in process | `{'n': 1}` | `packages/popmundo_utils/test/storage_test.dart:42` | PASS |
| toggleExclusion add/remove | `[99]` then empty | `packages/popmundo_utils/test/storage_test.dart:28,36` | PASS |
| normalizeExcludeMap null/list | `{}` | `packages/popmundo_utils/test/storage_test.dart:6-7` | PASS |
| excludeEntryId object/plain/garbage | 7 / 7 / null | `packages/popmundo_utils/test/storage_test.dart:12-15` | PASS |
| Overlay collapsed no panel | panel findsNothing | `apps/popmundo_app/test/debug_overlay_test.dart:20` | PASS |
| Overlay shows host/events | 73.popmundo.com, GET, console | `apps/popmundo_app/test/debug_overlay_test.dart:43,50,51` | PASS |
| Overlay eval | `result:1+1` | `apps/popmundo_app/test/debug_overlay_test.dart:57` | PASS |
| Overlay clear | GET/console gone | `apps/popmundo_app/test/debug_overlay_test.dart:61-62` | PASS |
| Scoring not auto on load | `autoApplyOnLoad == false` + helpers.js no `applyScoringNumbers();` | `css_scoring_test.dart:25`, `popmundo_webview_test.dart:58` | PASS |
| Scoring API invokes evaluate | evaluateCalls contains applyScoringNumbers | `packages/popmundo_utils/test/css_scoring_test.dart:29` | PASS |
| Logger capacity 200 | length 200, oldest dropped | `packages/popmundo_utils/test/logger_test.dart:10-12` | PASS |

**Status**: All ACs covered except one spec-precision gap (cookie relaunch e2e)

---

## Discrimination Sensor

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 | `packages/popmundo_utils/lib/src/host_tracker.dart:11` | `isPopmundoHost` always `true` | Killed (`observe_policy_test` expected openExternal) |
| 2 | `packages/popmundo_utils/lib/src/timed_fetch.dart` cache branch | disabled cache hit | Killed (`fetchCalls.length` expected 1 got 2) |
| 3 | `packages/popmundo_utils/lib/src/scoring.dart` | `autoApplyOnLoad = true` | Killed (`expect(..., isFalse)`) |

Mutations discarded (source restored). Scratch only.

**Sensor depth**: lightweight (3 targeted)
**Result**: 3/3 killed — PASS

---

## Interactive UAT Results (if performed)

| # | Test | Result | Details |
| - | ---- | ------ | ------- |
| 1 | Live load of www.popmundo.com on device | Skip | Requires device/emulator + game account; not run in CI |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | PASS |
| Surgical changes | PASS (greenfield) |
| No scope creep | PASS (no mass-interact) |
| Matches patterns | PASS (new repo) |
| Spec-anchored outcome check | PASS with 1 precision gap |
| Per-layer Coverage Expectation met | PASS for domain; adapter tested via assets/settings/bridge |
| Every test maps to a spec requirement | PASS |
| Documented guidelines followed | none — strong defaults applied |

---

## Edge Cases

- [x] External host does not update sticky origin
- [x] Non-numeric idHolder → 0
- [x] Unknown notification level errors
- [x] Missing notification container does not throw
- [x] TimedFetch overlapping calls serialize
- [x] TimedFetch relative URL after host change
- [x] Body truncation 32 KiB
- [ ] WebView onReceivedError reload UX — empty callback, no crash; not widget-tested
- [ ] `waitUntilReady` 30s timeout path — implemented in `InAppPopmundoRuntime`; Fake tests immediate not-ready error only

---

## Gate Check

- **Gate command**: `dart analyze` (workspace) + `dart test` (utils) + `flutter test` (webview, app)
- **Result**: analyze 0 issues; utils 37 passed; webview 5 passed; app 4 passed; 0 failed; 0 skipped
- **Test count before feature**: 0
- **Test count after feature**: 46
- **Delta**: +46
- **Skipped tests**: none
- **Failures**: none

---

## Fix Plans (if issues found)

None required for PASS. Optional follow-up: device UAT for cookie persistence across process kill.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| WRAP-01 | Pending | Verified |
| HOST-01..03 | Pending | Verified |
| SESS-01 | Pending | Verified (setting) / precision gap (relaunch e2e) |
| SESS-02 | Pending | Verified |
| INT-01..05 | Pending | Verified |
| UTIL-01..09 | Pending | Verified |
| STOR-01..03 | Pending | Verified |
| DBG-01..04 | Pending | Verified |
| SCORE-01..02 | Pending | Verified |
| LOG-01 | Pending | Verified |

---

## Summary

MVP wrapper is in place: utils domain is well-tested against FakeRuntime; WebView adapter is observe-only with JS hooks; app overlay covers debug ACs. One spec-precision gap remains on real cookie relaunch, which cannot be proven in unit tests.
