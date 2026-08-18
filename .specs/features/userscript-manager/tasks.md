# UserScript Manager Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.**

---

**Design**: `.specs/features/userscript-manager/design.md`
**Status**: Approved

---

## Test Coverage Matrix

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------- | --------------------- | ----------------- | ------------ |
| Parser / catalog / importer (`popmundo_utils`) | unit (`dart test`) | 1:1 to USM ACs for parse/validate/persist | `packages/popmundo_utils/test/userscript_*_test.dart` | `cd packages/popmundo_utils && dart test` |
| Injector (`popmundo_webview`) | unit (`flutter test`) | Mapping + merge + never removeAll | `packages/popmundo_webview/test/userscript_*_test.dart` | `cd packages/popmundo_webview && flutter test` |
| UI screen / registry (`popmundo_app`) | widget + unit | Happy path + empty + dialogs + snackbar | `apps/popmundo_app/test/*userscript*` / registry | `cd apps/popmundo_app && flutter test` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | utils unit tasks | `cd packages/popmundo_utils && dart test` |
| Full | webview injector | `cd packages/popmundo_webview && flutter test` |
| Build | app UI / wiring | `cd apps/popmundo_app && flutter analyze ; cd apps/popmundo_app && flutter test` |

---

## Execution Plan

```
T1 (docs+AD) → T2 (parser) → T3 (catalog) → T4 (importer) → T5 (injector) → T6 (UI) → T7 (sidebar wire)
```

Single batch (7 tasks) — execute inline.

---

## Task Breakdown

### T1: Spec artifacts + AD-010

**What**: Write `spec.md`, `context.md`, `design.md`, `tasks.md`; append AD-010; update Handoff.
**Where**: `.specs/features/userscript-manager/*`, `.specs/STATE.md`
**Depends on**: None
**Requirement**: hygiene
**Done when**: Files exist; AD-010 documents catalog + groupName isolation; never removeAll
**Tests**: none
**Gate**: build (docs only — file presence)
**Commit**: `docs(userscript-manager): add spec design tasks and AD-010`

### T2: UserScriptParser

**What**: Parse UserScript metadata block; honor/reject matrix; wrap match/include/exclude.
**Where**: `packages/popmundo_utils/lib/src/userscript/`, export; tests + fixtures
**Depends on**: T1
**Requirement**: USM-03, USM-04, USM-14
**Done when**: Valid fixtures parse; unsupported headers throw with listed names; injectable source includes guards
**Tests**: unit
**Gate**: quick
**Commit**: `feat(userscript-manager): add UserScriptParser with header matrix`

### T3: UserScriptCatalog

**What**: Persist installed scripts on KeyValueStore; CRUD, toggle, dedup by sourceUrl.
**Where**: `packages/popmundo_utils/lib/src/userscript/`
**Depends on**: T2
**Requirement**: USM-06, USM-07, USM-08, USM-09
**Done when**: add/list/toggle/remove work; duplicate sourceUrl rejected; MemoryKeyValueStore tests pass
**Tests**: unit
**Gate**: quick
**Commit**: `feat(userscript-manager): add UserScriptCatalog persistence`

### T4: UserScriptImporter

**What**: URL validation, fetch, parse, @require concat, catalog write with rollback.
**Where**: `packages/popmundo_utils/lib/src/userscript/`
**Depends on**: T2, T3
**Requirement**: USM-02, USM-05, USM-06
**Done when**: Fake HTTP happy path installs; network/@require failure leaves catalog empty; bad URL rejected
**Tests**: unit
**Gate**: quick
**Commit**: `feat(userscript-manager): add UserScriptImporter with injected fetch`

### T5: UserScriptInjector + WebView merge

**What**: Map to InAppWebView UserScript; merge initialUserScripts; add/remove by groupName + reload; never removeAll.
**Where**: `packages/popmundo_webview/lib/src/`, `popmundo_webview_widget.dart`, runtime
**Depends on**: T3
**Requirement**: USM-11, USM-12, USM-13, USM-14
**Done when**: Mapping tests pass; merge includes enabled only; API surface does not call removeAllUserScripts
**Tests**: unit (flutter)
**Gate**: full
**Commit**: `feat(userscript-manager): inject catalog via UserScript groupName`

### T6: UserScriptsScreen UI

**What**: ListView, add dialog, switch, delete confirm, SnackBar; theme untouched.
**Where**: `apps/popmundo_app/lib/userscripts/`
**Depends on**: T4, T5
**Requirement**: USM-01, USM-02, USM-07, USM-08, USM-09, USM-10
**Done when**: Widget tests cover empty, add flow stubs, toggle, delete confirm/cancel
**Tests**: widget
**Gate**: build
**Commit**: `feat(userscript-manager): add UserScriptsScreen with Material list UI`

### T7: Sidebar item + composition wiring

**What**: Always-visible menu item; Navigator.push; wire catalog/importer/injector in app.
**Where**: `app_menu_registry.dart`, `app.dart`, registry tests
**Depends on**: T6
**Requirement**: USM-15
**Done when**: Registry returns userscripts item always; release still has item; analyze+tests pass
**Tests**: unit + widget regression
**Gate**: build
**Commit**: `feat(userscript-manager): wire sidebar entry and composition root`

---

## Requirement Traceability

| Requirement ID | Task | Status |
| -------------- | ---- | ------ |
| USM-01 | T6 | Pending |
| USM-02 | T4, T6 | Pending |
| USM-03 | T2 | Pending |
| USM-04 | T2 | Pending |
| USM-05 | T4 | Pending |
| USM-06 | T3, T4 | Pending |
| USM-07 | T3, T6 | Pending |
| USM-08 | T3, T6 | Pending |
| USM-09 | T3, T6 | Pending |
| USM-10 | T6 | Pending |
| USM-11 | T5 | Pending |
| USM-12 | T5 | Pending |
| USM-13 | T5 | Pending |
| USM-14 | T2, T5 | Pending |
| USM-15 | T7 | Pending |
