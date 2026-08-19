# App Shell Internationalization (EN + PT) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/app-i18n/design.md`
**Status**: Approved

**Baseline (pre-feature, all green):** popmundo_app 55 tests · popmundo_utils 102 tests · popmundo_webview 24 tests.

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec — confirm before Execute. Guidelines found: `CLAUDE.md` (per-package analyze/test commands; no live-site e2e; fakes over real WebViews) and `.agents/agents/popmundo-app-shell.md` (gate = `flutter test` in the app; keep `platform_config_test.dart` green when touching manifest/plist).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| App shell widgets (menu, sidebar, screens, selector) | widget | All spec ACs 1:1 + every listed edge case; key-based finders preserved; EN assertions deterministic regardless of host locale | `apps/popmundo_app/test/*_test.dart` | `cd apps/popmundo_app && flutter test` |
| Background orchestration (`BackgroundKeepalive`/`BackgroundPlatform`) | widget/unit | All branches of changed API: defaults without translator, translated with translator, unresolved-key fallback | `apps/popmundo_app/test/background_keepalive_test.dart` | same as above |
| Platform config files (Info.plist/manifest) | unit (file-content asserts) | Every platform string this feature adds is asserted | `apps/popmundo_app/test/platform_config_test.dart` | same as above |
| Translation catalogs (assets) | none (validated via T2 EN/PT boot smoke) | Key sets identical across locales; render-verified by boot tests | `assets/translations/*.json` | covered by quick gate |
| Packages `popmundo_utils`/`popmundo_webview` | existing suites | Unchanged by this feature — must stay green (no locale added) | `packages/*/test` | `cd packages/popmundo_utils && dart test` · `cd packages/popmundo_webview && flutter test` |

## Gate Check Commands

> Generated from codebase — confirm before Execute.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After each app-shell task | `cd apps/popmundo_app && flutter test` |
| Full | After T7 (touches background layer contracts) | quick + `cd packages/popmundo_webview && flutter test` |
| Build | After T1, T8 (config/asset or phase completion) | `flutter analyze packages/popmundo_utils`, `flutter analyze packages/popmundo_webview`, `flutter analyze apps/popmundo_app`, `cd packages/popmundo_utils && dart test`, full gate |

---

## Execution Plan

Phases are ordered and run sequentially — each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Foundation

```
T1 → T2
```

### Phase 2: UI Extraction

```
T3 → T4 → T5 → T6 → T7
```

### Phase 3: Closure

```
T8
```

**Batch packing:** 8 tasks total ≤ single ~7-8 task budget → **inline execution** (no batch sub-agents). Verifier sub-agent still runs automatically after T8.

---

## Task Breakdown

### T1: Dependency + EN/PT translation catalogs

**What**: Add `easy_localization: ^3.0.8` to popmundo_app dependencies, create the complete `assets/translations/en.json` + `pt.json` (key schema from design.md, including all strings inventoried for menu/sidebar/userscripts/autologin/keepalive + common + language dialog), declare `assets/translations/` in pubspec, `flutter pub get` at repo root.
**Where**: `apps/popmundo_app/pubspec.yaml`, `apps/popmundo_app/assets/translations/en.json`, `apps/popmundo_app/assets/translations/pt.json`
**Depends on**: None
**Reuses**: existing `flutter.assets` declaration pattern (`assets/popflutter_logo.png`)
**Requirement**: I18N-02, I18N-05

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [x] `flutter pub get` resolves the workspace with easy_localization 3.0.8
- [x] Both JSON files parse; key sets identical across en/pt (verify with a throwaway Dart/pwsh comparison — not committed)
- [x] PT copy follows spec assumptions (status terms per A5; endonyms identical)
- [x] Gate check passes: build gate — `flutter analyze apps/popmundo_app` clean
- [x] Test count: 55 app tests still pass (no behavior change yet)

**Tests**: none (asset/config layer — render-validated by T2 boot smoke)
**Gate**: build

**Commit**: `feat(i18n): add easy_localization dependency and en/pt translation catalogs`

---

### T2: Composition-root wiring + iOS locales + test harness + boot smoke

**What**: (a) `lib/l10n.dart` (new): `const supportedAppLocales = [Locale('en'), Locale('pt')]` + `kTranslationsPath = 'assets/translations'`. (b) `main.dart`: `await EasyLocalization.ensureInitialized()` + wrap `PopmundoApp` in `EasyLocalization(supportedLocales, path, useOnlyLangCode: true, fallbackLocale: Locale('en'), useFallbackTranslations: true, child: ...)`. (c) `app.dart`: MaterialApp `localizationsDelegates: context.localizationDelegates`, `supportedLocales: context.supportedLocales`, `locale: context.locale`, `title: 'app.title'.tr()`. (d) Info.plist: `CFBundleLocalizations` [en, pt]. (e) `test/localization_helpers.dart`: `pumpLocalized` harness per design (forced `startLocale: en` default, `saveLocale: false`, mock SharedPreferences, pumpAndSettle). (f) `test/localization_boot_test.dart`: boot smoke — catalog renders EN under `Locale('en')` and PT under `Locale('pt')` (probe key `menu.empty`). (g) `platform_config_test.dart`: assert CFBundleLocalizations contains en and pt.
**Where**: `apps/popmundo_app/lib/l10n.dart` (new), `lib/main.dart`, `lib/app.dart`, `ios/Runner/Info.plist`, `test/localization_helpers.dart` (new), `test/localization_boot_test.dart` (new), `test/platform_config_test.dart`
**Depends on**: T1
**Reuses**: composition-root ordering (AD-002), platform_config_test assertion style
**Requirement**: I18N-01, I18N-05, I18N-06, I18N-07

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [x] App boots through the EasyLocalization wrapper (harness proves catalogs load)
- [x] Boot smoke: EN probe 'No options available.' and PT probe 'Nenhuma opção disponível.' both render via `menu.empty`
- [x] Unsupported-locale edge covered: `startLocale: Locale('fr')` is a library override (loads `fr.json`), not the device path — covered via omitted `startLocale` + `fallbackLocale` + supported-list contract (`fr` → `en`)
- [x] Info.plist declares CFBundleLocalizations; platform_config_test asserts it
- [x] Gate check passes: `cd apps/popmundo_app && flutter test`
- [x] Test count: 61 tests pass (55 baseline + 2 boot smoke + 1 config + 3 AC2/AC4 wiring; no deletions)

**Tests**: widget (boot smoke) + unit (platform config)
**Gate**: quick

**Commit**: `feat(i18n): wire EasyLocalization at composition root with localized test harness`

---

### T3: Menu registry + sidebar string extraction

**What**: `buildAppMenuItems` labels/subtitles resolve via `.tr()` (keys `menu.*`); `AppSidebar` empty-state text `'menu.empty'.tr()`. No signature change yet (language item arrives in T4).
**Where**: `apps/popmundo_app/lib/menu/app_menu_registry.dart`, `lib/menu/app_sidebar.dart`, tests: `test/app_menu_registry_test.dart` (convert to widget tests through harness), `test/app_sidebar_test.dart` (wrap via harness)
**Depends on**: T2
**Reuses**: harness from T2; registry pattern unchanged otherwise
**Requirement**: I18N-02, I18N-06

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [x] No literal label/subtitle remains in the registry; sidebar empty state localized
- [x] Registry tests run through the harness and still assert EN labels ('Auto Login', 'Debug panel', ids, onTap wiring, kDebugMode default)
- [x] Sidebar tests green through harness (labels, subtitles, 'No options available.')
- [x] Gate check passes: quick gate
- [x] Test count: 61 tests pass (conversions, no deletions)

**Tests**: widget
**Gate**: quick

**Commit**: `feat(i18n): localize sidebar menu registry and empty state`

---

### T4: LanguageSelector + language menu item

**What**: `lib/language/language_selector.dart` (new): `showLanguageDialog(BuildContext)` — AlertDialog (key `language-dialog`), RadioListTile per locale (keys `language-option-en`/`language-option-pt`), endonym labels, groupValue `context.locale.languageCode`, select → `await context.setLocale(locale)` + pop; idempotent re-select. Registry: add `required VoidCallback onOpenLanguage` + always-visible item `id: 'language'` (icon `Icons.language`, keys per existing pattern) placed before the debug-gated item. `app.dart`: `_openLanguage` wiring.
**Where**: `apps/popmundo_app/lib/language/language_selector.dart` (new), `lib/menu/app_menu_registry.dart`, `lib/app.dart`, tests: `test/language_selector_test.dart` (new), `test/app_menu_registry_test.dart` (language item + callback)
**Depends on**: T3
**Reuses**: dialog/key patterns from userscripts_screen; `supportedAppLocales` from T2
**Requirement**: I18N-03

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [x] Dialog lists exactly English/Português and marks the active locale
- [x] Selecting PT re-renders shell strings live (test asserts a PT label after tap, no restart)
- [x] Choice persists: re-pump with saved-locale semantics asserted via harness (saveLocale path) or documented test-double equivalent — must demonstrate I18N-03 AC3 at behavior level (startLocale simulating the saved value is acceptable evidence)
- [x] Re-selecting active locale closes dialog without error (AC4)
- [x] Registry test: with `includeDebugItem: false` ids are [auto-login, userscripts, language]; onTap invokes callback once
- [x] Gate check passes: quick gate
- [x] Test count: 66 tests pass (61 + 4 selector + 1 registry language item)

**Tests**: widget
**Gate**: quick

**Commit**: `feat(i18n): add sidebar language selector for EN/PT`

---

### T5: Userscripts screen string extraction

**What**: Replace all literals in `userscripts_screen.dart` with `tr()` keys (`userscripts.*` + `common.*`): appbar title, add tooltip/button, empty state, snackbar `'userscripts.imported'.tr(args: [name])`, delete dialog title/content (args: script name), Cancel/Delete/Import, URL label. Keep `https://example.com/script.user.js` hint literal (format example, not copy). Keys on widgets unchanged.
**Where**: `apps/popmundo_app/lib/userscripts/userscripts_screen.dart`, `test/userscripts_screen_test.dart` (pump via harness; EN assertions unchanged incl. "Imported 'Hello UI'")
**Depends on**: T4
**Reuses**: harness; existing snackbar/dialog keys
**Requirement**: I18N-02, I18N-06

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [x] No literal UI copy remains in the screen (example-URL hint excepted)
- [x] All 9 existing userscripts tests green through harness with unchanged EN expectations
- [x] Gate check passes: quick gate
- [x] Test count: 66 (unchanged vs T4; conversions only)

**Tests**: widget
**Gate**: quick

**Commit**: `feat(i18n): localize userscripts screen`

---

### T6: Auto Login screen string extraction

**What**: Replace all literals in `auto_login_screen.dart` with `tr()` keys (`autologin.*` + `common.save`): appbar, switch title/subtitle, field labels, both password helper texts, clear-password tooltip, character helper, Status label, saved snackbar, `'autologin.saveFailed'.tr(args: ['$e'])`. `_statusOptions` becomes value+key records; dropdown renders `.tr()` labels (en: Normal/Busy/Mobile/Away/Drunk; pt per A5).
**Where**: `apps/popmundo_app/lib/autologin/auto_login_screen.dart`, `test/auto_login_screen_test.dart` (pump via harness; EN assertions unchanged)
**Depends on**: T5
**Reuses**: harness; existing keys incl. `autologin-status-N`
**Requirement**: I18N-02, I18N-06

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [ ] No literal UI copy remains in the screen
- [ ] All 5 existing autologin tests green through harness (status dropdown EN labels still asserted)
- [ ] Gate check passes: quick gate
- [ ] Test count: unchanged vs T5 (conversions only)

**Tests**: widget
**Gate**: quick

**Commit**: `feat(i18n): localize auto login screen`

---

### T7: Keepalive notification localization

**What**: `BackgroundPlatform.startService({required notificationTitle, required notificationText})`; `FlutterForegroundTaskPlatform` passes them through (channel constants stay English — A3); `BackgroundKeepalive({translator})` + `_localize(key, enDefault)` treating null-or-same-as-key as unresolved; EN defaults as consts; composition root injects `(key) => key.tr()`; `FakeBackgroundPlatform` captures params.
**Where**: `apps/popmundo_app/lib/background/background_platform.dart`, `lib/background/background_keepalive.dart`, `lib/background/flutter_foreground_task_platform.dart`, `lib/main.dart`, `test/fake_background_platform.dart`, `test/background_keepalive_test.dart`
**Depends on**: T6
**Reuses**: existing bootstrap flow; fake platform pattern
**Requirement**: I18N-04

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [ ] With translator injected, startService receives catalog strings (test: translator returning PT values → captured PT title/text)
- [ ] Without translator, bundled EN defaults used (existing tests adapted, behavior preserved)
- [ ] Unresolved key (translator returns the key) falls back to EN default (A8 race)
- [ ] `stopWithTask` assertions in platform_config_test still green (unrelated behavior untouched)
- [ ] Gate check passes: full gate (quick + webview package tests)
- [ ] Test count: ≥ previous + 2 (translator injection + fallback), no deletions

**Tests**: widget/unit
**Gate**: full

**Commit**: `feat(i18n): localize keepalive foreground notification`

---

### T8: Full gate + residual-string sweep + handoff update

**What**: (a) Build gate across all three packages (analyze ×3, dart test utils 102, flutter test webview 24, flutter test app). (b) Grep sweep over `apps/popmundo_app/lib/**` for remaining user-visible literals in release-visible UI (regex for quoted strings in widget params: `Text(`, `tooltip`, `labelText`, `hintText`, `title`, `SnackBar`); allowed remainders: debug overlay internals (A7), BackgroundStatus labels, technical constants (channel id/name, keys, asset paths, example URL), identifiers. Fix any real find and add the key to both catalogs. (c) Update `.specs/STATE.md` Handoff: app-i18n Execute complete, Verifier pending.
**Where**: repo-wide gates; `apps/popmundo_app/lib/**`; `.specs/STATE.md`
**Depends on**: T7
**Reuses**: gate commands from CLAUDE.md
**Requirement**: I18N-06 (all requirements verified green)

**Tools**: MCP: NONE · Skill: tlc-spec-driven

**Done when**:

- [ ] Build gate green (all commands above; counts recorded)
- [ ] Sweep output reviewed; zero unjustified literals remain (each remainder mapped to an Out-of-Scope/assumption row)
- [ ] STATE.md Handoff updated (targeted edit, Decisions untouched)
- [ ] Gate check passes: build gate

**Tests**: none new (gate task)
**Gate**: build

**Commit**: `chore(i18n): full gate pass and residual string sweep`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Verifier (orchestrator)

Phase 1:  T1 ──→ T2
Phase 2:  T3 ──→ T4 ──→ T5 ──→ T6 ──→ T7
Phase 3:  T8
```

Execution is strictly sequential — there is no intra-phase parallelism. After T8 commits, the orchestrator dispatches the fresh Verifier sub-agent (spec-anchored check + discrimination sensor → `validation.md`).

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: dependency + catalogs | 1 concept (data + dep), 3 files | ✅ Cohesive |
| T2: wiring + harness + boot smoke | 1 concept (bootstrap), verified by its own smoke | ✅ Cohesive |
| T3: registry + sidebar extraction | 1 surface (menu) | ✅ Granular |
| T4: language selector + item | 1 component + wiring | ✅ Granular |
| T5: userscripts extraction | 1 screen | ✅ Granular |
| T6: autologin extraction | 1 screen | ✅ Granular |
| T7: keepalive notification | 1 behavior across 3 files | ✅ Cohesive |
| T8: gate + sweep | 1 verification pass | ✅ Granular |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | Phase 1 start | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 (phase boundary) | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T7 | T7 → T8 (phase boundary) | ✅ Match |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | asset catalogs + pubspec (config) | none (validated by T2 smoke) | none | ✅ OK |
| T2 | composition root (app shell) + platform config | widget + unit | widget (boot smoke) + unit (config test) | ✅ OK |
| T3 | menu registry + sidebar (app shell widgets) | widget | widget | ✅ OK |
| T4 | language selector (app shell widget) | widget | widget | ✅ OK |
| T5 | userscripts screen (app shell widget) | widget | widget | ✅ OK |
| T6 | autologin screen (app shell widget) | widget | widget | ✅ OK |
| T7 | background orchestration | widget/unit | widget/unit | ✅ OK |
| T8 | none (verification + docs) | none | none | ✅ OK |
