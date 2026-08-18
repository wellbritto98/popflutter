# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Popflutter is a Flutter (Android + iOS) wrapper around the web game [Popmundo](https://www.popmundo.com), built on `flutter_inappwebview`. The game's own web UI is the main UI — the app doesn't recreate it. The app observes network/console/navigation from the page, persists cookies, and offers a Dart utility library ported from [Popmundo-Utils `common/`](https://github.com/ilpersi/Popmundo-Utils) (GPL-3) so future features can be built without reimplementing that Chrome extension.

Full architecture/product docs (generated from source analysis): `docs/ARQUITETURA.md` and `docs/OBJETIVO.md`.

## Feature workflow — use the `tlc-spec-driven` skill

This repo's `.specs/` tree is not incidental documentation — it's the persisted state of the `tlc-spec-driven` skill (`.claude/skills/tlc-spec-driven/`), which owns all feature planning, implementation, and verification here. **Invoke that skill (`/tlc-spec-driven`, or let it trigger naturally on "specify feature", "design", "tasks", "implement", "validate", "resume work", etc.) for any non-trivial feature work instead of freelancing an ad-hoc plan.** Its 4-phase pipeline (Specify → Design → Tasks → Execute, auto-sized to scope) is what produced everything under `.specs/`:

- `.specs/STATE.md` — decision log (AD-001…AD-008) + handoff snapshot. Read the Decisions section before changing cross-package contracts (`PopmundoRuntime`, the JS bridge message shape, host-sticky resolution, etc.) — it records the *why* behind choices that aren't obvious from the code alone. On "resume work", this file's Handoff section is the skill's own entry point.
- `.specs/features/popmundo-wrapper/` — `spec.md` (requirements with traceable IDs), `context.md` (resolved gray-area decisions), `design.md` (architecture/components), `tasks.md`, `validation.md` (Verifier report) for the wrapper feature already implemented. Treat this as the canonical example of the skill's output shape for this repo.
- `.specs/LESSONS.md` / `.specs/lessons.json` — self-improving lessons distilled from past verification gaps; the skill loads confirmed lessons at Specify/Design. Don't hand-edit `LESSONS.md` — it's rendered from `lessons.json` by `scripts/lessons.py`.

New features, bug fixes with any ambiguity, or changes touching more than one package should go through Specify at minimum; the skill auto-skips Design/Tasks for small/medium scope. Execute always ends with an independent Verifier pass (author ≠ verifier) — don't hand-roll a substitute verification step.

## Specialist agents — use them for their area, don't freelance

Five domain-specialist agents exist for this repo, defined at `.cursor/agents/*.md` (Cursor) and mirrored at `.claude/agents/popmundo-greasemonkey.md` for Claude Code's Agent tool. **Whenever a change falls inside one of their areas, invoke that agent instead of editing directly** — each one carries a file-ownership list, non-negotiable rules, and lessons from past mistakes that aren't otherwise obvious from the code alone.

| Agent | Area | Touch it when |
| ----- | ---- | -------------- |
| `popmundo-utils` | Pure-Dart core: `PopmundoRuntime` contract, `TimedFetch`, `HostTracker`, `Notifications`, `Storage`/`KeyValueStore`, `CssSelectorHelper`, `Scoring`, `Logger` | Editing `packages/popmundo_utils`, outside the userscript-GM subtree |
| `popmundo-webview` | Flutter WebView adapter: `InAppPopmundoRuntime`, `PopmundoWebView`, JS bridge (`hooks.js`/`helpers.js`), `UserScripts` loader, WebView settings | Editing `packages/popmundo_webview`, outside the userscript-GM subtree |
| `popmundo-app-shell` | Composition root + shell UI: `main.dart`, `app.dart`, debug overlay, Android manifest / iOS `Info.plist` | Editing `apps/popmundo_app`, outside the userscript-GM subtree |
| `popmundo-domain` | Popmundo's own game rules: load-balanced hostnames, DOM selectors, webservice endpoints, the GPL port from Popmundo-Utils `common/` | Selectors, endpoints, throttle behavior, or porting more of the upstream extension |
| `popmundo-greasemonkey` | The `GM_*`/`GM.*` (Greasemonkey/Tampermonkey) polyfill layer: `@grant` parsing, `UserScriptGmShim`, `GmValueStore`, navigation-time snapshot refresh | Any `GM_*`/`GM.*` implementation or maintenance, spanning both `popmundo_utils` and `popmundo_webview` |

Read the target agent's file-ownership list and rules before editing — don't just skim this table. When a change spans two areas (e.g. a new `GM_*` function that also needs a new domain selector), invoke both agents rather than having one agent freelance outside its own file list.

## Repo layout

Pub workspace (`pubspec.yaml` at root, `resolution: workspace`) with three packages:

| Package | Role |
| ------- | ---- |
| `packages/popmundo_utils` | Pure Dart, no Flutter dependency. `PopmundoRuntime` contract, `HostTracker`, `TimedFetch`, `Utils`, `Notifications`, `CssSelectorHelper`/`XPathHelper`, `Scoring`, `StorageService`/`KeyValueStore`, `Logger`, `PopmundoEventBus`/event models, `ObservePolicy`. |
| `packages/popmundo_webview` | Flutter adapter: `InAppPopmundoRuntime` (implements `PopmundoRuntime`), `PopmundoWebView` widget, JS bridge (`PopmundoJsBridge`), `UserScripts` loader, WebView settings. JS assets in `assets/js/{hooks,helpers}.js`. |
| `apps/popmundo_app` | Composition root + shell UI. `main.dart` wires `InAppPopmundoRuntime()` + `SharedPreferencesStore`; `app.dart` is the `MaterialApp`/`PopmundoScope`; `debug_overlay.dart` is the dev inspector. |

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

## Architecture notes that span files

- **`PopmundoRuntime` is the seam.** It's a port defined in `popmundo_utils` (`popmundo_runtime.dart`) and implemented once, in `popmundo_webview` (`InAppPopmundoRuntime`). Everything in `popmundo_utils` — `Utils`, `Notifications`, `TimedFetch`, `Scoring`, `CssSelectorHelper` — takes a `PopmundoRuntime` and calls `runtime.evaluate(...)` or `runtime.fetchInPage(...)`; none of them know about `flutter_inappwebview`. Tests fake this runtime (`packages/popmundo_utils/test/fake_runtime.dart`) instead of using a device.
- **One JS↔Dart channel.** All page-side events (`fetch`/`XHR`/`console`) go through a single JS handler named `'popmundo'` with payload `{type, payload}`, routed in Dart by `PopmundoJsBridge.handle` (`type` ∈ `ready|network|console`). Navigation events are separate — they come from native WebView callbacks (`onLoadStart`, `shouldOverrideUrlLoading`), not the JS channel. The JS side (`assets/js/hooks.js`) queues messages until `flutterInAppWebViewPlatformReady` fires, then flushes and sends `{type: 'ready'}`, which completes `InAppPopmundoRuntime._ready`; anything awaiting `runtime.waitUntilReady()` blocks (30s timeout → `PopmundoRuntimeException`) until then.
- **Interception is observe-only — never change this.** `shouldInterceptFetchRequest`/`shouldInterceptAjaxRequest` always return the original request; `shouldInterceptRequest` (Android) always returns `null` via `ObservePolicy.observeOnlyResourceResponse()`. No code path should ever construct a replacement `WebResourceResponse` or mutate a request — this is a hard product requirement (AD-003), not just a current choice.
- **Host is sticky, never hardcoded.** `HostTracker` starts at `https://www.popmundo.com` and updates only on real Popmundo navigations (`onNavigation`). `TimedFetch._absoluteUrl` and `Utils.getServerLink` always resolve against `host.currentOrigin`/`host.resolve(...)` at call time — don't reintroduce a literal `www.popmundo.com` anywhere downstream of the first load (AD-007).
- **`TimedFetch` enforces the game's throttle.** Serial queue, 750ms minimum delay since the last call's completion, in-memory cache keyed `METHOD:URL`. Any new auxiliary network call to the game must go through this, not a parallel `fetch`, or risk logging the player out.
- **`Scoring` must never auto-run.** `Scoring.autoApplyOnLoad` is a documented `false` constant; scoring/bar helpers are opt-in API calls, not something a `UserScript` triggers on page load.
- **Page-facing functions follow one pattern.** New DOM/page functionality is added as `window.__popmundo.<fn>` in `assets/js/helpers.js` (or `hooks.js` for interception), then a Dart facade method in `popmundo_utils` that calls `runtime.evaluate('window.__popmundo.<fn>(...)')` with `jsonEncode`-d arguments — see `utils.dart`, `notifications.dart`, `css_selector.dart` for the shape.
- **`apps/popmundo_app/lib/app.dart` imports `flutter_inappwebview` directly** (`CookieManager`, `WebUri`) to read cookie names for the debug overlay, bypassing the `popmundo_webview` adapter. This is a known, intentional-but-undocumented-elsewhere coupling — be aware of it if `popmundo_webview` internals change.
- **Storage has no `chrome.*`.** `KeyValueStore` is the contract (`popmundo_utils`); `MemoryKeyValueStore` is used in tests, `SharedPreferencesStore` (`apps/popmundo_app/lib/prefs_store.dart`) is the real implementation, injected at the composition root in `main.dart`.
- **GPL-3.0-or-later applies repo-wide** (see `LICENSE`/`NOTICE`) because these packages are a translation of Popmundo-Utils' GPL-3 `common/`. `chrome.storage`/`chrome.runtime` equivalents are reimplemented in Dart from scratch, never copied. Keep this in mind before pulling in code from the original JS project.
- **Gameplay automation features (mass interact, call friends, autograph collector, etc.) are explicitly out of scope** per `spec.md` — this repo is the observable foundation only, not a full port of the Chrome extension.
- **No live-site e2e tests.** Testing against `www.popmundo.com` in CI is deliberately excluded (instability, real auth, ToS) — business logic is tested via `FakePopmundoRuntime` in `popmundo_utils`, and widget tests in `popmundo_app`/`popmundo_webview` use fake event streams instead of a real WebView.
