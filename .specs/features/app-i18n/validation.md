# App Shell Internationalization Validation

**Date**: 2026-08-18
**Spec**: `.specs/features/app-i18n/spec.md`
**Diff range**: `262911b..c86d5d2` (i18n commits; e2e commits between T1 and T2 ignored)
**Verifier**: independent sub-agent (author ≠ verifier)
**Iteration**: 2 of 3 (after FAIL on `0d4269a`)

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| T1   | ✅ Done | `easy_localization ^3.0.8`; `assets/translations/{en,pt}.json`; pubspec assets |
| T2   | ✅ Done | `l10n.dart`, EasyLocalization wrapper, MaterialApp locale wiring, `pumpLocalized`, boot smoke, `CFBundleLocalizations` |
| T3   | ✅ Done | Registry + sidebar empty state via `.tr()`; tests converted through harness |
| T4   | ✅ Done | `LanguageSelector` + always-visible `language` menu item |
| T5   | ✅ Done | Userscripts screen extracted; EN assertions preserved |
| T6   | ✅ Done | Auto Login screen extracted; EN status labels preserved |
| T7   | ✅ Done | Keepalive translator injection + EN-default fallback |
| T8   | ✅ Done | Build gate recorded green; residual-string sweep committed |
| Fix  | ✅ Done | `c86d5d2` — PT `AppSidebar` / registry assertions + missing-key EN fallback widget test |

---

## Spec-Anchored Acceptance Criteria

### P1: Portuguese shell for PT users (I18N-01, I18N-02, I18N-05, I18N-07)

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| AC1: WHEN the app starts on a device whose locale language code is `pt` THEN the shell SHALL render every catalog-backed string in Portuguese | Independent Test: pumping **the shell** with `startLocale: Locale('pt')` finds `'Login automático'` / `'Nenhuma opção disponível.'` | `app_sidebar_test.dart:132-144` — `pumpLocalized(..., startLocale: Locale('pt'))` of real `AppSidebar(items: [])`; `expect(find.text('Nenhuma opção disponível.'), findsOneWidget)`; `expect(find.text('No options available.'), findsNothing)`. `app_menu_registry_test.dart:137-156` — PT pump then `buildAppMenuItems`; `expect(..., 'Login automático')`; `expect(..., 'Idioma')`. Catalog probe remains at `localization_boot_test.dart:31-33`. | ✅ PASS |
| AC2: WHEN the app starts on `en` or any unsupported language THEN the shell SHALL render every catalog-backed string in English | EN copy from catalog; unsupported → `fallbackLocale` English | EN: `localization_boot_test.dart:26-28` — `expect(find.text('No options available.'), findsOneWidget)`; `app_menu_registry_test.dart:20` — `expect(items.first.label, 'Auto Login')`; `app_sidebar_test.dart:128` — `expect(find.text('No options available.'), findsOneWidget)` on the real empty `AppSidebar`. Unsupported: `localization_boot_test.dart:36-41` — `expect(supportedAppLocales, const [Locale('en'), Locale('pt')])`; `expect(fallbackAppLocale, const Locale('en'))`; `expect(_localeForLanguageCode('fr'), const Locale('en'))`; `:44-53` — production `main.dart` sets `fallbackLocale: fallbackAppLocale`, omits `startLocale`. | ✅ PASS |
| AC3: WHEN a translation key is missing from `pt.json` but present in `en.json` THEN the shell SHALL display the English value and SHALL never display the raw key | Rendered string = EN catalog value `'No options available.'`; raw key `'menu.empty'` absent | `localization_boot_test.dart:72-84` — `_PtMissingMenuEmptyLoader` strips `menu.empty` from PT; `expect(find.text('No options available.'), findsOneWidget)`; `expect(find.text('menu.empty'), findsNothing)`; `expect(find.text('Nenhuma opção disponível.'), findsNothing)`. Wiring: `:50` — `expect(source.contains('useFallbackTranslations: true'), isTrue)` in `main.dart`. | ✅ PASS |
| AC4: WHEN the translation catalogs load THEN `MaterialApp` SHALL receive `localizationDelegates`, `supportedLocales`, and `locale` from the localization widget | Exact wiring from EasyLocalization context | `localization_boot_test.dart:55-69` — `expect(source.contains('localizationsDelegates: context.localizationDelegates'), isTrue)`; `supportedLocales: context.supportedLocales`; `locale: context.locale`; `title: 'app.title'.tr()`. Matches spec-defined assignments. | ✅ PASS |

### P1: Manual language selector (I18N-03)

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| AC1: WHEN the sidebar is open THEN it SHALL show a "Language"/"Idioma" menu item (always visible — debug and release) that opens a dialog listing exactly English and Português | Item present in release (`includeDebugItem: false`) and debug; dialog lists exactly those two endonyms | `app_menu_registry_test.dart:19` — `expect(items.map((e) => e.id), ['auto-login', 'userscripts', 'language'])` with `includeDebugItem: false`; `:40-41` debug path still includes `'language'`; `:134` — `expect(..., 'Language')`; `:156` — PT `'Idioma'`. Dialog: `language_selector_test.dart:36-40` — keys `language-dialog` / `language-option-en` / `language-option-pt`; `expect(find.text('English'), findsOneWidget)`; `expect(find.text('Português'), findsOneWidget)`. | ✅ PASS |
| AC2: WHEN the user picks Português THEN the whole shell SHALL immediately re-render in Portuguese without an app restart | PT string appears, EN counterpart gone, dialog closed | `language_selector_test.dart:64-74` — after tap `language-option-pt`: `expect(find.byKey(const Key('language-dialog')), findsNothing)`; `expect(find.text('Login automático'), findsOneWidget)`; `expect(find.text('Auto Login'), findsNothing)`. | ✅ PASS |
| AC3: WHEN the user kills and restarts the app after choosing a language THEN the shell SHALL start in the chosen language | Independent Test: fresh pump with saved locale renders PT | `language_selector_test.dart:77-84` — `pumpLocalized(..., startLocale: const Locale('pt'))`; `expect(find.text('Login automático'), findsOneWidget)`. Matches the spec's own Independent Test shape (not a live SharedPreferences round-trip; prod `saveLocale` defaults `true` in easy_localization 3.0.8). | ✅ PASS |
| AC4: WHEN the user picks the language already active THEN the dialog SHALL close and nothing SHALL break | Dialog gone; EN strings still render | `language_selector_test.dart:93-101` — tap `language-option-en` (already active); `expect(find.byKey(const Key('language-dialog')), findsNothing)`; `expect(find.text('Auto Login'), findsOneWidget)`. | ✅ PASS |
| AC5: WHEN the selector dialog is open THEN it SHALL mark the currently active language as selected | `groupValue` equals active language code | `language_selector_test.dart:42-45` — `expect(group.groupValue, 'en')` under EN; `:87-90` — `expect(group.groupValue, 'pt')` under PT. | ✅ PASS |

### P2: Localized keepalive notification (I18N-04)

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| AC1: WHEN the keepalive foreground service starts under a PT locale THEN the notification SHALL show the PT title and text from the catalog | Independent Test: injected translator → captured `startService` strings | `background_keepalive_test.dart:186-190` — `expect(platform.lastNotificationTitle, 'Popmundo está em execução')`; `expect(platform.lastNotificationText, 'Mantendo sua sessão ativa em segundo plano.')` (values match `pt.json` `keepalive.*`). | ✅ PASS |
| AC2: WHEN it starts under EN (or before translations could be resolved) THEN the notification SHALL show the bundled English defaults | Title `'Popmundo is running'`; text `'Keeping your session alive in the background.'` | No translator: `background_keepalive_test.dart:27-31` — `expect(platform.lastNotificationTitle, 'Popmundo is running')`; `expect(platform.lastNotificationText, 'Keeping your session alive in the background.')`. Unresolved key (`translator: (key) => key`): `:206-210` — same EN defaults. | ✅ PASS |
| AC3: WHEN the service starts THEN `channelId`/`channelName`/`channelDescription` SHALL remain the existing English constants | `'popmundo_keepalive'` / `'Session keepalive'` / English description | Source-verified `flutter_foreground_task_platform.dart:48-51` — literals unchanged. No dedicated test assertion (unlike `stopWithTask` in `platform_config_test.dart`). Structural remainder, not a behavior gap. | ✅ PASS (source-verified) |

**Status**: ✅ All ACs covered — 12/12 ACs spec-anchored PASS, 0 spec-precision gaps

---

## Discrimination Sensor

Scratch: `git worktree add` at `c86d5d2` (`C:\Users\Wellington\Documents\projetos\popflutter-i18n-verify-2`). Real working tree not mutated. Worktree removed after the run.

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1        | `language_selector.dart:51-53` | Skipped `context.setLocale` (`if (false && …)`) so picking PT only pops the dialog | ✅ Killed — `language_selector_test.dart:73` (`Login automático` not found) |
| 2        | `localization_helpers.dart:51` | Disabled fallback on the missing-key test path (`useFallbackTranslations: false`) | ✅ Killed — `localization_boot_test.dart:81` expected `'No options available.'`, found 0; library warned `Localization key [menu.empty] not found` |
| 3        | `app_sidebar.dart:28` | Replaced `'menu.empty'.tr()` with hardcoded `'No options available.'` | ✅ Killed — `app_sidebar_test.dart:143` expected `'Nenhuma opção disponível.'`, found 0 |

**Sensor depth**: lightweight (3 targeted behavior-level mutations)
**Result**: 3/3 killed — PASS ✅

Mutant 3 is the iteration-1 survivor. The new PT `AppSidebar` test now fails when empty-state copy is hardcoded English.

---

## Interactive UAT Results (if performed)

| #   | Test | Result | Details |
| --- | ---- | ------ | ------- |
| —   | Interactive UAT | ⏭️ Skip | Deferred to orchestrator (automated verification only) |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns | ✅ |
| Spec-anchored outcome check (asserted values match spec) | ✅ Independent Test strings asserted on `AppSidebar` / registry; missing-key path asserts the EN catalog value and `findsNothing` on the raw key |
| Per-layer Coverage Expectation met (domain 1:1 ACs; routes happy+edge+error) | ✅ Widget layer covers PT shell empty-state, PT registry labels, missing-key fallback, selector, keepalive translator |
| Every test maps to a spec requirement — no unclaimed tests | ✅ In-scope files map to I18N ACs, listed edges, Done-when, or pre-existing MENU/UI ACs kept green via the harness (I18N-06) |
| Documented guidelines followed: `CLAUDE.md` (per-package analyze/test; fakes over real WebViews); `.agents/agents/popmundo-app-shell.md` (app `flutter test` gate; keep `platform_config_test.dart` green) | ✅ |

---

## Edge Cases

- [x] Unsupported device locale (`fr`) → English `fallbackLocale`: contract-covered (`supportedAppLocales` / `fallbackAppLocale` / omitted `startLocale` in `main.dart`). Not a widget pump of `Locale('fr')` — T2 correctly notes `startLocale: Locale('fr')` would try to load `fr.json`.
- [ ] Persisted choice not overridden by a later device-language change: no automated evidence (library `saveLocale: true` default confirmed in easy_localization 3.0.8; harness uses `saveLocale: false`). Accepted as library-default, not an AC gap.
- [x] Catalog load failure → library error widget: accepted fatal-by-design in spec; assets bundled.
- [ ] SharedPreferences unavailable → persistence degrades silently: library behavior, no app-level test.
- [x] `tr()` before catalog load (keepalive race) → bundled EN defaults: `background_keepalive_test.dart:195-213`.
- [x] Missing PT key present in EN → English value, never raw key: `localization_boot_test.dart:72-84`.

---

## Gate Check

- **Gate command**: `flutter analyze` ×3 (`packages/popmundo_utils`, `packages/popmundo_webview`, `apps/popmundo_app`); `cd packages/popmundo_utils ; dart test`; `cd packages/popmundo_webview ; flutter test`; `cd apps/popmundo_app ; flutter test`
- **Result**: analyze clean (0 issues ×3); **102 + 24 + 71 = 197** passed, **0** failed, **0** skipped
- **Test count before feature**: 55 app / 102 utils / 24 webview (tasks.md baseline)
- **Test count after T8**: 68 app / 102 utils / 24 webview
- **Test count after fix (`c86d5d2`)**: 71 app / 102 utils / 24 webview
- **Delta**: **+16** app tests vs baseline (**+3** vs T8: PT sidebar, PT registry, missing-key fallback). No deletions; EN assertions on converted screens preserved.
- **Skipped tests**: none
- **Failures**: none
- **Success criterion `CFBundleLocalizations` = [en, pt]**: `platform_config_test.dart:63-70` — `expect(plist.contains('CFBundleLocalizations'), isTrue)`; `contains('<string>en</string>')`; `contains('<string>pt</string>')`

---

## Fix Plans (if issues found)

None. Iteration-1 Fix 1 (PT shell widgets) and Fix 2 (runtime missing-key fallback) are verified; mutant 3 is killed.

---

## Requirement Traceability Update

Update spec.md requirement statuses (recommendation only — Verifier does not edit spec.md):

| Requirement | Previous Status | New Status   |
| ----------- | --------------- | ------------ |
| I18N-01     | ❌ Needs Fix    | ✅ Verified  |
| I18N-02     | ✅ Verified     | ✅ Verified  |
| I18N-03     | ✅ Verified     | ✅ Verified  |
| I18N-04     | ✅ Verified     | ✅ Verified  |
| I18N-05     | ❌ Needs Fix    | ✅ Verified  |
| I18N-06     | ✅ Verified     | ✅ Verified  |
| I18N-07     | ✅ Verified     | ✅ Verified  |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 12/12 ACs matched spec outcome | 0 spec-precision gaps
**Sensor**: 3/3 mutations killed
**Gate**: 197 passed, 0 failed

**What works**: EasyLocalization boots with EN/PT catalogs; real `AppSidebar` empty state and registry labels render PT Independent Test strings; missing PT key falls back to the EN catalog value without showing the raw key; selector live-switch, idempotent re-select, and active-marking; keepalive translator + unresolved-key EN defaults; MaterialApp locale wiring; iOS `CFBundleLocalizations`; existing EN screen tests stay green through `pumpLocalized`; full build gate green.

**Issues found**: none

**Next steps**: Interactive UAT remains deferred to the orchestrator. No lessons recorded (clean PASS, no surviving mutants, no spec-precision gaps, no failed ACs, no `SPEC_DEVIATION`).
