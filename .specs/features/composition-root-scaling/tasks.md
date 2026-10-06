# Tasks: Composition Root Scaling

Package column: **U** = `packages/popmundo_utils`, **A** = `apps/popmundo_app`, **D** = docs.
Each task = one atomic commit, gated by its package's test runner passing **before** commit.

Order is fixed: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8. T1 must precede T6/T7 (the wiring diff is
measured against already-dead-code-free source). T4 must precede T7 (its call-site change lands in
`build` before `build` is rewritten). T5 must precede T7 (`app_wiring.dart` must exist before
`app.dart` consumes it).

| # | Task | Pkg | Covers | Verification (gate) |
| - | ---- | --- | ------ | ------------------- |
| 1 | Delete `PopmundoScope` (`app.dart` class + the `build` wrapper) **and** the now-orphaned `late final storage = StorageService(widget.store)` — its only consumer was the scope's `storage` field. `build` returns `AppShell(...)` directly | A | CRS-17 | `flutter analyze apps/popmundo_app` clean (no new unused-import warning); `flutter test` green; `grep -r PopmundoScope` returns nothing outside docs |
| 2 | Create `lib/notifications/README.md` in the house style of `lib/gm/README.md` (Objetivo / Responsabilidade principal / Funcionalidades existentes / Dependências / Relacionados / Pontos de entrada / Observações e débitos), documenting `notification_service.dart`, `local_notifications_service.dart`, `fake_notification_service.dart`, `menu_notifications_bridge.dart` | A | CRS-18 | Docs-only. `ls apps/popmundo_app/lib/*/README.md` shows one per feature folder |
| 3 | `git mv` the 12 loose `lib/src/*.dart` into `core/` (8) and `facades/` (4); rewrite the 11 `../X.dart` imports in the 3 existing slices to `../core/X.dart` (**preserving** `show ClockNow, Sleeper` in `auth_http.dart` and `show ClockNow` in `auto_login_controller.dart`); rewrite `facades/*`'s bare sibling imports to `../core/...`; update the 12 export paths in the barrel | U | CRS-15, CRS-16 | `cd packages/popmundo_utils && dart test` green; `flutter analyze` clean on **all three** packages (proves the barrel's symbol set held and no downstream import changed); `ls lib/src` shows directories only |
| 4 | New `buildAppMenuItems({required List<AppMenuItem> items, AppMenuItem? debugItem, bool includeDebugItem = kDebugMode})`; create `autologin/auto_login_menu_item.dart`, `userscripts/userscripts_menu_item.dart`, `language/language_menu_item.dart`, `menu/debug_menu_item.dart`; update the `app.dart` call site; **redistribute the tests in the same commit** — `app_menu_registry_test.dart` keeps only ordering/gating (against stub items), and 4 new flat `*_menu_item_test.dart` files take each feature's EN label/subtitle, `onTap`-once, and PT `.tr()` assertions | A | CRS-02, CRS-05, CRS-06, CRS-07 | `flutter test` green. Test-count check: the 8 original assertions all still exist, just relocated — none deleted. Signature change and test rewrite **must** be one commit (the old tests cannot compile against the new signature) |
| 5 | Add `lib/app_wiring.dart` (`UserscriptsState`, `AppWiring` with the 15 collaborators, `userscripts` notifier, `start`/`dispose`/`applyUserScripts`/`connectHeadersFor`, `bool _started` guard) and `lib/cookie_watcher.dart` (`CookieWatcher` + `cookies` notifier, owning the sole `flutter_inappwebview` import). **Pure addition — nothing consumes them yet** | A | CRS-04, CRS-09, CRS-10, CRS-11, CRS-12 | `flutter analyze apps/popmundo_app` clean; `flutter test` still green (nothing wired). Manual check: `grep -E 'BuildContext\|State<\|Navigator\|Widget ' lib/app_wiring.dart` returns nothing (CRS-04) |
| 6 | Rewire `main.dart` (builds `AppWiring`, moves the `FlutterSecureSecretStore()` default into it) and `app.dart` (`PopmundoApp`/`PopmundoHome` collapse to one `wiring` param; delete the 6 State fields plus `_onKeepaliveStatus`, `_onGmMenuChanged`, `_bootstrap`, `_applyUserScripts`, `_refreshCookies`, `_connectHeadersFor`; `build` uses `ValueListenableBuilder`/`ListenableBuilder`). `MaterialApp` **stays textually in `app.dart`** with the four scanned substrings byte-identical | A | CRS-01, CRS-03, CRS-08, CRS-13 | `flutter analyze` + full `flutter test` green — **especially `localization_boot_test.dart`** (source-text scan). `wc -l lib/app.dart` ≤ 180 (CRS-03). `git diff --stat` shows **zero** changes to the leaf-widget test files named in CRS-08 |
| 7 | New `test/app_wiring_test.dart` using `FakePopmundoRuntime` + `MemoryKeyValueStore`: `start()` bootstraps the catalog into the notifier; a second `start()` creates no duplicate subscriptions (CRS-10); `dispose()` cancels everything and is a no-op if `start()` never ran (CRS-11); `applyUserScripts` publishes the notifier and sets `previouslyEnabledIds` to exactly the enabled ids (CRS-12); `connectHeadersFor` returns a script's `@connect` list and `const []` for an unknown id; the two swallow points don't propagate (CRS-09) | A | CRS-09, CRS-10, CRS-11, CRS-12, CRS-14 | `flutter test test/app_wiring_test.dart` green. **Mutation proof:** removing the `previouslyEnabledIds` update in `_publishUserscripts` must make this file fail; revert after |
| 8 | Doc sync (below) + `AD-022` in `.specs/STATE.md` + Handoff update + mark CRS-01…18 `Verified` in `spec.md` | D | all | Reviewed for accuracy against what was actually built. No stale path or superseded claim left behind |

## Task 8 — exact doc surface

Verified references that go stale; each must be fixed:

| File | What changes |
| --- | --- |
| `docs/ARQUITETURA.md:75` | Delete the `**InheritedWidget**` pattern row (`PopmundoScope` expõe `runtime`/`storage`) |
| `docs/ARQUITETURA.md:255` | Delete the dead-code row `PopmundoScope sem call sites` — the dead code is gone, and its stated rationale is superseded by AD-022 |
| `docs/ARQUITETURA.md` — **Composition root** row | `main.dart` now builds `AppWiring` wholesale; `PopmundoHome` no longer instantiates collaborators |
| `docs/ARQUITETURA.md` — **Registro de menu** row | `buildAppMenuItems` only orders + gates debug; each feature owns its `AppMenuItem` |
| `docs/ARQUITETURA.md` — **Facade** row | Repath to `.../src/facades/{utils,notifications,scoring,css_selector}.dart` |
| `apps/popmundo_app/README.md:18` | Shell row: drop `PopmundoScope`, add `AppWiring` / `CookieWatcher` |
| `apps/popmundo_app/README.md:69` | Delete the bullet `PopmundoScope.of` **não tem call sites** |
| `apps/popmundo_app/README.md` — Responsabilidade principal / Fluxos importantes | Navigation/cookie/bootstrap flows are now `AppWiring`'s job, not `_PopmundoHomeState`'s |
| `apps/popmundo_app/lib/menu/README.md` — "Pontos de entrada" | Currently states *"Novo item nativo = nova entrada em `buildAppMenuItems` **somente**"* — now **wrong**. Rewrite to: item-builder function in the feature's own folder + one line in `app.dart`'s `items:` list |
| `apps/popmundo_app/lib/menu/README.md` — Funcionalidades table | Update the `app_menu_registry.dart` row; add `debug_menu_item.dart` |
| `apps/popmundo_app/lib/notifications/README.md` | Its "Pontos de entrada" section says `_PopmundoHomeState` starts the watcher/bridge in `initState`. T6 moves that to `AppWiring.start()` — repoint it |
| `packages/popmundo_utils/README.md` | Repath every `src/*.dart` cell in "Funcionalidades existentes" and "Arquivos críticos" to `src/core/…` / `src/facades/…` |
| `CLAUDE.md` | The bullet naming `apps/popmundo_app/lib/app.dart` as the direct `flutter_inappwebview` importer must point at `lib/cookie_watcher.dart` |
| `.claude/agents/popmundo-app-shell.md` **and** `.agents/agents/popmundo-app-shell.md` | File-ownership lists name `app.dart`; add `app_wiring.dart` and `cookie_watcher.dart` |
| `.claude/agents/popmundo-utils.md` **and** `.agents/agents/popmundo-utils.md` | Repath any `lib/src/*.dart` references |
| `.specs/STATE.md` | New **AD-022** covering all four items under one rationale; explicitly notes it supersedes the `PopmundoScope` "kept by design" note in `.specs/features/app-sidebar-menu/design.md`. Update Handoff |

`.specs/features/app-sidebar-menu/{design,tasks,validation}.md` are **not** edited — they are
historical execution records. That feature's `spec.md` never mentions `PopmundoScope`, so no
`SPEC_DEVIATION` marker is needed there.

---

**Requirement coverage check:** CRS-01…CRS-18 all mapped (T1→17; T2→18; T3→15,16; T4→02,05,06,07;
T5→04,09,10,11,12; T6→01,03,08,13; T7→09,10,11,12,14). **0 unmapped.**

**Full gate, run after T3, T6, T7 and once at the end:**

```bash
flutter pub get && \
flutter analyze packages/popmundo_utils && flutter analyze packages/popmundo_webview && flutter analyze apps/popmundo_app && \
(cd packages/popmundo_utils && dart test) && \
(cd packages/popmundo_webview && flutter test) && \
(cd apps/popmundo_app && flutter test && flutter analyze integration_test)
```

**Out of agent reach:** Gradle builds do not complete in the agent sandbox (`.specs/STATE.md`
Handoff, confirmed 3×), so Patrol and a real `flutter run` smoke stay with the user. The device tier
is structurally unaffected — under Patrol the test file is the Dart entrypoint, so `main.dart` never
runs and `AppWiring` is never constructed.

## Execution record

All tasks committed on `claude/project-architecture-scaling-530c6e`. Range `4ec5f50..HEAD`.

| # | Status | Commit |
| - | ------ | ------ |
| — | ✅ T0 — **pre-existing breakage**, not part of this feature: `4ec5f50` left `menu_notifications_bridge_test.dart` calling `Utils(runtime)` with 1 of 2 args and stubbing `evaluateHandler` for a name that now comes from `TimedFetch`+HTML. The app did not analyze and 2 tests failed on HEAD. Fixed with zero assertion changes; mutation-verified | `1ebf55b` |
| 1 | ✅ | `79afb10` |
| 2 | ✅ | `bcffa2d` |
| 3 | ✅ | `0449965` |
| 4 | ✅ | `25d3e89` |
| 5 | ✅ | `ee5c55a` |
| 6 | ✅ — CRS-03 missed (216 LOC vs ≤180), recorded in `spec.md` | `891b9db` |
| 7 | ✅ — 2 mutants injected and killed, both reverted | `e66dade` |
| 8 | ✅ — also fixed the root `README.md`, which the doc surface below had missed | `d4ccd21` |

Final gate: `flutter analyze` clean on all three packages **and** on `integration_test`;
`dart test` 216 (utils), `flutter test` 31 (webview) and 111 (app, up from 95).

Verifier: dispatched over `4ec5f50..HEAD`; report in `validation.md`.
