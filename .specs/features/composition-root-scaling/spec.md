# Composition Root Scaling Specification

## Problem Statement

`apps/popmundo_app/lib/app.dart` is 402 LOC — 15% of the app's entire `lib/` — and appears in
essentially every feature commit (19 commits, out of 136 total). `_PopmundoHomeState` builds 15
collaborators as `late final` fields and mutates 7 `setState` fields, so adding one feature
requires edits in **7 scattered places**: the `late final` block → `initState` → `dispose` →
`build`/`_openX` → `main.dart` → the `buildAppMenuItems` named-parameter signature →
`app_menu_registry_test.dart`.

The cost this imposes is concrete and recurring. To find *where to plug a feature in*, a coding
agent must load `app.dart` (402) + `main.dart` (44) + `app_menu_registry.dart` (49) + the registry
test (158) ≈ **650 LOC ≈ 9k tokens**, every session, and that grows O(n features). A second,
quieter cost: the bootstrap / userscript-sync / cookie-refresh logic is locked inside a `State`
object and therefore has **zero unit tests** today.

This is not a missing-layer problem. The macro architecture (3 packages, ports & adapters,
feature-first slices, manual DI, per-folder READMEs) is already what current conventions
recommend. This feature fixes the one bottleneck without adding a conceptual layer.

## Goals

- [ ] Adding a sidebar-backed feature requires **1 line in the composition root + 1 file in the
      feature's own folder** — never a signature change and never an edit inside `_PopmundoHomeState`.
- [ ] `apps/popmundo_app/lib/app.dart` drops substantially from 402 LOC (target was ≤ 180; **actual: 216** — see the CRS-03 note).
- [ ] The collaborator wiring becomes a plain, non-widget object with unit tests covering behavior
      that has none today (userscript diffing, start/dispose lifecycle, `@connect` header lookup).
- [ ] `packages/popmundo_utils/lib/src` has **zero loose files** — every source file lives in a
      named slice — with the package's public export surface byte-identical.
- [ ] **Zero new dependencies, zero new conceptual layers.** Only Flutter primitives already used
      in this repo (`ValueNotifier`, `ValueListenableBuilder`, `ChangeNotifier`).

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| --- | --- |
| Clean Architecture layering (`entities/`, `usecases/`, `mappers/`, `datasources/`) | Explicit user rejection. The domain layer already exists as `popmundo_utils` (Flutter-free, device-free tests) — the benefit is already held without the boilerplate |
| Per-feature packages / Melos scripts | One app, no genuine cross-app reuse. `melos.yaml` stays globs-only (AD-001) |
| A state-management library (Riverpod, BLoC, signals) | `setState` + `ChangeNotifier`/`ValueNotifier` already cover 8 features across 2.7k LOC; a library adds provider+notifier+state per feature |
| A DI container (`get_it`, `injectable`) | Manual constructor DI is cheaper for an agent to follow — the object graph is greppable. A container hides it behind type/string registration |
| A routing abstraction / named routes | `Navigator.push` call sites are 3 lines each and BuildContext-bound; a router is a layer this app has no need for |
| A new port/abstraction for `CookieManager` | The `flutter_inappwebview` import in the app layer is a coupling CLAUDE.md documents as intentional. This feature **relocates** that code, it does not abstract it |
| Any behavior change to the game-facing flows (TimedFetch throttle, Auto Login handshake, session heartbeat, observe-only interception, GM host APIs) | Behavior-neutral refactor. AD-003/-007/-010/-012/-018/-019 all hold unchanged |
| Splitting `popmundo_webview` | Only 12 files / 1016 LOC, already one coherent slice. No bottleneck there |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Execution slicing | Cleanup (A) + wiring extraction (B) + menu registry (C) in **one cycle** | User choice via `AskUserQuestion`. Two cycles would pay the context re-exploration cost twice | y |
| Process | Full `tlc-spec-driven` pipeline (Specify → Design → Tasks → Execute + Verifier) | User choice. CLAUDE.md mandates it for cross-package changes | y |
| Menu registry signature change, given it forces rewriting 8 tests (158 LOC) | **Include it.** One-time test rewrite; the saving is per-feature, forever | User choice | y |
| Where the `MaterialApp` is constructed | Stays textually inside `lib/app.dart` | `test/localization_boot_test.dart:44-70` does a raw **source-text substring scan** of `lib/app.dart`. Moving the `MaterialApp` breaks it on file-location grounds alone | y (agent default, verified against the test) |
| Where `AppWiring` is constructed | `lib/main.dart` | It already builds `InAppPopmundoRuntime`, `SharedPreferencesStore`, `BackgroundKeepalive`, `LocalNotificationsService`. The `secretStore ?? FlutterSecureSecretStore()` default moves there from `PopmundoApp.build` | y (agent default) |
| New slice folder names in `popmundo_utils/lib/src` | `core/` and `facades/` | `facades/` is the vocabulary **already used** in `docs/ARQUITETURA.md`'s patterns table and the "Facades" row of `packages/popmundo_utils/README.md`. Inventing `page/` would add a third word for the same idea | y (agent default) |
| `_debugPanelVisible` | Stays a `setState` field on `_PopmundoHomeState` | Pure UI toggle with no collaborator behind it. Moving it to a notifier would be ceremony | y (agent default) |
| Moving `debug_overlay.dart` into a `lib/debug/` folder | **Cut.** `debug_overlay.dart` stays at `lib/` root | Two independent design passes reached the same verdict: `lib/` root already holds the shell's flat files (`app_shell.dart`, `l10n.dart`, `prefs_store.dart`) and debug is a shell capability, not a feature slice. Costs 3 test-import updates for zero functional gain. `debugMenuItem` goes in `lib/menu/` next to the registry it gates | y (agent default, cut) |
| The app's `StorageService storage` instance | **Deleted, not migrated** | Verified: its only consumer is `PopmundoScope` (`app.dart:96` builds it, `app.dart:388` holds it). Once CRS-17 removes the scope it has zero consumers — carrying it into `AppWiring` would create fresh dead weight. `StorageService` itself stays in `popmundo_utils` (it has its own tests there); only the app-side instance goes | y (agent default) |
| Shape of the new `buildAppMenuItems` | `({required List<AppMenuItem> items, AppMenuItem? debugItem, bool includeDebugItem = kDebugMode})` — **no new wrapper type** | An earlier draft introduced an `AppMenuContribution` value object. A plain list plus a nullable `debugItem` satisfies the same three invariants (caller-controlled order, debug last, per-call gating) with zero new types — which is the point of this feature | y (agent default) |
| Verification depth reachable by the agent | `flutter analyze` + `dart test` + `flutter test` only | `.specs/STATE.md` Handoff records that Gradle builds cannot complete in the agent sandbox (confirmed 3×). Patrol / `flutter run` smoke stays with the user | y |
| `STATE.md` AD entry | **Required** (AD-020) | This *is* a cross-cutting architectural choice about the composition root — exactly what the Decisions log exists for | y (agent default) |

**Open questions:** none — all resolved or logged above.

### Implicit-requirement dimensions sweep (Large scope — every dimension resolved)

| Dimension | Resolution |
| --- | --- |
| Input validation & bounds | **N/A** — no new user input surface; this is an internal restructuring |
| Failure / partial-failure states | CRS-09 |
| Idempotency / retry / duplicate handling | CRS-10 |
| Auth boundaries & rate limits | **N/A** — no new network call. `TimedFetch`, `AuthSession`, and the 60s heartbeat are untouched |
| Concurrency / ordering | CRS-11 |
| Data lifecycle / expiry | **N/A** — no storage key added, removed, or renamed. `userscripts.v1`, `autologin.v1`, `userscript:<id>:gmvalues`, `userscript:<id>:gmresources` unchanged |
| Observability | **N/A** — `Logger` and the debug overlay's event streams are untouched |
| External-dependency failure | Covered by CRS-09 (`CookieManager` unavailable, `PopmundoRuntimeException` on sync) |
| State-transition integrity | CRS-12 |

---

## User Stories

### P1: The composition root stops growing per feature ⭐ MVP

**User Story**: As the developer (and as the coding agent working for me), I want to add a
sidebar-backed feature by touching one line in the composition root and one file in the feature's
own folder, so that per-feature context cost stays flat instead of growing with the app.

**Why P1**: This is the entire point of the feature. Everything else is supporting work.

**Acceptance Criteria**:

1. WHEN a developer inspects `_PopmundoHomeState` THEN it SHALL construct **zero** collaborator
   objects — every collaborator SHALL be a field of `AppWiring`.
2. WHEN a new sidebar entry is added THEN the signature of `buildAppMenuItems` SHALL NOT change,
   and the new entry's `AppMenuItem` SHALL be defined inside its own feature folder.
3. WHEN `apps/popmundo_app/lib/app.dart` is measured THEN it SHALL be ≤ 180 lines.
   > ⚠️ **MISSED — 216 lines (recorded at T6, not retrofitted).** 402 → 216 is a 46% cut, but the
   > 180 figure was an estimate made before the `build` method was written and it did not account
   > for the cost of scoped rebuilds: three `ValueListenableBuilder`/`ListenableBuilder` wrappers
   > plus the nullable-`keepalive` branch take ~55 lines that the old blanket-`setState` version got
   > for free by reading fields inline. Closing the gap would mean either giving those lines back
   > (returning to whole-tree rebuilds) or scattering `build` across files purely to satisfy a line
   > count. Neither serves CRS-01/CRS-02, which are the requirements that actually encode the goal —
   > and both are met: zero collaborators in the State, one edit point per feature. The number is
   > reported as measured rather than the target being quietly rewritten.
4. WHEN `AppWiring` is inspected THEN it SHALL NOT reference `BuildContext`, `State`, `Navigator`,
   or any widget type.
5. WHEN the sidebar is built with the debug item included THEN the item order SHALL be
   `auto-login, userscripts, language, debug`, with the debug entry always last.
6. WHEN `buildAppMenuItems` is called without `includeDebugItem` THEN debug inclusion SHALL equal
   `kDebugMode`.
7. WHEN the app runs under a `pt` locale THEN menu labels SHALL resolve through live `.tr()`
   catalog lookups, not hardcoded strings.

**Independent Test**: `flutter test test/app_menu_registry_test.dart` plus a line count of
`app.dart` and a grep of `_PopmundoHomeState` for collaborator constructors.

> ⚠️ **Known coverage delta on CRS-05 (recorded at T4, for the Verifier to rule on).**
> "debug is always last" and "the caller's order is preserved" are both structurally guaranteed and
> directly tested in `app_menu_registry_test.dart`, and every feature's own id is asserted in its
> `*_menu_item_test.dart`. What is **no longer** covered is the concrete production sequence
> `auto-login, userscripts, language` — that is now data in `app.dart`'s single call site, and no
> test pumps `_PopmundoHomeState`. Closing it would require reintroducing a registry that knows the
> feature identities, i.e. undoing CRS-02. Recorded deliberately rather than papered over.

---

### P1: The refactor is behavior-neutral ⭐ MVP

**User Story**: As the developer, I want proof that nothing observable changed, so that I can
accept a 400-line restructuring of the app's startup path without a manual regression sweep.

**Why P1**: A refactor that silently changes behavior is worse than no refactor.

**Acceptance Criteria**:

8. WHEN the full test suite runs after the change THEN every pre-existing test SHALL pass **without
   any leaf-widget test file being modified** (`app_shell_test.dart`, `app_sidebar_test.dart`,
   `debug_overlay_test.dart`, `language_selector_test.dart`, `auto_login_screen_test.dart`,
   `background_status_test.dart`, `background_keepalive_test.dart`, `userscripts_screen_test.dart`,
   `notifications/*`).
9. WHEN `CookieManager` is unavailable (test/desktop binding) or `runtime.syncUserScripts` throws
   `PopmundoRuntimeException` (WebView not yet attached) THEN `AppWiring` SHALL swallow the error
   exactly as `_PopmundoHomeState` does today, leaving the rest of startup unaffected.
10. WHEN `AppWiring.start()` is invoked more than once THEN it SHALL NOT create duplicate stream
    subscriptions or duplicate listener registrations.
11. WHEN `AppWiring.dispose()` runs while a `start()`-initiated async operation is still pending
    THEN it SHALL complete without throwing and SHALL NOT leave an active subscription behind.
12. WHEN `applyUserScripts(next)` completes THEN `previouslyEnabledIds` SHALL equal exactly the set
    of ids in `next` whose `enabled` is true — this value is the diff input to
    `runtime.syncUserScripts` on the following call.
13. WHEN `localization_boot_test.dart` runs THEN its source-text scan of `lib/app.dart` and
    `lib/main.dart` SHALL still find every asserted substring.

**Independent Test**: full suite green with `git diff --stat` showing zero changes to the leaf
widget test files listed in AC 8.

---

### P2: The wiring logic becomes testable

**User Story**: As the developer, I want the bootstrap / userscript-sync / cookie logic covered by
unit tests, so that behavior currently protected by nothing gains a regression net.

**Why P2**: Not required for the structural win, but this logic is genuinely untested today and
extraction is what makes testing it possible at all.

**Acceptance Criteria**:

14. WHEN `test/app_wiring_test.dart` runs THEN it SHALL cover, using `FakePopmundoRuntime` and
    `MemoryKeyValueStore`: `start()` performing catalog bootstrap; `applyUserScripts` updating the
    userscripts notifier and the `previouslyEnabledIds` diff (CRS-12); `dispose()` cancelling every
    subscription; and `connectHeadersFor` returning a script's `@connect` headers (and `const []`
    for an unknown id).

**Independent Test**: `cd apps/popmundo_app && flutter test test/app_wiring_test.dart`.

---

### P2: Structural consistency across the repo

**User Story**: As the coding agent, I want every source file to live in a named slice and every
feature folder to carry a README, so that locating code is a directory lookup rather than a
repo-wide grep.

**Why P2**: Real but incremental savings; independent of the `app.dart` bottleneck.

**Acceptance Criteria**:

15. WHEN `packages/popmundo_utils/lib/src` is listed THEN it SHALL contain **only** directories —
    zero loose `.dart` files.
16. WHEN the barrel `lib/popmundo_utils.dart` is compared before and after THEN the **set of
    exported symbols SHALL be identical**, and neither `popmundo_webview` nor `popmundo_app` SHALL
    require an import change.
17. WHEN `apps/popmundo_app/lib/app.dart` is searched for `PopmundoScope` THEN there SHALL be no
    match anywhere in the repo.
18. WHEN each feature folder under `apps/popmundo_app/lib/` is listed THEN each SHALL contain a
    `README.md`.

**Independent Test**: `ls packages/popmundo_utils/lib/src`, `grep -r PopmundoScope`, and a
`flutter analyze` of all three packages proving the barrel surface held.

---

## Edge Cases

- WHEN `keepalive` is `null` (not injected) THEN `build` SHALL render the debug overlay without a
  background-status listener rather than throwing.
- WHEN `notificationService` is `null` THEN `menuNotificationsBridge` SHALL remain `null` and
  `start()`/`dispose()` SHALL skip it, exactly as today.
- WHEN `dispose()` is called before `start()` was ever called THEN it SHALL be a no-op.
- WHEN a userscript id passed to `connectHeadersFor` is not in the catalog THEN it SHALL return
  `const []` (current behavior).
- WHEN a navigation event fires THEN `gmMenuRegistry.clear()` SHALL still run before the cookie
  refresh, preserving today's ordering.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| CRS-01 | P1: Composition root stops growing | T6 | Verified |
| CRS-02 | P1: Composition root stops growing | T4 | Verified |
| CRS-03 | P1: Composition root stops growing | T6 | **MISSED** (216 vs ≤180), confirmed by Verifier |
| CRS-04 | P1: Composition root stops growing | T5 | Verified |
| CRS-05 | P1: Composition root stops growing | T4 | Verified — partial, delta disclosed |
| CRS-06 | P1: Composition root stops growing | T4 | Verified |
| CRS-07 | P1: Composition root stops growing | T4 | Verified |
| CRS-08 | P1: Behavior-neutral | T6 | Verified |
| CRS-09 | P1: Behavior-neutral | T5,T7 | Verified |
| CRS-10 | P1: Behavior-neutral | T5,T7 | Verified |
| CRS-11 | P1: Behavior-neutral | T5,T7 | Verified |
| CRS-12 | P1: Behavior-neutral | T5,T7 | Verified |
| CRS-13 | P1: Behavior-neutral | T6 | Verified |
| CRS-14 | P2: Wiring becomes testable | T7 | Verified |
| CRS-15 | P2: Structural consistency | T3 | Verified |
| CRS-16 | P2: Structural consistency | T3 | Verified |
| CRS-17 | P2: Structural consistency | T1 | Verified |
| CRS-18 | P2: Structural consistency | T2 | Verified |

**ID format:** `CRS-[NUMBER]` (Composition Root Scaling). AC numbering in the stories above is
1:1 with these IDs.

**Coverage:** 18 total, 18 mapped to tasks, 0 unmapped. 16 Implemented, 1 Partial (CRS-05), 1 **Missed** (CRS-03). Verifier PASS at iteration 2 (`validation.md`): 16 Verified, CRS-05 Verified-partial with its delta disclosed, CRS-03 **Missed** and confirmed as missed. Iteration 1 returned FAIL on two surviving mutants; both were fixed in `160a4d8` and re-killed at iteration 2.

---

## Success Criteria

- [ ] `app.dart` substantially reduced from 402 LOC — measured by `wc -l`. **Result: 216 (−46%)**, short of the ≤ 180 target; see the CRS-03 note for why that was not forced.
- [ ] Adding a hypothetical new sidebar feature touches **≤ 2 files** in the composition root
      (`app.dart`'s menu list + the new feature's own folder) — demonstrated by walking the diff of
      an existing feature against the new structure.
- [ ] `flutter analyze` clean on all three packages; `dart test` (utils) and `flutter test`
      (webview, app) fully green.
- [ ] `git diff --stat` shows **zero** modifications to the leaf-widget test files named in CRS-08.
- [ ] Discrimination sensor: mutating `AppWiring.applyUserScripts` to skip the
      `previouslyEnabledIds` update makes `app_wiring_test.dart` fail (CRS-12 is really guarded).
- [ ] `packages/popmundo_utils/lib/src` contains zero loose `.dart` files and the barrel's exported
      symbol set is unchanged.
