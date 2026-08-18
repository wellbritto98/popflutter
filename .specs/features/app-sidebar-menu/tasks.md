# App Sidebar Menu Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/app-sidebar-menu/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling (`apps/popmundo_app/test/debug_overlay_test.dart`, `apps/popmundo_app/test/platform_config_test.dart`) — no project-level testing guideline file found (`CLAUDE.md` documents commands but not coverage thresholds); strong defaults applied where the repo is silent. Confirm before Execute.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------- | --------------------- | ----------------- | ------------ |
| Pure model/registry (`AppMenuItem`, `buildAppMenuItems`) | unit (via `flutter_test`'s `test()`, no widget pump) | All branches; 1:1 to spec ACs (MENU-04, MENU-05, MENU-06, MENU-07, MENU-09) | `apps/popmundo_app/test/app_menu_registry_test.dart` | `cd apps/popmundo_app && flutter test test/app_menu_registry_test.dart` |
| Widget (`AppSidebar`, `AppShell`, `DebugOverlay`) | widget (`testWidgets`) | Happy path + every listed edge case (empty state, close control, DBG-01 property) | `apps/popmundo_app/test/*_test.dart` | `cd apps/popmundo_app && flutter test` |
| App composition (`app.dart`, `_PopmundoHomeState`) | none — untestable without the concrete `InAppPopmundoRuntime`; same constraint as pre-existing code | build/analyze gate only | — | `cd apps/popmundo_app && flutter analyze` |
| Documentation / `.specs` hygiene | none | — | — | build gate only (no compiled artifact) |

## Gate Check Commands

> Generated from `CLAUDE.md` commands section — confirm before Execute.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After tasks with unit tests only (T1) | `cd apps/popmundo_app && flutter test test/app_menu_registry_test.dart` |
| Full | After tasks with widget tests (T2, T3, T4) | `cd apps/popmundo_app && flutter test` |
| Build | After phase completion, composition-only, or doc-only tasks (T5, T6, T7) | `cd apps/popmundo_app && flutter analyze && cd apps/popmundo_app && flutter test` |

---

## Execution Plan

Phases are ordered and run sequentially — each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Menu building blocks

Foundation types and widgets — purely additive, nothing imports them into the app yet.

```
T1 → T2 → T3
```

### Phase 2: Debug overlay refactor + composition

Makes the existing debug panel controllable and wires everything together in the app.

```
T4 → T5
```

### Phase 3: Documentation and spec hygiene

Brings docs and `.specs/` records in line with the shipped behavior.

```
T6 → T7
```

---

## Task Breakdown

### T1: AppMenuItem model + buildAppMenuItems registry

**What**: Create the immutable `AppMenuItem` value type and the `buildAppMenuItems` registry function (the sidebar's single extension point).
**Where**: `apps/popmundo_app/lib/menu/app_menu_item.dart`, `apps/popmundo_app/lib/menu/app_menu_registry.dart`
**Depends on**: None
**Reuses**: `design.md` → AppMenuItem, buildAppMenuItems; `collection-if` idiom already used in `debug_overlay.dart`
**Requirement**: MENU-04, MENU-05, MENU-06, MENU-07, MENU-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `AppMenuItem` is `@immutable`, `const`-constructible, with fields `id`, `icon`, `label`, `subtitle?`, `onTap` — no `BuildContext` field
- [ ] `buildAppMenuItems({required VoidCallback onOpenDebugPanel, bool includeDebugItem = kDebugMode})` returns exactly one `AppMenuItem` (`id: 'debug'`) when `includeDebugItem: true`, and an empty list when `includeDebugItem: false`
- [ ] The returned item's `onTap` invokes `onOpenDebugPanel` exactly once when called
- [ ] Gate check passes: `cd apps/popmundo_app && flutter test test/app_menu_registry_test.dart`
- [ ] Test count: 4 tests pass (no silent deletions)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(app-menu): add AppMenuItem model and buildAppMenuItems registry`

---

### T2: AppSidebar widget

**What**: Create the `Drawer`-based sidebar that renders a list of `AppMenuItem`, closes itself on tap, and shows an empty state when the list is empty.
**Where**: `apps/popmundo_app/lib/menu/app_sidebar.dart`
**Depends on**: T1
**Reuses**: `design.md` → AppSidebar; `Key` kebab-case convention from `debug_overlay.dart`
**Requirement**: MENU-02, MENU-05, MENU-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Renders `Drawer(key: Key('app-sidebar'))` with a `DrawerHeader` showing "Popmundo"
- [ ] Renders one `ListTile(key: Key('menu-item-<id>'))` per item, with icon and label (and subtitle when present)
- [ ] Tapping an item closes the drawer (`Scaffold.maybeOf(context)?.closeDrawer()`) and then calls the item's `onTap`
- [ ] With an empty item list, renders `Text(key: Key('menu-empty'))` with "No options available." and no `ListTile`
- [ ] Gate check passes: `cd apps/popmundo_app && flutter test`
- [ ] Test count: 5 tests pass (no silent deletions)

**Tests**: widget
**Gate**: full

**Commit**: `feat(app-menu): add AppSidebar drawer widget`

---

### T3: AppShell widget

**What**: Extract the app's `Scaffold` into its own widget, hosting `AppSidebar` as `drawer`, a FAB that opens it, and a `body` slot — decoupled from the concrete runtime.
**Where**: `apps/popmundo_app/lib/app_shell.dart`
**Depends on**: T1, T2
**Reuses**: `design.md` → AppShell; existing `mini: true` FAB style from `debug_overlay.dart`
**Requirement**: MENU-01, MENU-03, MENU-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `AppShell({required List<AppMenuItem> items, required Widget body})` renders a `Scaffold` with `drawer: AppSidebar(items: items)` and `body: body`
- [ ] `drawerEnableOpenDragGesture` is `false` (DBG-01 guard — inline comment citing DBG-01)
- [ ] FAB (`key: Key('menu-toggle')`, `Icons.menu`, `mini: true`) is always rendered, built inside a `Builder` so `Scaffold.of(context).openDrawer()` resolves correctly, regardless of `items.isEmpty`
- [ ] Tapping the FAB opens `AppSidebar`
- [ ] Gate check passes: `cd apps/popmundo_app && flutter test`
- [ ] Test count: 5 tests pass (no silent deletions)

**Tests**: widget
**Gate**: full

**Commit**: `feat(app-menu): add AppShell scaffold with drawer-opening FAB`

---

### T4: Controlled DebugOverlay + test rewrite

**What**: Remove `DebugOverlay`'s own FAB/internal toggle; make it a controlled widget (`visible`/`onClose`) with a dedicated close control, preserving every other current behavior. Rewrite `debug_overlay_test.dart` per the assertion-mapping table below.
**Where**: `apps/popmundo_app/lib/debug_overlay.dart`, `apps/popmundo_app/test/debug_overlay_test.dart`
**Depends on**: None (independent of T1–T3; touches only `DebugOverlay`)
**Reuses**: `design.md` → DebugOverlay (modificado); all internal panel logic (`_networks`, `_consoles`, `_clear()`, `_runEval()`, cookie chips) unchanged
**Requirement**: MENU-06, MENU-07, MENU-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `DebugOverlay` constructor gains `bool visible = false` and `VoidCallback? onClose`; `_expanded` field and the internal `FloatingActionButton` block are removed
- [ ] Panel visibility is driven solely by `widget.visible`; when `false`, the widget renders only `child` (stronger DBG-01 pass-through than before — no control at all over the WebView)
- [ ] Header row gains `IconButton(key: Key('debug-close'), icon: Icons.close, onPressed: widget.onClose)` alongside the existing `debug-clear` button; all pre-existing keys (`debug-panel`, `debug-host`, `debug-clear`, `debug-eval-input`, `debug-eval-run`, `debug-eval-result`) are unchanged
- [ ] Test 1 preserved/relocated per the mapping table in `design.md`'s Risks section and `spec.md` MENU-06..08: `debug-toggle` presence assertion → replaced by `find.byType(FloatingActionButton) findsNothing`; `debug-panel` absence when `visible: false` → preserved verbatim
- [ ] Test 2 preserved: all body assertions (host, cookie `name@domain`, **`secret-value` never rendered**, network/console events, eval input/run/result, clear) unchanged except the setup now passes `visible: true` instead of tapping a toggle
- [ ] New test: tapping `debug-close` invokes `onClose` once, and re-pumping with `visible: false` hides `debug-panel`
- [ ] Gate check passes: `cd apps/popmundo_app && flutter test`
- [ ] Test count: 3 tests pass in this file (2 preserved + 1 new), no assertions silently dropped

**Tests**: widget
**Gate**: full

**Commit**: `refactor(debug-overlay): make DebugOverlay a controlled visible/onClose widget`

---

### T5: Wire AppShell + registry into app.dart

**What**: Compose `AppShell` in `_PopmundoHomeState.build()`, add `_debugPanelVisible` state, pass `buildAppMenuItems(onOpenDebugPanel: ...)` and the controlled `DebugOverlay` props.
**Where**: `apps/popmundo_app/lib/app.dart`
**Depends on**: T1, T2, T3, T4
**Reuses**: `design.md` → Integration Points; existing `PopmundoScope`/`_refreshCookies` logic unchanged
**Requirement**: MENU-01, MENU-03, MENU-06, MENU-07

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `_PopmundoHomeState` has `var _debugPanelVisible = false;`
- [ ] `build()` composes `PopmundoScope(... child: AppShell(items: buildAppMenuItems(onOpenDebugPanel: () => setState(() => _debugPanelVisible = true)), body: SafeArea(child: DebugOverlay(..., visible: _debugPanelVisible, onClose: () => setState(() => _debugPanelVisible = false), child: PopmundoWebView(...)))))`
- [ ] `SafeArea` continues to wrap only the body (no second `SafeArea` around the FAB)
- [ ] `PopmundoScope` gains no new call sites (sidebar/shell remain runtime-agnostic)
- [ ] Gate check passes: `cd apps/popmundo_app && flutter analyze && cd apps/popmundo_app && flutter test`
- [ ] Test count: unchanged from T4 (this task adds no new test file — `PopmundoHome` requires the concrete `InAppPopmundoRuntime`, which cannot be faked)

**Tests**: none
**Gate**: build

**Commit**: `feat(app): wire AppShell and menu registry into PopmundoHome`

---

### T6: Documentation updates

**What**: Update `apps/popmundo_app/README.md`, `docs/ARQUITETURA.md`, `docs/OBJETIVO.md` per the touchpoints below.
**Where**: `apps/popmundo_app/README.md`, `docs/ARQUITETURA.md`, `docs/OBJETIVO.md`
**Depends on**: T5
**Reuses**: existing README template headings (Objetivo do módulo / Responsabilidade principal / Funcionalidades existentes / Dependências / Módulos relacionados / Pontos de entrada / Fluxos importantes / Arquivos críticos / Observações técnicas e débitos identificados)
**Requirement**: N/A (documentation, not a functional requirement)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `apps/popmundo_app/README.md` — Funcionalidades existentes table gains rows for `app_shell.dart`, `menu/app_menu_item.dart`, `menu/app_menu_registry.dart`, `menu/app_sidebar.dart`, and its `debug_overlay.dart`/`app.dart` rows are updated to describe the controlled panel and `_debugPanelVisible`
- [ ] `apps/popmundo_app/README.md` — Fluxos importantes replaces "Overlay recolhível" with the sidebar → debug-panel flow, keeping the DBG-01 pass-through statement updated
- [ ] `apps/popmundo_app/README.md` — Arquivos críticos names `menu/app_menu_registry.dart` as the extension point and lists the new/changed widget `Key`s (`debug-toggle` removed; `debug-close`, `app-sidebar`, `menu-toggle`, `menu-item-<id>`, `menu-empty` added)
- [ ] `apps/popmundo_app/README.md` — Observações técnicas e débitos identificados documents: no i18n; release-mode empty sidebar with FAB still visible; `drawerEnableOpenDragGesture: false` is a DBG-01 requirement, not styling; the pre-existing `StreamSubscription` leak in `DebugOverlay.initState` (found, not fixed here); `PopmundoScope` still has zero call sites by design
- [ ] `docs/ARQUITETURA.md` — §3 gains a rule that no shell widget may install a gesture recognizer over the WebView area; §4 documents the new `Key` convention; §5's `apps/popmundo_app` row gains "menu lateral componentizado (`lib/menu/`)"; §9 gains the directive "novo item de menu = uma entrada em `buildAppMenuItems`"; §1 mermaid diagram updated to include `AppShell`/`AppSidebar`
- [ ] `docs/OBJETIVO.md` — §5 gains a "Menu lateral (sidebar)" bullet; the existing "Overlay de debug (P2)" bullet is edited to say it opens from the sidebar item, not its own FAB
- [ ] Gate check passes: `cd apps/popmundo_app && flutter analyze && cd apps/popmundo_app && flutter test` (docs-only, but re-run to confirm nothing else drifted)

**Tests**: none
**Gate**: build

**Commit**: `docs(app-menu): document sidebar menu in READMEs and architecture docs`

---

### T7: Spec hygiene — STATE.md and popmundo-wrapper cross-references

**What**: Record decision AD-009 in `.specs/STATE.md`, update the superseded "Overlay em release" row in `popmundo-wrapper/context.md`, and note DBG-01's new home (shell FAB) in `popmundo-wrapper/spec.md`.
**Where**: `.specs/STATE.md`, `.specs/features/popmundo-wrapper/context.md`, `.specs/features/popmundo-wrapper/spec.md`
**Depends on**: T6
**Reuses**: existing AD-NNN entry format in `STATE.md`
**Requirement**: N/A (project memory, not a functional requirement)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `.specs/STATE.md` — Decisions section gains **AD-009** (section-scoped write only; Handoff section touched separately, see below) describing: debug entry point moved to a componentized sidebar; debug item gated by `kDebugMode`; FAB stays visible with an empty-state sidebar in release
- [ ] `.specs/STATE.md` — Handoff section updated to reflect `app-sidebar-menu` as the active/most-recent feature once T7 lands (per `memory.md` — Decisions section untouched otherwise)
- [ ] `.specs/features/popmundo-wrapper/context.md` — the row *"Overlay em release | FAB toggle, default visível | ... | n (agent)"* is annotated as superseded by AD-009, confirmed by the user
- [ ] `.specs/features/popmundo-wrapper/spec.md` — DBG-01's "except for the expand control" phrasing gains a note that the control is now the shell-level FAB (`menu-toggle`), not a control owned by `DebugOverlay` itself
- [ ] `.specs/LESSONS.md` / `.specs/lessons.json` are **not** hand-edited (machine-owned)
- [ ] Gate check passes: build gate only — no code changed, confirm repo still analyzes/tests clean

**Tests**: none
**Gate**: build

**Commit**: `docs(specs): record AD-009 and cross-reference app-sidebar-menu in popmundo-wrapper`

---

## Execution Diagram

Visual representation of task ordering. Phases run in sequence, and tasks within a phase run in order:

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 ──→ T2 ──→ T3
Phase 2:  T4 ──→ T5
Phase 3:  T6 ──→ T7
```

Execution is strictly sequential — there is no intra-phase parallelism. Total: 7 tasks, well within a single ~7-task worker budget — no sub-agent batch offer required; execution happens inline (or as one batch, if delegated).

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ----------------------- | -------------- | ------- |
| T1 | None | (start of Phase 1) | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T1, T2 | T2 → T3 (T1 satisfied earlier in phase) | ✅ Match |
| T4 | None (independent) | Starts Phase 2 | ✅ Match |
| T5 | T1, T2, T3, T4 | T4 → T5 (T1–T3 satisfied by end of Phase 1) | ✅ Match |
| T6 | T5 | Starts Phase 3 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | ----------------------------- | ----------------- | ----------- | ------- |
| T1: AppMenuItem + registry | Pure model/registry | unit | unit | ✅ OK |
| T2: AppSidebar | Widget | widget | widget | ✅ OK |
| T3: AppShell | Widget | widget | widget | ✅ OK |
| T4: DebugOverlay refactor | Widget | widget | widget | ✅ OK |
| T5: Wire app.dart | App composition (untestable without concrete runtime) | none | none | ✅ OK |
| T6: Documentation | Documentation | none | none | ✅ OK |
| T7: Spec hygiene | Documentation / project memory | none | none | ✅ OK |

No ❌ VIOLATION — all tasks' `Tests` fields match the coverage matrix.

---

## Granularity Check

| Task | Scope | Status |
| ---- | ------ | ------- |
| T1: AppMenuItem + registry | 2 files, 1 cohesive concept (model + its single builder function) | ✅ Granular |
| T2: AppSidebar | 1 widget | ✅ Granular |
| T3: AppShell | 1 widget | ✅ Granular |
| T4: DebugOverlay refactor | 1 widget + its test file (cohesive pair) | ✅ Granular |
| T5: Wire app.dart | 1 file change | ✅ Granular |
| T6: Documentation | 3 doc files, one cohesive "document the feature" deliverable | ✅ Granular |
| T7: Spec hygiene | 3 `.specs/` files, one cohesive "record the decision" deliverable | ✅ Granular |
