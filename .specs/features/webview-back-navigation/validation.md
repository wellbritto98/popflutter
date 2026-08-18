# webview-back-navigation Validation

**Date**: 2026-08-18
**Spec**: `.specs/features/webview-back-navigation/spec.md`
**Diff range**: uncommitted working tree vs `HEAD` (no feature commit yet)
**Feature surface**: `packages/popmundo_webview/lib/src/webview_back_navigation.dart`, `packages/popmundo_webview/lib/src/popmundo_webview_widget.dart` (PopScope + history sync), `packages/popmundo_webview/lib/popmundo_webview.dart` (export), `packages/popmundo_webview/test/webview_back_navigation_test.dart`, `.specs/features/webview-back-navigation/spec.md`
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| —    | ✅ N/A  | No `tasks.md` (Small scope). Execute surface present: handler + PopScope wrap + unit tests. |

---

## Spec-Anchored Acceptance Criteria

### P1: System back follows WebView history

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| WHEN system back AND WebView can go back THEN call `goBack` and SHALL NOT pop the Flutter home route | `goBack` invoked; decision is stay-in-WebView (`navigateBack`), not exit | `packages/popmundo_webview/test/webview_back_navigation_test.dart:35` — `expect(decision, SystemBackDecision.navigateBack)`; `:36` — `expect(port.goBackCalls, 1)` | ✅ PASS |
| WHEN system back AND WebView cannot go back THEN allow the Flutter route to pop (app exits on root) | decision is `allowExit`; `goBack` not invoked | `webview_back_navigation_test.dart:44` — `expect(decision, SystemBackDecision.allowExit)`; `:45` — `expect(port.goBackCalls, 0)` | ✅ PASS |
| WHEN system back AND WebView is not attached THEN allow the route to pop | `handle(null)` → `allowExit` | `webview_back_navigation_test.dart:49-51` — `WebViewBackHandler.handle(null)` then `expect(decision, SystemBackDecision.allowExit)` | ✅ PASS |
| WHEN WebView has history THEN `PopScope.canPop` SHALL be `false` | `allowRoutePop(webViewCanGoBack: true) == false` | `webview_back_navigation_test.dart:55` — `expect(WebViewBackHandler.allowRoutePop(webViewCanGoBack: true), isFalse)`; wiring `:64-66` — source contains `PopScope`, `allowRoutePop`, `handle` | ✅ PASS |
| WHEN WebView has no history THEN `PopScope.canPop` SHALL be `true` | `allowRoutePop(webViewCanGoBack: false) == true` | `webview_back_navigation_test.dart:56` — `expect(WebViewBackHandler.allowRoutePop(webViewCanGoBack: false), isTrue)` | ✅ PASS |

**Status**: ✅ All ACs covered — asserted values match spec-defined outcomes (Independent Test: fake history port + boolean `canPop` mapping)

---

## Discrimination Sensor

Scratch: copy of `webview_back_navigation.dart` to `%TEMP%`; mutate package source; run `flutter test test/webview_back_navigation_test.dart`; restore from copy. SHA256 after restore matched original `C278FEF82B380ED5CD0C9CE11BD38A55ECEFA08270B1F7F10935B7B3D3B706DA`. Temp backup deleted.

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 | `webview_back_navigation.dart:25` | Flipped `allowRoutePop`: `!webViewCanGoBack` → `webViewCanGoBack` | ✅ Killed — `route may pop only when the WebView has no history` (`webview_back_navigation_test.dart:55` Expected `false` Actual `true`) |
| 2 | `webview_back_navigation.dart:31` | Returned `allowExit` when `canGoBack` is true (still called `goBack`) | ✅ Killed — `system back with history…` (`:35` Expected `navigateBack` Actual `allowExit`) |
| 3 | `webview_back_navigation.dart:30` | Skipped `goBack()` call; still returned `navigateBack` | ✅ Killed — `system back with history…` (`:36` Expected `1` Actual `0`) |

**Sensor depth**: lightweight (3 behavior-level mutations)
**Result**: 3/3 killed — PASS ✅

---

## Interactive UAT Results (if performed)

| # | Test | Result | Details |
| - | ---- | ------ | ------- |
| — | Device back / swipe | ⏭️ Skip | Automated verifier; device UAT is the next product step (navigate in-game, press/swipe back). Not executed here. |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ Feature-specific: handler + `PopScope` + history sync. Adjacent `gmValueStore` / `refreshGmSnapshots` edits in the same widget file are other uncommitted work, not this feature. |
| No scope creep | ✅ No forward nav, no confirm-before-exit, overlay unused (matches Out of Scope) |
| Matches patterns | ✅ Narrow port + Dart facade; observe-only WebView callbacks unchanged |
| Spec-anchored outcome check (asserted values match spec) | ✅ |
| Per-layer Coverage Expectation met (domain 1:1 ACs; routes happy+edge+error) | ✅ Domain handler 1:1 with ACs; no HTTP routes in scope |
| Every test maps to a spec requirement — no unclaimed tests | ✅ Five tests → AC1+edge, AC2+edge, AC3, AC4+AC5, PopScope wiring |
| Documented guidelines followed: `.claude/skills/tlc-spec-driven/references/coding-principles.md`; spec Independent Test | ✅ |

---

## Edge Cases

- [x] WHEN `canGoBack` is true THEN `goBack` SHALL be invoked exactly once per system-back event — `webview_back_navigation_test.dart:36` `expect(port.goBackCalls, 1)`
- [x] WHEN `canGoBack` is false THEN `goBack` SHALL NOT be invoked — `webview_back_navigation_test.dart:45` `expect(port.goBackCalls, 0)`

---

## Gate Check

- **Gate command**: `cd packages/popmundo_webview && flutter test` then `flutter analyze`
- **Result**: 21 passed, 0 failed, 0 skipped (`flutter test`); `flutter analyze` — No issues found
- **Test count before feature**: 11 on `HEAD` (`popmundo_webview_test.dart` 5 + `userscript_injector_test.dart` 6)
- **Test count after feature**: 21 in current working tree
- **Delta**: +10 vs `HEAD` of which **+5** are this feature (`webview_back_navigation_test.dart`); remaining +5 are other uncommitted userscript/GM work in the same package. Feature tests did not decrease or weaken existing assertions.
- **Skipped tests**: none
- **Failures**: none

---

## Fix Plans (if issues found)

None.

---

## Requirement Traceability Update

Statuses proposed by verifier (spec.md left unchanged — report-only):

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| BACK-01 | Pending | ✅ Verified |
| BACK-02 | Pending | ✅ Verified |
| BACK-03 | Pending | ✅ Verified |
| BACK-04 | Pending | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 5/5 ACs matched spec outcome | 0 spec-precision gaps
**Sensor**: 3/3 mutations killed
**Gate**: 21 passed, 0 failed (`flutter analyze` clean)

**What works**: System back with history calls `goBack` once and returns `navigateBack`; empty/detached history returns `allowExit` without `goBack`; `allowRoutePop` is false iff the WebView can go back; `PopmundoWebView` wraps the WebView in `PopScope` wired to the handler.

**Issues found**: none

**Next steps**: Device UAT (back with in-game history stays in app; first page still exits). Commit when requested.
