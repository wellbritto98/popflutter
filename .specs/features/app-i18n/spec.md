# App Shell Internationalization (EN + PT) Specification

## Problem Statement

Every user-visible string in the app shell (sidebar menu, Userscripts screen, Auto Login screen, Android keepalive notification) is hardcoded in English inside Dart code. Brazilian-Portuguese players — the primary audience of this wrapper — see a mixed experience: the Popmundo site in PT, the native shell in EN. The shell needs real i18n infrastructure (EN + PT initially) plus a manual language selector, before any further native UI is built on top.

## Goals

- [ ] All release-visible app-shell strings resolve from translation catalogs (EN + PT); zero hardcoded literals remain in release-visible UI code
- [ ] Device locale drives the initial language (pt\* → PT, anything else → EN fallback)
- [ ] User can manually switch EN/PT from the sidebar; the choice persists across app restarts
- [ ] Android keepalive notification title/text are localized
- [ ] Existing test suite stays green with a reusable localized-test harness

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| ------- | ------ |
| DebugOverlay internals ('host:', 'network', 'console', 'clear', 'run', hint) | User decision: dev-only tool stays English |
| `BackgroundStatus` telemetry labels ('running', 'granted', '12s ago'…) | Computed debug values, not UI copy; debug-only surface |
| `popmundo_utils`/`popmundo_webview` exception messages ('Download failed: …', 'Invalid URL'…) | AD-002: utils stays Flutter-free and locale-free; dynamic technical detail shown raw in snackbars |
| WebView/game content | The Popmundo site renders its own languages |
| Android launcher label (`android:label`) / iOS `CFBundleDisplayName` | Platform-level localization (res values / Info.plist per locale) — candidate for a later feature |
| Languages beyond EN/PT | "inicialmente somente Inglês e Português" |
| Plural/gender machinery | No current string needs it; catalog format already supports it later |
| "Follow system default" selector option | Selector offers EN/PT only (assumption A2); initial locale already follows the device |
| Userscript metadata (script name/description) | Data fetched from the web, not app copy |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here — nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| A1 — PT variant coverage | Single `pt.json` + `useOnlyLangCode: true` covers pt-BR and pt-PT devices | One catalog per language code; user base is overwhelmingly pt-BR; avoids duplicate catalogs | n (assumption) |
| A2 — Selector options | EN/PT only, no "system default" entry; device locale decides initial language | easy_localization persists explicit choices; a "system" reset adds restart semantics not worth it for MVP | n (assumption) |
| A3 — FGS channel name/description | Stay English constants | Android creates the notification channel once per install; renaming later has no effect on existing devices; title/text (per-service-start) ARE localized | n (assumption) |
| A4 — Package exception messages | Remain English, displayed raw | AD-002 keeps `popmundo_utils` Flutter/locale-free; messages carry dynamic technical detail (`$uri ($e)`) | n (assumption) |
| A5 — PT game-status terms | Best-effort translations: Ocupado, Celular, Ausente, Bêbado (Normal stays Normal) | Matches known Popmundo PT UI terms; live-site verification is excluded by repo policy | n (assumption) |
| A6 — Launcher label / display name | Not localized in this feature | Platform resources, not Flutter UI; deferred | n (assumption) |
| A7 — Debug panel language | DebugOverlay internals stay English | User decision (Discuss phase) | y |
| A8 — Keepalive timing vs translation load | `startService` runs only after `EasyLocalization` finishes loading (its child — and therefore `PopmundoHome.initState` — is built only after load); translator additionally falls back to bundled EN defaults | Guarantees `tr()` availability without awaiting anything new | n (assumption) |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Portuguese shell for PT users ⭐ MVP

**User Story**: As a Brazilian player, I want the native app shell (menu, Userscripts, Auto Login) in Portuguese so that the app feels consistent with the PT game site.

**Why P1**: Core reason this feature exists; release-visible UX for the primary audience.

**Acceptance Criteria**:

1. WHEN the app starts on a device whose locale language code is `pt` THEN the shell SHALL render every catalog-backed string in Portuguese.
2. WHEN the app starts on a device whose locale is `en` or any unsupported language THEN the shell SHALL render every catalog-backed string in English.
3. WHEN a translation key is missing from `pt.json` but present in `en.json` THEN the shell SHALL display the English value and SHALL never display the raw key.
4. WHEN the translation catalogs load THEN `MaterialApp` SHALL receive `localizationDelegates`, `supportedLocales`, and `locale` from the localization widget so Material widgets (dialogs, tooltips) are localized too.

**Independent Test**: Widget test pumping the shell with `startLocale: Locale('pt')` finds 'Login automático' / 'Nenhuma opção disponível.'; with `Locale('en')` finds 'Auto Login' / 'No options available.'.

### P1: Manual language selector ⭐ MVP

**User Story**: As a user, I want to choose between English and Portuguese in the sidebar so that I can override the device language.

**Why P1**: Explicitly requested (user chose "Adicionar seletor no sidebar" in Discuss).

**Acceptance Criteria**:

1. WHEN the sidebar is open THEN it SHALL show a "Language"/"Idioma" menu item (always visible — debug and release) that opens a dialog listing exactly English and Português.
2. WHEN the user picks Português THEN the whole shell SHALL immediately re-render in Portuguese without an app restart.
3. WHEN the user kills and restarts the app after choosing a language THEN the shell SHALL start in the chosen language (choice persisted).
4. WHEN the user picks the language already active THEN the dialog SHALL close and nothing SHALL break (idempotent).
5. WHEN the selector dialog is open THEN it SHALL mark the currently active language as selected.

**Independent Test**: Widget test opens the dialog, taps Português, asserts PT strings render; relaunch-style test (fresh pump with saved locale) asserts persistence.

### P2: Localized keepalive notification

**User Story**: As an Android user, I want the persistent "session keepalive" notification in my language so that OS-level UI matches the app.

**Why P2**: Visible in release, but secondary to in-app UI; depends on the same catalog.

**Acceptance Criteria**:

1. WHEN the keepalive foreground service starts under a PT locale THEN the notification SHALL show the PT title and text from the catalog.
2. WHEN it starts under EN (or before translations could be resolved) THEN the notification SHALL show the bundled English defaults.
3. WHEN the service starts THEN `channelId`/`channelName`/`channelDescription` SHALL remain the existing English constants.

**Independent Test**: `background_keepalive_test` with an injected translator asserts the strings passed to `startService`; fake platform captures them.

---

## Edge Cases

- WHEN device locale is unsupported (e.g. `fr`) THEN system SHALL fall back to English (fallbackLocale).
- WHEN the locale choice was persisted THEN a later device-language change SHALL NOT override the explicit user choice (easy_localization saved-locale precedence).
- WHEN translations fail to load at startup (asset missing/corrupt) THEN the app SHALL surface the localization library's error widget — accepted as fatal-by-design since the shell cannot render without strings; prevented in practice by bundled assets + test coverage.
- WHEN SharedPreferences is unavailable (some test/desktop bindings) THEN locale persistence SHALL degrade silently; the in-session locale still works.
- WHEN `tr()` is called before catalog load (race) THEN keepalive translator SHALL return bundled EN defaults, never a raw key.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| I18N-01 | P1: PT shell | Execute | Implementing |
| I18N-02 | P1: PT shell | Execute | Implementing |
| I18N-03 | P1: Selector | Execute | Implementing |
| I18N-04 | P2: Notification | Execute | Implementing |
| I18N-05 | P1: PT shell | Execute | Implementing |
| I18N-06 | P1: PT shell + Selector | Execute | Implementing |
| I18N-07 | P1: PT shell | Execute | Implementing |

**ID format:** `I18N-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 7 total, 7 to be mapped to tasks, 0 unmapped

---

## Success Criteria

- [ ] A pt-locale device renders the entire release-visible shell in Portuguese; en and unsupported locales render English
- [ ] Selector switches EN↔PT live and the choice survives app restart
- [ ] Grep sweep finds zero hardcoded user-visible literals left in release-visible shell UI
- [ ] `flutter analyze` clean on all three packages; `dart test` (utils) and `flutter test` (webview, app) all green
- [ ] `platform_config_test` asserts `CFBundleLocalizations` = [en, pt]

---

## Implicit-Requirement Dimensions Sweep (Large scope)

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | Selector exposes a fixed EN/PT list — no free-form locale input possible (I18N-03 AC1) |
| Failure / partial-failure states | Missing key → EN fallback, never raw key (I18N-05); catalog load failure → error widget, accepted fatal-by-design (Edge Cases) |
| Idempotency / retry / duplicate handling | Selecting the active locale is a no-op that closes the dialog (I18N-03 AC4) |
| Auth boundaries & rate limits | N/A because no auth surface, no game network calls touched |
| Concurrency / ordering | Translation load vs keepalive bootstrap ordering guaranteed by EasyLocalization build order + EN fallback in translator (A8) |
| Data lifecycle / expiry | Locale choice persisted via easy_localization `saveLocale` (shared_preferences), no expiry (I18N-03 AC3) |
| Observability | N/A because no new logging; library default logger retained |
| External-dependency failure | SharedPreferences unavailable → persistence degrades silently, session locale unaffected (Edge Cases) |
| State-transition integrity | Locale state = device default until first explicit choice; choice rebuilds tree once; no invalid state representable (I18N-03) |
