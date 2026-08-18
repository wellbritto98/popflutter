# UserScript Manager Validation

**Date**: 2026-08-17
**Spec**: `.specs/features/userscript-manager/spec.md`
**Diff range**: `f283e2e^..HEAD` (`f283e2e` … `05e8818`, includes fix commit `05e8818`)
**Verifier**: independent sub-agent (author ≠ verifier) — **re-verify** after prior FAIL

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| T1–T7 | ✅ Done | Feature commits through `46ade1f` |
| Fix 1–3 | ✅ Done | `05e8818` — empty body, `@inject-into`, import-busy UI tests |

---

## Prior Gap Closure (evidence-or-zero)

| Prior gap | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| Empty response body rejection | Reject as invalid; catalog unchanged | `packages/popmundo_utils/test/userscript_importer_test.dart:87-101` — `throwsA(... message contains('empty'))` + `expect(await catalog.list(), isEmpty)` | ✅ PASS |
| Import-in-progress disables add | Add action disabled while import runs | `apps/popmundo_app/test/userscripts_screen_test.dart:166-211` — during `Completer` gate: `expect(addButton.onPressed, isNull)`; after complete: `onPressed` `isNotNull` | ✅ PASS |
| `@inject-into` unsupported rejection | Reject + list unsupported header | `packages/popmundo_utils/test/userscript_parser_test.dart:168-194` — allow `page`; `throwsA(... unsupportedHeaders contains('@inject-into browser'))` | ✅ PASS |

---

## Spec-Anchored Acceptance Criteria

### P1: Importar UserScript por URL

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| USM-01 | Empty or list + add affordance | `userscripts_screen_test.dart:68-72` / `:76-83` | ✅ PASS |
| USM-02 | Persist enabled + SnackBar `@name` + apply/sync/reload | `userscript_importer_test.dart:44-49`; `userscripts_screen_test.dart:102-104`; `userscript_injector_test.dart:108-111` | ✅ PASS |
| USM-03 | Missing block/`@name` → reject, catalog empty | `userscript_parser_test.dart:56-85`; `userscript_importer_test.dart:104-112` | ✅ PASS |
| USM-04 | Unsupported headers listed + reject | `userscript_parser_test.dart:88-164` + `:168-194` (`@inject-into`) | ✅ PASS |
| USM-05 | Network/`@require` fail → zero writes + error UI | `userscript_importer_test.dart:78-84`, require abort; `userscripts_screen_test.dart:120-123` | ✅ PASS |
| USM-06 | Duplicate `sourceUrl` rejected | `userscript_catalog_test.dart:51-63`; `userscript_importer_test.dart` duplicate case | ✅ PASS |

### P1: Listar / toggle / delete

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| USM-07 | Name + Switch in list | `userscripts_screen_test.dart:76-83` | ✅ PASS |
| USM-08 | Toggle persist + sync/reload | catalog toggle tests + screen `:132-134` + injector sync | ✅ PASS |
| USM-09 | Delete confirm removes | `userscripts_screen_test.dart:150-161` | ✅ PASS |
| USM-10 | Delete cancel no-op | `userscripts_screen_test.dart:146-147` | ✅ PASS |

### P1: Injeção

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --------- | -------------------- | ----------------------- | ------ |
| USM-11 | merge builtins + enabled | `userscript_injector_test.dart:81-98` | ✅ PASS |
| USM-12 | `addUserScript` `userscript:<id>` + reload | `userscript_injector_test.dart:101-111` | ✅ PASS |
| USM-13 | remove by group; never `removeAllUserScripts` | `userscript_injector_test.dart:114-136` | ✅ PASS |
| USM-14 | runAt / noframes / PAGE mapping | parser + `userscript_injector_test.dart:59-78` | ✅ PASS |
| USM-15 | Sidebar userscripts always present | `app_menu_registry_test.dart:6-15`, `:55-61` | ✅ PASS |

**Status**: ✅ All ACs covered

---

## Discrimination Sensor

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 | `userscript_importer.dart` empty-body guard | Removed empty-body rejection | ✅ Killed — `empty response body leaves catalog empty` failed (no longer threw message containing `empty`) |
| 2 | `userscript_parser.dart` `@inject-into` loop | Forced `if (false)` so `@inject-into browser` accepted | ✅ Killed — `rejects unsupported @inject-into` returned `ParsedUserScript` |

**Sensor depth**: lightweight (2 mutations, focused on prior-gap code)
**Result**: 2/2 killed — PASS ✅  
**Scratch**: mutants discarded via `git checkout --` on mutated sources; feature lib tree clean afterward.

---

## Interactive UAT Results

| # | Test | Result | Details |
| - | ---- | ------ | ------- |
| — | Interactive UAT | ⏭️ Skip | Automated re-verify only; device UAT optional for orchestrator/user |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ (fix commit is tests-only) |
| No scope creep | ✅ |
| Matches patterns | ✅ |
| Spec-anchored outcome check | ✅ |
| Per-layer Coverage Expectation met | ✅ |
| Every test maps to AC / edge / Done-when | ✅ |
| Documented guidelines followed | ✅ `CLAUDE.md` / coding-principles |

---

## Edge Cases

- [x] Non-`http(s)` / path not `.user.js` — `userscript_importer_test.dart`
- [x] Empty response body — `userscript_importer_test.dart:87-101`
- [x] `@match`/`@include`/`@exclude` guards — `userscript_parser_test.dart`
- [x] Multiple `@require`; failure aborts — `userscript_importer_test.dart`
- [x] Import in progress disables add — `userscripts_screen_test.dart:166-211`
- [x] Empty catalog copy — `userscripts_screen_test.dart:66-72`

---

## Gate Check

| Command | Result |
| ------- | ------ |
| `cd packages/popmundo_utils && dart test` | **67** passed, 0 failed |
| `cd packages/popmundo_webview && flutter test` | **11** passed, 0 failed |
| `cd apps/popmundo_app && flutter analyze` | exit 0; **1 info** (`unnecessary_brace_in_string_interps` at `userscripts_screen_test.dart:171`) — not treated as gate failure |
| `cd apps/popmundo_app && flutter test` | **30** passed, 0 failed |

- **Test count before feature** (`f283e2e^`): utils 10 / webview 1 / app 5 test files
- **After (incl. fix)**: utils 13 / webview 2 / app 6 files; assertion counts ↑ (67 / 11 / 30)
- **Delta vs prior FAIL report**: utils 65→67, app 29→30 (+ empty body, `@inject-into`, import-busy)
- **Skipped**: none
- **Failures**: none

---

## Fix Plans

None — prior Fix 1–3 verified closed.

---

## Requirement Traceability Update

| Requirement | Previous (FAIL report) | New Status |
| ----------- | ---------------------- | ---------- |
| USM-01..USM-15 | ✅ Verified (with edge gaps) | ✅ Verified |
| Edge: empty body | ❌ untested | ✅ Verified |
| Edge: import-busy | ❌ untested | ✅ Verified |
| Matrix: `@inject-into` | ❌ untested | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 15/15 ACs matched | listed edges covered | 0 open gaps  
**Sensor**: 2/2 mutations killed  
**Gate**: 67 + 11 + 30 passed; analyze exit 0 (1 non-blocking info in test)

**What works**: Full MVP path (import/list/toggle/delete/inject) plus previously missing empty-body, import-busy, and `@inject-into` discrimination.

**Issues found**: None blocking. Optional: clean `unnecessary_brace_in_string_interps` info in `userscripts_screen_test.dart:171` (style only).

**Next steps**: Feature validation complete; optional interactive device UAT; no further fix→re-verify iteration required.
