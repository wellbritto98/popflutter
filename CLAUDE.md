# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Popflutter is a Flutter (Android + iOS) wrapper around the web game [Popmundo](https://www.popmundo.com), built on `flutter_inappwebview`. The game's own web UI is the main UI — the app doesn't recreate it. The app observes network/console/navigation from the page, persists cookies, and offers a Dart utility library ported from [Popmundo-Utils `common/`](https://github.com/ilpersi/Popmundo-Utils) (GPL-3) so future features can be built without reimplementing that Chrome extension.

Full architecture/product docs (generated from source analysis): `docs/ARQUITETURA.md` and `docs/OBJETIVO.md`. Per-module `README.md` files live next to the code they describe (packages, app shell areas, `integration_test/`, `.specs/`). See `docs/README.md` for the index.

### Documentation maintenance — keep docs in lockstep with the code

These documents are the official Spec Driven Development baseline. **When a change alters architecture, product intent, module responsibility, public APIs, dependency direction, storage keys, documented flows, or feature scope, the same change MUST update the matching docs in the same work.** Do not leave `docs/` or module READMEs describing behavior the code no longer has.

Update, when relevant:

- `docs/ARQUITETURA.md` — patterns, rules, module communication, couplings, critical dependencies
- `docs/OBJETIVO.md` — purpose, actors, business flows, in/out of scope
- Root `README.md` — package table and high-level usage
- The `README.md` of every module/folder whose responsibility, entry points, dependencies, or critical files changed
- `.specs/features/<id>/spec.md` (and design/context if they exist) when the implemented behavior diverges — fix the spec or mark SPEC_DEVIATION; do not leave stale Goals
- `.specs/STATE.md` Decisions when the change is a cross-cutting architectural choice (via `tlc-spec-driven` memory)

Never invent behavior in docs. Mark inferences as **Hipótese**. Keep global docs and local READMEs consistent with each other and with `STATE.md` ADs. After Execute, documentation sync is part of finishing the feature (see the `tlc-spec-driven` skill), not an optional follow-up.

## Feature workflow — use the `tlc-spec-driven` skill

This repo's `.specs/` tree is not incidental documentation — it's the persisted state of the `tlc-spec-driven` skill (`.claude/skills/tlc-spec-driven/`), which owns all feature planning, implementation, and verification here. **Invoke that skill (`/tlc-spec-driven`, or let it trigger naturally on "specify feature", "design", "tasks", "implement", "validate", "resume work", etc.) for any non-trivial feature work instead of freelancing an ad-hoc plan.** Its 4-phase pipeline (Specify → Design → Tasks → Execute, auto-sized to scope) is what produced everything under `.specs/`:

- `.specs/STATE.md` — decision log (AD-001…AD-018; AD-011 and AD-017 are superseded) + handoff snapshot. Read the Decisions section before changing cross-package contracts (`PopmundoRuntime`, the JS bridge message shape, host-sticky resolution, Auto Login transport, GM host APIs, etc.) — it records the *why* behind choices that aren't obvious from the code alone. On "resume work", this file's Handoff section is the skill's own entry point.
- `.specs/features/popmundo-wrapper/` — `spec.md` (requirements with traceable IDs), `context.md` (resolved gray-area decisions), `design.md` (architecture/components), `tasks.md`, `validation.md` (Verifier report) for the wrapper feature already implemented. Treat this as the canonical example of the skill's output shape for this repo.
- `.specs/LESSONS.md` / `.specs/lessons.json` — self-improving lessons distilled from past verification gaps; the skill loads confirmed lessons at Specify/Design. Don't hand-edit `LESSONS.md` — it's rendered from `lessons.json` by `scripts/lessons.py`.

New features, bug fixes with any ambiguity, or changes touching more than one package should go through Specify at minimum; the skill auto-skips Design/Tasks for small/medium scope. Execute always ends with an independent Verifier pass (author ≠ verifier) — don't hand-roll a substitute verification step.

## Specialist agents — use them for their area, don't freelance

Six domain-specialist agents exist for this repo, defined at `.agents/agents/*.md` (Cursor) and mirrored under `.claude/agents/` for Claude Code's Agent tool. **Whenever a change falls inside one of their areas, invoke that agent instead of editing directly** — each one carries a file-ownership list, non-negotiable rules, and lessons from past mistakes that aren't otherwise obvious from the code alone.

| Agent | Area | Touch it when |
| ----- | ---- | -------------- |
| `popmundo-utils` | Pure-Dart core: `PopmundoRuntime` contract, `TimedFetch`, `HostTracker`, `Notifications`, `Storage`/`KeyValueStore`, `CssSelectorHelper`, `Scoring`, `Logger` | Editing `packages/popmundo_utils`, outside the userscript-GM subtree |
| `popmundo-webview` | Flutter WebView adapter: `InAppPopmundoRuntime`, `PopmundoWebView`, JS bridge (`hooks.js`/`helpers.js`), `UserScripts` loader, WebView settings | Editing `packages/popmundo_webview`, outside the userscript-GM subtree |
| `popmundo-app-shell` | Composition root + shell UI: `main.dart`, `app.dart`, debug overlay, Android manifest / iOS `Info.plist` | Editing `apps/popmundo_app`, outside the userscript-GM subtree |
| `popmundo-domain` | Popmundo's own game rules: load-balanced hostnames, DOM selectors, webservice endpoints, the GPL port from Popmundo-Utils `common/` | Selectors, endpoints, throttle behavior, or porting more of the upstream extension |
| `popmundo-greasemonkey` | The `GM_*`/`GM.*` (Greasemonkey/Tampermonkey) polyfill layer: `@grant` parsing, `UserScriptGmShim`, `GmValueStore`, navigation-time snapshot refresh | Any `GM_*`/`GM.*` implementation or maintenance, spanning both `popmundo_utils` and `popmundo_webview` |
| `popmundo-e2e` | The device-real test tier: `integration_test/` + Patrol, `androidTest` bootstrap, instrumentation config. Carries the one-`patrolTest`-per-file rule, the mutation-proof requirement, and the obligation to run `patrol test` itself (never hand a paste-ready command to the user as a substitute for execution) | Writing or debugging anything under `apps/popmundo_app/integration_test/`, or a request to test something "for real on the device" (foreground service, Keystore, prefs channel, real sockets) |

Read the target agent's file-ownership list and rules before editing — don't just skim this table. When a change spans two areas (e.g. a new `GM_*` function that also needs a new domain selector), invoke both agents rather than having one agent freelance outside its own file list.

## Repo layout

Pub workspace (`pubspec.yaml` at root, `resolution: workspace`) with three packages:

| Package | Role |
| ------- | ---- |
| `packages/popmundo_utils` | Pure Dart, no Flutter. `PopmundoRuntime`, `HostTracker`, `TimedFetch`, Auto Login (`AuthSession` / `CookieSink` / `CookieSource`), UserScript parser/catalog/GM shim, facades, `KeyValueStore`/`SecretStore`, events (`network`/`console`/`navigation`/`gmValue`/`gmCall`). First pub dependency: `html`. `dart:io` only in `auth_http_io.dart`. |
| `packages/popmundo_webview` | Flutter adapter: `InAppPopmundoRuntime` (`loadUrl`, `syncUserScripts`), `PopmundoWebView`, JS bridge, `UserScriptInjector`, `InAppCookieSink`, back-navigation. JS in `assets/js/{hooks,helpers}.js`. |
| `apps/popmundo_app` | Composition root + shell. `main.dart` wires runtime, `SharedPreferencesStore`, EasyLocalization, FGS port. Sidebar, Auto Login UI, UserScripts UI, `GmHostHandler`, keepalive, i18n EN/PT, debug overlay. Patrol tests in `integration_test/`. |

Dependency direction is strictly one-way: `popmundo_utils` ← `popmundo_webview` ← `popmundo_app`. `popmundo_utils` must never depend on Flutter or `flutter_inappwebview` — that's what makes its tests device-free.

## Commands

Run from the repo root unless noted; `resolution: workspace` means `pub get` at the root resolves all three packages at once.

```bash
# fetch deps for the whole workspace
flutter pub get

# static analysis (per package; each has its own analysis_options.yaml)
flutter analyze packages/popmundo_utils
flutter analyze packages/popmundo_webview
flutter analyze apps/popmundo_app

# tests — popmundo_utils is pure Dart, no Flutter binding needed
cd packages/popmundo_utils && dart test
cd packages/popmundo_utils && dart test test/timed_fetch_test.dart   # single file
cd packages/popmundo_utils && dart test --name "some test name"      # single test by name

# tests — popmundo_webview and popmundo_app need the Flutter test binding
cd packages/popmundo_webview && flutter test
cd apps/popmundo_app && flutter test
cd apps/popmundo_app && flutter test test/debug_overlay_test.dart

# run the app
cd apps/popmundo_app && flutter run
```

There are no melos scripts defined (`melos.yaml` only lists package globs) and no CI config in-repo — analyze/test are invoked manually per package as above.

### Device-real tests (Patrol)

A second test tier lives in `apps/popmundo_app/integration_test/` and runs on a real Android device or emulator. It exercises real platform APIs — the foreground service, the Keystore, the SharedPreferences channel, real sockets — which the fake-based tier structurally cannot reach.

```bash
# one-time: install the CLI, and make sure adb is on PATH
flutter pub global activate patrol_cli

# run one file (see the one-test-per-file rule below)
cd apps/popmundo_app && patrol test --target integration_test/keepalive_test.dart -d <device-id>
```

- **`flutter test` never runs these** — it globs `test/` only, so the two tiers stay independent.
- **The device tier never loads popmundo.com, and structurally cannot.** Under `integration_test`/Patrol the Dart entrypoint is the *test file*, so `lib/main.dart` never runs, `PopmundoApp` is never constructed and `InAppPopmundoRuntime` never exists. Tests pump minimal harness widgets instead. Because `lib/main.dart` does not run, anything it sets up must be redone in `integration_test/support/harness.dart` — notably `FlutterForegroundTask.initCommunicationPort()`.
- **Exactly ONE `patrolTest` per file.** Patrol runs a single Dart test per app process; a second one fails with `Invalid response 500`. This is an open upstream bug ([2005](https://github.com/leancodepl/patrol/issues/2005), [2380](https://github.com/leancodepl/patrol/issues/2380)) — group related assertions into one sequential test with a `reason` on each `expect`.
- **Always run `flutter analyze integration_test` before a device run.** It catches Dart errors in ~2s that would otherwise cost a full build-install-run cycle.
- **Agents run Patrol themselves.** After analyze is clean, run `patrol test` against a connected device. Do not hand a paste-ready command to the user as a substitute for execution.
- See `.specs/features/mobile-e2e-tests/` for the spec, and AD-015 for the tier's boundary.

## Architecture notes that span files

- **`PopmundoRuntime` is the seam.** It's a port defined in `popmundo_utils` (`popmundo_runtime.dart`) and implemented once, in `popmundo_webview` (`InAppPopmundoRuntime`). Methods: `evaluate`, `fetchInPage`, `loadUrl` (document navigation; required by Auto Login after cookie sync), `waitUntilReady`. Everything in `popmundo_utils` that talks to the page takes a `PopmundoRuntime`; tests fake it (`packages/popmundo_utils/test/fake_runtime.dart`). Cookie sync into the WebView uses a second port, `CookieSink` → `InAppCookieSink`. The session heartbeat reads the other way via `CookieSource` (`CookieManager.getCookies`).
- **One JS↔Dart channel.** All page-side events go through a single JS handler named `'popmundo'` with payload `{type, payload}`, routed in Dart by `PopmundoJsBridge.handle` (`type` ∈ `ready|network|console|gmValue|gm`). Navigation events are separate — they come from native WebView callbacks (`onLoadStart`, `shouldOverrideUrlLoading`), not the JS channel. The JS side (`assets/js/hooks.js`) queues messages until `flutterInAppWebViewPlatformReady` fires, then flushes and sends `{type: 'ready'}`, which completes `InAppPopmundoRuntime._ready`; anything awaiting `runtime.waitUntilReady()` blocks (30s timeout → `PopmundoRuntimeException`) until then. Host GM replies use `window.__popmundo.gmReply`.
- **Interception is observe-only — never change this.** `shouldInterceptFetchRequest`/`shouldInterceptAjaxRequest` always return the original request; `shouldInterceptRequest` (Android) always returns `null` via `ObservePolicy.observeOnlyResourceResponse()`. No code path should ever construct a replacement `WebResourceResponse` or mutate a request — this is a hard product requirement (AD-003), not just a current choice.
- **Host is sticky, never hardcoded.** `HostTracker` starts at `https://www.popmundo.com` and updates only on real Popmundo navigations (`onNavigation`). `TimedFetch._absoluteUrl` and `Utils.getServerLink` always resolve against `host.currentOrigin`/`host.resolve(...)` at call time — don't reintroduce a literal `www.popmundo.com` anywhere downstream of the first load (AD-007).
- **`TimedFetch` enforces the game's throttle.** Serial queue, 750ms minimum delay since the last call's completion, in-memory cache keyed `METHOD:URL`. Any new auxiliary **in-page** network call to the game must go through this, not a parallel `fetch`, or risk logging the player out. Auto Login (AD-018) is the documented exception: the handshake uses native `dart:io` (`AuthSession`) because in-page fetch cannot follow the `www` → `N.popmundo.com` CORS hop; it still honors the 750ms cooldown. Cookies are copied into the WebView via `CookieSink` / `InAppCookieSink`. Session heartbeat (AD-019) is a second native GET every 60s to `{stickyHost}/World/Popmundo.aspx/Character` and does **not** use TimedFetch (WebView JS freezes in background). UserScript / `@require` / `@resource` downloads must **not** use TimedFetch (AD-010).
- **`Scoring` must never auto-run.** `Scoring.autoApplyOnLoad` is a documented `false` constant; scoring/bar helpers are opt-in API calls, not something a `UserScript` triggers on page load.
- **Page-facing functions follow one pattern.** New DOM/page functionality is added as `window.__popmundo.<fn>` in `assets/js/helpers.js` (or `hooks.js` for interception), then a Dart facade method in `popmundo_utils` that calls `runtime.evaluate('window.__popmundo.<fn>(...)')` with `jsonEncode`-d arguments — see `notifications.dart`, `css_selector.dart` for the shape. Exception: `Utils.getMyID` / `getMyName` / `getMyCharDetails` TimedFetch GET `/World/Popmundo.aspx/Character` (cached) and parse the HTML in Dart — those nodes are missing on most routes.
- **`apps/popmundo_app/lib/app.dart` imports `flutter_inappwebview` directly** (`CookieManager`, `WebUri`) to read cookie names for the debug overlay, bypassing the `popmundo_webview` adapter. This is a known, intentional-but-undocumented-elsewhere coupling — be aware of it if `popmundo_webview` internals change.
- **Storage has no `chrome.*`.** `KeyValueStore` is the contract (`popmundo_utils`); `MemoryKeyValueStore` is used in tests, `SharedPreferencesStore` (`apps/popmundo_app/lib/prefs_store.dart`) is the real implementation, injected at the composition root in `main.dart`.
- **GPL-3.0-or-later applies repo-wide** (see `LICENSE`/`NOTICE`) because these packages are a translation of Popmundo-Utils' GPL-3 `common/`. `chrome.storage`/`chrome.runtime` equivalents are reimplemented in Dart from scratch, never copied. Keep this in mind before pulling in code from the original JS project.
- **Gameplay automation features (mass interact, call friends, autograph collector, etc.) are explicitly out of scope** per `spec.md` — this repo is the observable foundation only, not a full port of the Chrome extension.
- **No live-site e2e of the app.** The product CI/default gates do not drive `www.popmundo.com` through `PopmundoApp` (instability, real auth, ToS). Business logic is tested via `FakePopmundoRuntime`; widget tests use fake streams. Patrol (`apps/popmundo_app/integration_test/`) runs on real Android but **structurally cannot** load the game (test file is the Dart entrypoint). Opt-in exception: `packages/popmundo_utils/test_live/` can hit the live site when invoked by path with `POPMUNDO_*` env vars; `dart test` (glob `test/` only) never runs it. Do not wire `test_live` into CI. See AD-015 and `packages/popmundo_utils/test_live/README.md`.
