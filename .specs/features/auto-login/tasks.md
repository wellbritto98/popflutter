# Auto Login Tasks

**Spec**: `.specs/features/auto-login/spec.md`
**Design**: `.specs/features/auto-login/design.md`

---

## Test Coverage Matrix

> Guidelines found: `CLAUDE.md` / `AGENTS.md` (dart test / flutter test per package; FakePopmundoRuntime; no live popmundo.com e2e).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| TimedFetch / InPageFetchResult / AspNetForm / stores / AutoLoginController | unit | 1:1 to AUTH/NAV ACs + listed edges | `packages/popmundo_utils/test/**/*_test.dart` | `cd packages/popmundo_utils && dart test` |
| hooks.js / InAppPopmundoRuntime.loadUrl | unit | Location header + loadUrl fake/port | `packages/popmundo_webview/test/**/*_test.dart` | `cd packages/popmundo_webview && flutter test` |
| Menu registry / AutoLoginScreen / SecretStore wiring | unit/widget | UI-01–04; password not in KV; Save disabled | `apps/popmundo_app/test/**/*_test.dart` | `cd apps/popmundo_app && flutter test` |
| Live site e2e | none | Device UAT only | — | manual |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After utils tasks | `cd packages/popmundo_utils && dart test` |
| Full | After webview/app tasks | utils dart test + `flutter test` in webview and app |
| Build | Phase complete | above + `flutter analyze` on three packages |

---

## Execution Plan

### Phase 1 — Runtime contract + TimedFetch (popmundo-utils)

#### T1: Extend InPageFetchResult + PopmundoRuntime.loadUrl
- **Files**: `packages/popmundo_utils/lib/src/popmundo_runtime.dart`, `packages/popmundo_utils/test/fake_runtime.dart`
- **Reqs**: AUTH-03, NAV-02
- **Done when**: `headers`/`url` on result; abstract `loadUrl`; Fake records calls and updates host + emits navigation; existing compile
- **Verify**: `dart test` (fake still works for notifications)
- **Commit**: `feat(utils): add loadUrl and fetch headers to PopmundoRuntime`

#### T2: TimedFetch.fetchResponse with acceptRedirect
- **Files**: `packages/popmundo_utils/lib/src/timed_fetch.dart`, `packages/popmundo_utils/test/timed_fetch_test.dart`
- **Reqs**: AUTH-02, AUTH-03, AUTH-04
- **Done when**: `fetch()` unchanged; `fetchResponse` returns result; `acceptRedirect: true` allows 3xx; `useCache: false` forces network; queue still serial
- **Verify**: quick gate
- **Commit**: `feat(utils): add TimedFetch.fetchResponse for redirect-aware login`

### Phase 2 — Autologin domain (popmundo-utils)

#### T3: SecretStore + AutoLoginSettingsStore + LastUrlStore
- **Files**: `packages/popmundo_utils/lib/src/secret_store.dart`, `packages/popmundo_utils/lib/src/autologin/*.dart`, exports, tests
- **Reqs**: UI-03, NAV-03, NAV-04
- **Done when**: settings round-trip on MemoryKV; password API separate; last URL filter rejects auth paths; accepts Character/World paths
- **Verify**: unit tests for filter + settings
- **Commit**: `feat(utils): add AutoLogin settings, secrets contract, last-url store`

#### T4: AspNetForm parser
- **Files**: `packages/popmundo_utils/lib/src/autologin/aspnet_form.dart`, test
- **Reqs**: AUTH-02, NAV-01, NAV-05
- **Done when**: extracts VIEWSTATE trio; finds character buttons; matches Escolher/Choose + name
- **Verify**: unit tests with HTML fixtures
- **Commit**: `feat(utils): parse ASP.NET login and character form fields`

#### T5: AutoLoginController
- **Files**: `packages/popmundo_utils/lib/src/autologin/auto_login_controller.dart`, test
- **Reqs**: AUTH-01–06, NAV-01–02, NAV-05
- **Done when**: full happy path with fake runtime; 200 abort; missing creds skip; inFlight; character miss abort; restore last URL
- **Verify**: quick gate all utils tests
- **Commit**: `feat(utils): orchestrate AutoLoginController with TimedFetch`

### Phase 3 — WebView adapter (popmundo-webview)

#### T6: hooks.js redirect + Location header
- **Files**: `packages/popmundo_webview/assets/js/hooks.js`, related test if any
- **Reqs**: AUTH-03
- **Done when**: options passed through; JSON includes headers.location when present
- **Verify**: webview tests / manual contract assert in dart parse
- **Commit**: `feat(webview): expose Location header from in-page fetch`

#### T7: InAppPopmundoRuntime.loadUrl + parse headers
- **Files**: `packages/popmundo_webview/lib/src/in_app_runtime.dart`, tests
- **Reqs**: AUTH-03, NAV-02
- **Done when**: loadUrl uses controller; fetchInPage maps headers; Fake/tests green
- **Verify**: `flutter test` webview
- **Commit**: `feat(webview): implement loadUrl and map fetch headers`

### Phase 4 — App shell (popmundo-app-shell)

#### T8: Menu registry Auto Login item
- **Files**: `apps/popmundo_app/lib/menu/app_menu_registry.dart`, `test/app_menu_registry_test.dart`
- **Reqs**: UI-01
- **Done when**: item always present with includeDebugItem false; onOpenAutoLogin wired
- **Verify**: registry tests
- **Commit**: `feat(app): add Auto Login sidebar menu item`

#### T9: FlutterSecureStorage SecretStore + AutoLoginScreen
- **Files**: `apps/popmundo_app/pubspec.yaml`, `lib/autologin/*`, tests
- **Reqs**: UI-02–04
- **Done when**: screen saves settings; password only in secure store; Save disabled while saving
- **Verify**: widget tests
- **Commit**: `feat(app): Auto Login settings screen with secure password storage`

#### T10: Wire controller, last-url listener, initialUrl
- **Files**: `apps/popmundo_app/lib/app.dart`, tests if feasible
- **Reqs**: NAV-03, NAV-04, AUTH-01
- **Done when**: composition creates TimedFetch + controller; navigation updates LastUrlStore; WebView gets initialUrl from store after bootstrap
- **Verify**: full gate + analyze
- **Commit**: `feat(app): wire AutoLoginController and last-URL restore`

---

## Requirement → Task map

| ID | Tasks |
| -- | ----- |
| UI-01 | T8 |
| UI-02 | T9 |
| UI-03 | T3, T9 |
| UI-04 | T9 |
| AUTH-01 | T5, T10 |
| AUTH-02 | T2, T4, T5 |
| AUTH-03 | T1, T2, T6, T7, T5 |
| AUTH-04 | T5 |
| AUTH-05 | T5 |
| AUTH-06 | T5 |
| NAV-01 | T4, T5 |
| NAV-02 | T5, T7, T10 |
| NAV-03 | T3, T10 |
| NAV-04 | T3, T10 |
| NAV-05 | T4, T5 |

**Coverage:** 15 total, 15 mapped, 0 unmapped

## Sub-agent packing

~10 tasks → offer 2 batches: Phase1+2 (T1–T5 utils), Phase3+4 (T6–T10 webview+app). Or execute inline sequentially with specialist Task agents per phase.
