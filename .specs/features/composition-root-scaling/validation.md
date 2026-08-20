# Composition Root Scaling Validation

**Date**: 2026-08-20
**Spec**: `.specs/features/composition-root-scaling/spec.md`
**Diff range**: `4ec5f50..HEAD` (9 commits: `1ebf55b`, `9fc711f`, `79afb10`, `0449965`, `bcffa2d`,
`25d3e89`, `ee5c55a`, `891b9db`, `e66dade`)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Verdict: ❌ FAIL (narrow — 2 surviving mutants; all 18 CRS otherwise evidenced, all gates green)

The structural work is solid: every one of CRS-01…18 traces to real `file:line` evidence, all
seven gate commands are green, and 3 of 5 assigned discrimination mutants (plus one extra used to
independently re-verify a pre-existing-bugfix claim) were killed cleanly. But the discrimination
sensor is not a formality here — two of the five assigned mutations **survived**, both clustered on
the exact behavior CRS-11 exists to protect (safe disposal while an async operation is still in
flight). Per this skill's own rule ("surviving mutants are fix tasks — do not mark the feature done
if the sensor found weak tests"), that is a FAIL, not a PASS with a footnote. Both gaps are small
and mechanical to close (see Fix Plans).

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 (`PopmundoScope` deletion) | ✅ Done | `grep -rn PopmundoScope --include=*.dart .` → empty |
| T2 (`notifications/README.md`) | ✅ Done | File exists, house style followed |
| T3 (`lib/src` → `core/`+`facades/`) | ✅ Done | Zero loose files; barrel paths rewritten; `show` clauses preserved |
| T4 (menu registry + 4 item files + test redistribution) | ✅ Done | Signature is generic; 8 old assertions → 16 new (relocated, none dropped) |
| T5 (`AppWiring`+`CookieWatcher`, unwired) | ✅ Done, but see Sensor gap 2 | `CookieWatcher` has **zero** dedicated test file |
| T6 (rewire `main.dart`/`app.dart`) | ✅ Done | `app.dart` = 216 LOC (CRS-03 target missed, disclosed) |
| T7 (`app_wiring_test.dart`) | ✅ Done, but see Sensor gap 1 | CRS-11's "dispose while pending" test does not kill the `_disposed`-guard-removal mutant |
| T8 (doc sync + AD-020) | ✅ Done | Landed as `d4ccd21`/`e905314` during this pass — see "Out-of-scope observation" below |

---

## Spec-Anchored Acceptance Criteria

| # | Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| - | -------------------------- | --------------------- | ------------------------ | ------ |
| CRS-01 | `_PopmundoHomeState` constructs zero collaborators | Every collaborator is a field of `AppWiring`; State only reads `_wiring.X` | `apps/popmundo_app/lib/app.dart:60-216` (no `= XController(` construction inside the State); confirmed via `grep -nE '^\s*(late\s+final|final)\s+\w+\s*=\s*\w+\(' lib/app.dart` → empty | ✅ PASS |
| CRS-02 | New sidebar entry ⇒ `buildAppMenuItems` signature unchanged, item defined in its own folder | Generic `{items, debugItem, includeDebugItem}` signature; each feature owns an `AppMenuItem` builder | `apps/popmundo_app/lib/menu/app_menu_registry.dart:12-19` (signature); `apps/popmundo_app/lib/autologin/auto_login_menu_item.dart:8-14` (own-folder builder); ordering proven by `apps/popmundo_app/test/app_menu_registry_test.dart:19-26` — `expect(items.map((e) => e.id), ['a','b','c'])` | ✅ PASS |
| CRS-03 | `app.dart` ≤ 180 lines | 216 measured, target missed | `wc -l apps/popmundo_app/lib/app.dart` → **216** (independently re-measured, matches disclosed 216) | ❌ **MISSED** (disclosed, confirmed) |
| CRS-04 | `AppWiring` references no `BuildContext`/`State`/`Navigator`/widget type | Zero real references (doc comments only) | `grep -nE 'BuildContext\|State<\|Navigator\|Widget ' apps/popmundo_app/lib/app_wiring.dart` → 2 hits, both inside `///` doc comments (lines 48, 89), zero in code | ✅ PASS |
| CRS-05 | Debug item order structurally guaranteed; caller order preserved; concrete prod order `auto-login, userscripts, language` untested | Order/gating tested against stubs; no test pumps `_PopmundoHomeState` or imports 2+ menu-item builders together | `apps/popmundo_app/test/app_menu_registry_test.dart:19-37` (order+gate, stubs only); independently confirmed **no** test file imports `autoLoginMenuItem`+`userscriptsMenuItem`+`languageMenuItem` together and no test constructs `PopmundoHome` (`grep -rn "PopmundoHome(" apps/popmundo_app/test/` → empty) | ⚠️ **Partial** (disclosed, confirmed accurate) |
| CRS-06 | `includeDebugItem` omitted ⇒ defaults to `kDebugMode` | `expect(items.any((e) => e.id == 'debug'), kDebugMode)` | `apps/popmundo_app/test/app_menu_registry_test.dart:55-63` | ✅ PASS |
| CRS-07 | PT locale ⇒ live `.tr()` lookups, not hardcoded | Labels resolve via `EasyLocalization` catalog under `pt` | `apps/popmundo_app/test/auto_login_menu_item_test.dart:29-37` (`'Login automático'`), `apps/popmundo_app/test/language_menu_item_test.dart:28-36` (`'Idioma'`); structurally all 4 builders use `.tr()` (`userscripts_menu_item.dart:10-11`, `debug_menu_item.dart:12-13`) — PT-specific test exists for 2/4 items, identical to pre-refactor coverage (old `app_menu_registry_test.dart` at `4ec5f50` also only PT-tested auto-login+language) | ✅ PASS (no regression vs. baseline) |
| CRS-08 | Full suite green, zero leaf-widget test files modified | Suite green; `app_shell_test.dart`, `app_sidebar_test.dart`, `debug_overlay_test.dart`, `language_selector_test.dart`, `auto_login_screen_test.dart`, `background_status_test.dart`, `background_keepalive_test.dart`, `userscripts_screen_test.dart`, `notifications/*` untouched | `git diff 9fc711f..HEAD --stat -- apps/popmundo_app/test/` → only `app_menu_registry_test.dart`, `app_wiring_test.dart`, 4 new `*_menu_item_test.dart` files (none of the 9 named files) | ✅ PASS — **caveat**: the raw range `4ec5f50..HEAD` (as given) *does* show `notifications/menu_notifications_bridge_test.dart` changed, but only in commit `1ebf55b`, which predates the feature's own spec commit `9fc711f` and fixes a pre-existing compile break unrelated to CRS scope (see "Pre-existing fix" section below) |
| CRS-09 | `CookieManager` unavailable / `syncUserScripts` throws ⇒ swallowed exactly as before | Same 2 swallow points as pre-refactor `app.dart` | `apps/popmundo_app/lib/cookie_watcher.dart:38` (`catch (_)`), `apps/popmundo_app/lib/app_wiring.dart:219` (`on PopmundoRuntimeException`); parity confirmed against `git show 4ec5f50:.../app.dart` lines 256/268 (same 2 swallow points, no more no fewer); test: `apps/popmundo_app/test/app_wiring_test.dart:100-116` — `expectLater(wiring.applyUserScripts(...), completes)` | ✅ PASS |
| CRS-10 | `start()` called twice ⇒ no duplicate subscriptions | `bool _started` guard | `apps/popmundo_app/lib/app_wiring.dart:153-154` (`if (_started \|\| _disposed) return;`); test: `apps/popmundo_app/test/app_wiring_test.dart:118-146` — after double `start()` + `dispose()`, a navigation event must not re-clear the registry: `expect(wiring.gmMenuRegistry.commands, hasLength(1))` | ✅ PASS |
| CRS-11 | `dispose()` while a `start()`-initiated async op is pending ⇒ completes without throwing, no active subscription left | No throw; all subs cancelled | `apps/popmundo_app/test/app_wiring_test.dart:178-187` — `expectLater(wiring.dispose(), completes)` | ⚠️ **Spec-precision / discrimination gap** — test passes today, but the sensor shows it does not actually exercise the race the `_disposed` guard in `_publish` (`app_wiring.dart:225-234`) exists to prevent (see Sensor mutation 3) |
| CRS-12 | `applyUserScripts(next)` ⇒ `previouslyEnabledIds` = exactly the enabled ids of `next` | Exact set equality | `apps/popmundo_app/test/app_wiring_test.dart:77-94` — `expect(wiring.userscripts.value.previouslyEnabledIds, {'a', 'c'})` then `{'c'}` after a second call | ✅ PASS |
| CRS-13 | `localization_boot_test.dart`'s source-text scan of `app.dart`/`main.dart` still finds every asserted substring | All 4 substrings present | `apps/popmundo_app/test/localization_boot_test.dart:55-70` — `expect(source.contains('localizationsDelegates: context.localizationDelegates'), isTrue)` etc., run and passing against the moved `PopmundoApp.build` in `apps/popmundo_app/lib/app.dart:36-45` | ✅ PASS |
| CRS-14 | `app_wiring_test.dart` covers bootstrap, diffing, dispose-cancel-all, `connectHeadersFor` | `FakePopmundoRuntime`+`MemoryKeyValueStore`-based tests | `apps/popmundo_app/test/app_wiring_test.dart:44-67` (bootstrap), `:69-98` (diffing), `:170-187` (dispose), `:189-222` (`connectHeadersFor`, incl. unknown-id → `const []` at `:215-219`) | ✅ PASS |
| CRS-15 | `lib/src` contains only directories | Zero loose `.dart` files | `find packages/popmundo_utils/lib/src -maxdepth 1 -type f` → empty; `find ... -maxdepth 1` → 5 dirs only (`core`, `facades`, `autologin`, `menu_notifications`, `userscript`) | ✅ PASS |
| CRS-16 | Barrel exported symbol set identical; no consumer import change | Only export **paths** change | `git diff 4ec5f50..HEAD -- packages/popmundo_utils/lib/popmundo_utils.dart` — 12 lines changed, all `src/X.dart` → `src/{core,facades}/X.dart`, zero export lines added/removed; `grep -rn "package:popmundo_utils/src" apps/popmundo_app packages/popmundo_webview` → empty; `grep -rln "^part " packages/popmundo_utils/lib` → empty; `flutter analyze` clean on all 3 packages | ✅ PASS |
| CRS-17 | `app.dart` search for `PopmundoScope` ⇒ no match anywhere in repo | Zero matches | `grep -rn "PopmundoScope" --include="*.dart" .` → empty (code-level intent fully met) | ⚠️ **Spec-precision gap** — literal AC text ("no match anywhere in the repo") is not met if read maximally strictly: `.specs/features/app-sidebar-menu/{design,tasks,validation}.md` (historical records, explicitly exempted by this feature's own `design.md` §2) and this feature's own `spec.md`/`design.md`/`tasks.md` (which necessarily discuss the deletion) still mention the name. Not a functional gap — the code-level check the AC is actually testing (`grep --include=*.dart`) is clean |
| CRS-18 | Every feature folder under `lib/` has a `README.md` | 1:1 | `ls apps/popmundo_app/lib/*/README.md` → `autologin/`, `background/`, `gm/`, `language/`, `menu/`, `notifications/`, `userscripts/` all present | ✅ PASS |

**Status**: 15/18 clean PASS, 1 disclosed MISSED (CRS-03, confirmed), 1 disclosed Partial (CRS-05,
confirmed), 1 new spec-precision gap surfaced by this pass (CRS-17, cosmetic/wording only — not a
functional gap). CRS-11 is nominally "Implemented" per traceability but carries a discrimination
gap surfaced by the sensor (see below) — kept as PASS in this table because the AC's literal text
("completes without throwing") is true today; the gap is that the *test* doesn't prove it robustly,
which is why it is called out separately in the Sensor and Fix Plans sections rather than flipping
this row to a GAP.

---

## Discrimination Sensor

All mutations applied to the real working tree in sequence, one at a time, then reverted with
`git checkout --` before the next; `git status --short -- lib/` confirmed clean before, between,
and after every mutation. No mutation was left in place.

| # | File:line | Description | Killed? |
| - | --------- | ------------ | ------- |
| 1 | `apps/popmundo_app/lib/menu/app_menu_registry.dart:16-19` | `debugItem` appended **first** instead of last | ✅ Killed — `app_menu_registry_test.dart` ("appends the debug item last...") fails: `Actual: ['debug', 'a', 'b', 'c']` |
| 2 | `apps/popmundo_app/lib/app_wiring.dart:239-244` | `connectHeadersFor` made to always `return const []` | ✅ Killed — `app_wiring_test.dart` ("connectHeadersFor returns...") fails: `Actual: []` vs `Expected: ['api.example.test', 'cdn.example.test']` |
| 3 | `apps/popmundo_app/lib/app_wiring.dart:226` | Removed the `if (_disposed) return;` guard in `_publish` | ❌ **Survived** — full `flutter test test/app_wiring_test.dart` still passes (8/8). The "dispose() while the catalog read is still in flight does not throw" test does not actually catch this: `MemoryKeyValueStore.get`/`UserScriptCatalog.list()` resolve within fewer microtask turns than `AppWiring.dispose()` takes to reach its own `userscripts.dispose()` call, so `_publish`'s write lands *before* the notifier is disposed regardless of the guard — no exception is ever provoked, guarded or not |
| 4 | `apps/popmundo_app/lib/cookie_watcher.dart:31-33` | Removed the post-await `if (_disposed) return;` in `refresh()` | ❌ **Survived** — full `flutter test` (111/111) still passes, because **no test file exercises `CookieWatcher` at all** (`find apps/popmundo_app/test -iname "*cookie_watcher*"` → empty; `grep -rln "CookieWatcher" apps/popmundo_app/test/` → empty) |
| 5 | `apps/popmundo_app/lib/autologin/auto_login_menu_item.dart:9` | Changed `id: 'auto-login'` → `id: 'auto-login-CHANGED'` | ✅ Killed — `auto_login_menu_item_test.dart` ("exposes the auto-login id...") fails |
| 6 (extra, verifying an author-disclosed claim) | `apps/popmundo_app/lib/notifications/menu_notifications_bridge.dart:53-54` | Moved `utils.getMyName()` from once-per-batch to inside the per-item loop | ✅ Killed — `menu_notifications_bridge_test.dart` ("getMyName() is resolved once per batch...") fails: `Actual: <3>` vs `Expected: <1>`. Independently confirms the author's disclosed claim about `_CountingUtils` in commit `1ebf55b` |

**Sensor depth**: lightweight (5 assigned + 1 verification mutation)
**Result**: 4/6 killed, **2/6 survived** — ❌ FAIL on the sensor gate

Both survivors point at the same class of gap: **dispose-time / async-race safety in the new
non-widget collaborators is under-tested.** `AppWiring._publish`'s guard is exercised by a test that
doesn't actually create the race it claims to (CRS-11), and `CookieWatcher` — a new class introduced
specifically so this exact coupling has "a single place to look" (per its own doc comment) — has no
test file whatsoever.

---

## Necessity Check (test → CRS mapping)

Every changed/added test in scope maps to a CRS requirement; no unclaimed test found:

| Test file | Maps to |
| --- | --- |
| `app_menu_registry_test.dart` (rewritten) | CRS-02, CRS-05, CRS-06 |
| `app_wiring_test.dart` (new) | CRS-09, CRS-10, CRS-11, CRS-12, CRS-14 |
| `auto_login_menu_item_test.dart` (new) | CRS-02, CRS-05, CRS-07 |
| `debug_menu_item_test.dart` (new) | CRS-02, CRS-05, CRS-06 |
| `language_menu_item_test.dart` (new) | CRS-02, CRS-05, CRS-07 |
| `userscripts_menu_item_test.dart` (new) | CRS-02, CRS-05 |
| `notifications/menu_notifications_bridge_test.dart` (changed in `1ebf55b`) | **Not this feature** — pre-existing compile-break fix, see below. Independently verified: `git show 4ec5f50:packages/popmundo_utils/lib/src/utils.dart` shows `Utils(this.runtime, this.timedFetch)` (2 required args) while `git show 4ec5f50:apps/popmundo_app/test/notifications/menu_notifications_bridge_test.dart` calls `Utils(runtime)` (1 arg) — `apps/popmundo_app` genuinely did not compile at `4ec5f50`, confirming the commit message's claim independently |

No test in scope maps to nothing. Test-count delta: `app_menu_registry_test.dart` went from 8
cases (`4ec5f50`) to 6, with the other 10 (16 total minus 6) distributed into the 4 new
`*_menu_item_test.dart` files (3+2+3+2=10) — **8 → 16, zero deleted**, matching Task 4's "none
deleted" claim.

One file worth flagging even though it needs no fix: `apps/popmundo_app/lib/autologin/auto_login_status_snackbar.dart`
(new, 34 lines) is not named anywhere in `design.md` or `tasks.md`'s task table. It is a reasonable
extraction of logic that was inline in the old `_onAutoLoginStatus` (`git show 4ec5f50:.../app.dart`
lines ~307-321) into the auto-login feature's own folder — consistent with the feature's spirit —
but it has zero direct test coverage, same as before the refactor (it was never unit-tested inline
either, so this is not a regression, just an untracked file addition).

---

## Pre-existing fix note (commit `1ebf55b`)

Independently confirmed, not just accepted on the commit message's word:
- `4ec5f50` (the branch point) does not compile `apps/popmundo_app`'s test target: `Utils` requires
  `(runtime, timedFetch)` but the old test called `Utils(runtime)`.
- `1ebf55b` changes zero assertion values in `menu_notifications_bridge_test.dart` — only the
  harness wiring (adds `_CountingUtils`, a `_serve()` fetch handler covering both the character page
  and `GetMenuNotifications`).
- The `_CountingUtils.getMyNameCalls` counter genuinely discriminates: mutation #6 above
  (moving `getMyName()` into the per-item loop) fails the "resolved once per batch" test, confirming
  the commit's own claim that a fetch-count-based check would NOT have caught this (TimedFetch
  caches `METHOD:URL`, so a naive once-per-item implementation would still fetch once).
- This commit predates the feature's own spec commit (`9fc711f`) and is therefore correctly excluded
  from CRS-08's "zero leaf-widget test file modified" scope — confirmed via
  `git diff 9fc711f..HEAD --stat -- apps/popmundo_app/test/`, which shows no touch to
  `notifications/menu_notifications_bridge_test.dart` within the feature's own commits.

---

## Gate Check

```
flutter analyze packages/popmundo_utils   → No issues found!
flutter analyze packages/popmundo_webview → No issues found!
flutter analyze apps/popmundo_app         → No issues found!
(cd packages/popmundo_utils && dart test)     → 216 passed
(cd packages/popmundo_webview && flutter test) → 31 passed
(cd apps/popmundo_app && flutter test)         → 111 passed
(cd apps/popmundo_app && flutter analyze integration_test) → No issues found!
```

**Result**: 7/7 gate commands passed, 0 failures, 0 skips.
**Out of agent reach** (per instructions, not attempted): `patrol test`, `flutter build`,
`flutter run` — Gradle cannot complete in this sandbox (`.specs/STATE.md` Handoff, confirmed prior
sessions). Not treated as a failure.

---

## Edge Cases (from spec.md)

- [x] `keepalive == null` ⇒ `build` renders without a background-status listener —
  `apps/popmundo_app/lib/app.dart:208-210` (`if (status == null) return overlay(null);`)
- [x] `notificationService == null` ⇒ `menuNotificationsBridge` stays `null`, `start`/`dispose` skip
  it — `apps/popmundo_app/lib/app_wiring.dart:135-141` (ternary), `:164` (`?.start()`), `:194`
  (`?.dispose()`)
- [x] `dispose()` before `start()` ⇒ no-op — directly tested,
  `apps/popmundo_app/test/app_wiring_test.dart:170-176`
- [x] Unknown userscript id ⇒ `connectHeadersFor` returns `const []` — directly tested,
  `apps/popmundo_app/test/app_wiring_test.dart:215-219`
- [~] Navigation event ⇒ `gmMenuRegistry.clear()` before cookie refresh — code confirms the ordering
  (`apps/popmundo_app/lib/app_wiring.dart:199-204`: `gmMenuRegistry.clear();` executes synchronously
  before `await cookieWatcher.refresh();`), but no test asserts the *ordering* specifically — the
  existing test (`app_wiring_test.dart:148-168`) only asserts the end state (registry empty), not
  that clear precedes refresh. Minor spec-precision gap, low severity given it's a one-line
  synchronous-then-await sequence that cannot silently reorder without an intentional code change.

---

## Code Quality

| Principle | Status |
| --- | --- |
| No features beyond what was asked | ✅ |
| No abstractions for single-use code | ✅ (CookieWatcher explicitly documented as *not* a port) |
| No unnecessary "flexibility" added | ✅ |
| Only touched files required for task | ✅ (one file, `auto_login_status_snackbar.dart`, is an untracked-but-reasonable extraction — see Necessity Check) |
| Didn't "improve" unrelated code | ✅ |
| Matches existing patterns/style | ✅ |
| Would senior engineer approve? | ⚠️ Yes, with the two sensor gaps fixed first |
| Tests map to acceptance criteria, non-shallow | ✅ (spot-checked P1 story in full) |
| Spec-anchored outcome check | ✅ 15/18 clean, 2 disclosed deviations confirmed accurate, 1 new spec-precision gap (CRS-17, cosmetic) |
| Per-layer coverage: domain 1:1 ACs, routes happy+edge+error | ⚠️ `CookieWatcher`'s error/dispose path has 0 tests |
| Every test maps to a spec requirement | ✅ (see Necessity Check) |
| Documented guidelines followed | `CLAUDE.md` composition-root/testing conventions — followed |

---

## Fix Plans

### Fix 1: `CookieWatcher` has no test coverage (Sensor mutation 4 survived)

- **Root cause**: T5's gate only required `flutter analyze` clean + suite green ("nothing wired
  yet"); no follow-up task ever added a dedicated test file for the new class.
- **Fix task**: Add `apps/popmundo_app/test/cookie_watcher_test.dart` covering: `refresh()` swallows
  a `CookieManager` failure (mirrors CRS-09's edge case, now applied to this class specifically);
  `dispose()` is idempotent; a `refresh()` in flight when `dispose()` runs does not throw (this is
  the exact behavior the removed guard protects — needs a fake/delayed `CookieManager` path or a
  seam to control timing, since the real `CookieManager.instance()` needs a platform channel not
  available in `flutter test`).
- **Priority**: Major — this is a coupling `CookieWatcher` was created specifically to make visible
  and safe; right now its safety is asserted only in a doc comment.

### Fix 2: CRS-11's dispose-while-pending test doesn't kill the `_disposed` guard removal (Sensor mutation 3 survived)

- **Root cause**: `MemoryKeyValueStore`/`UserScriptCatalog.list()` resolve too fast relative to
  `AppWiring.dispose()`'s own await chain for the existing test to reliably land `_publish`'s write
  after `userscripts.dispose()`.
- **Fix task**: Strengthen `apps/popmundo_app/test/app_wiring_test.dart`'s "dispose() while the
  catalog read is still in flight" test to force the ordering deterministically — e.g. a
  `KeyValueStore` fake whose `get`/`set` await a `Completer` the test controls, so `catalog.list()`
  is made to resolve strictly *after* `dispose()` has fully returned (and `userscripts` is disposed),
  then assert the write does not throw and/or that `wiring.userscripts.value` does not change after
  disposal.
- **Priority**: Major — CRS-11 is a P1 (Behavior-neutral) AC; the guard is real production code the
  comment says exists specifically for this race, but the test currently proves nothing about it.

---

## Out-of-scope observation (not a code gap, informational only)

Task 8 (doc sync) was in progress and uncommitted when this pass began, and landed as commits
`d4ccd21` ("docs: sync architecture docs with the composition-root refactor") and `e905314`
("docs(specs): record the composition-root-scaling execution log") while this verification was
running. Confirmed via `git log --oneline -5`: `docs/ARQUITETURA.md`, both package READMEs, the
`menu/`/`notifications/`/`autologin/` module READMEs, root `README.md`, `CLAUDE.md`'s
`flutter_inappwebview` bullet (now points at `cookie_watcher.dart`), the four mirrored
`popmundo-app-shell`/`popmundo-utils` agent files, and `.specs/STATE.md` (new AD-020) are all now
committed. `d4ccd21`'s message correctly notes `spec.md`'s traceability table is filled in but
`Verified` is intentionally withheld pending this report — consistent with this verifier not writing
to `spec.md` itself (out of scope per its own instructions; only `validation.md` was written). This
verifier did not read or touch any of these doc files beyond what was needed to confirm they exist,
per its instructions to stay out of `docs/`, `CLAUDE.md`, and module READMEs.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| CRS-01 | Implemented | ✅ Verified |
| CRS-02 | Implemented | ✅ Verified |
| CRS-03 | MISSED | ❌ Confirmed MISSED (216 > 180) |
| CRS-04 | Implemented | ✅ Verified |
| CRS-05 | Partial | ⚠️ Confirmed Partial |
| CRS-06 | Implemented | ✅ Verified |
| CRS-07 | Implemented | ✅ Verified |
| CRS-08 | Implemented | ✅ Verified (with the `1ebf55b` pre-existing-fix caveat documented above) |
| CRS-09 | Implemented | ✅ Verified |
| CRS-10 | Implemented | ✅ Verified |
| CRS-11 | Implemented | ⚠️ Verified-but-weak — test does not discriminate the guard it's meant to prove (Fix 2) |
| CRS-12 | Implemented | ✅ Verified |
| CRS-13 | Implemented | ✅ Verified |
| CRS-14 | Implemented | ⚠️ Verified-but-incomplete — `CookieWatcher`, part of the wiring layer CRS-14 targets, has no test file (Fix 1) |
| CRS-15 | Implemented | ✅ Verified |
| CRS-16 | Implemented | ✅ Verified |
| CRS-17 | Implemented | ⚠️ Verified with spec-precision gap (literal "anywhere in the repo" wording vs. historical docs) |
| CRS-18 | Implemented | ✅ Verified |

---

## Summary

**Overall**: ⚠️ Issues — ❌ FAIL on the discrimination sensor gate, everything else PASS

**Spec-anchored check**: 15/18 ACs cleanly matched their spec-defined outcome; 1 disclosed MISSED
confirmed accurate (CRS-03); 1 disclosed Partial confirmed accurate (CRS-05); 1 new spec-precision
gap surfaced (CRS-17, wording-only, not functional).

**Sensor**: 6 mutations injected (5 assigned + 1 independent verification of a disclosed claim),
**4 killed, 2 survived**.

**Gate**: 7/7 commands passed, 0 failures.

**What works**: Zero-collaborator `_PopmundoHomeState`, generic `buildAppMenuItems` signature,
feature-owned menu items, `AppWiring`'s CRS-09/10/12 behavior, `popmundo_utils` slicing (CRS-15/16),
dead-code removal (CRS-17 at the code level), per-folder READMEs (CRS-18) — all independently
re-derived from `file:line` evidence, not taken on the author's word.

**Issues found**:
1. `CookieWatcher` (new file, `apps/popmundo_app/lib/cookie_watcher.dart`) has zero test coverage —
   fix: add `cookie_watcher_test.dart` (Fix 1).
2. `app_wiring_test.dart`'s CRS-11 "dispose while pending" test does not actually force the race the
   `_disposed` guard in `_publish` protects against — fix: make the timing deterministic with a
   controllable fake store (Fix 2).

**Next steps**: Route Fix 1 and Fix 2 to an implementer, then re-run this sensor (re-apply mutations
3 and 4 above) to confirm both are killed before marking the feature done. Everything else in this
report needs no further action.
