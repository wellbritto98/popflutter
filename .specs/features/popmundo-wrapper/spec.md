# Popmundo Wrapper Specification

## Problem Statement

O Popmundo é um jogo web com load balancing por subdomínio e throttle agressivo de requests. Queremos um app Flutter que use a UI do próprio jogo via InAppWebView, mas dê ao desenvolvedor acesso observável a requests, DOM, console e helpers (TimedFetch, host sticky, notifications, storage) para construir funções novas sem reimplementar a extensão Chrome.

## Goals

- [ ] O jogador abre o app e joga Popmundo em WebView fullscreen, com sessão persistente.
- [ ] O desenvolvedor observa navegação, fetch/XHR e console via streams Dart, sem mutar o tráfego.
- [ ] O desenvolvedor usa APIs Dart equivalentes à fundação `common/` (host, TimedFetch, personagem, notifications, selectors, storage, Scoring) contra o host sticky atual.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| ------- | ------ |
| Mass interact, call friends, autograph, demais features de gameplay da extensão | Fundação `common/` apenas; features são outro produto |
| Bloquear ou reescrever request/response | Interceptor é observe-only |
| Android-only native `shouldInterceptRequest` como fonte da verdade | MVP é Android + iOS |
| Desktop / Flutter Web | Fora do MVP |
| Publicação nas stores | Não pedido |
| E2E contra `www.popmundo.com` em CI | Instável, auth real, ToS |
| Auto-aplicar Scoring/QoL visual em todo page load | API existe; o dev chama |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here — nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Links externos (`host` não é `*.popmundo.com`) | Abrem no browser do SO | Evita sair da sessão do jogo no WebView | n (agent) |
| Overlay em release | FAB toggle, default visível — **superseded by AD-009** (`.specs/STATE.md`): overlay agora gated por `kDebugMode` via `buildAppMenuItems`, inacessível em release; FAB sempre visível passa a ser o do sidebar (`menu-toggle`), não um FAB próprio do overlay | App é ferramenta de desenvolvimento | n (agent) |
| Body de fetch no stream | Texto/JSON até 32 KiB; binário omitido | Overlay e memória | n (agent) |
| Host permitido no WebView | `popmundo.com` e qualquer subdomínio `*.popmundo.com` | Load balancing + `apps.` | n (agent) |
| Cache TimedFetch | Somente memória, por sessão de processo | Igual ao JS original | y |
| Delay TimedFetch | 750 ms | Valor do `TimedFetch` original | y |
| Scoring no load | Não auto-aplica | Escopo utils-only | y |
| Licença | GPL-3.0-or-later + NOTICE | Fonte `common/` é GPL-3 | y |
| Cookie values no overlay | Ocultos por padrão | Evitar vazar sessão na UI | y |

**Open questions:** none — all resolved or logged above (required before the spec is confirmed).

---

## User Stories

### P1: WebView shell com host sticky ⭐ MVP

**User Story**: As a player, I want the app to load Popmundo and follow subdomain redirects so that I stay on the server assigned to my session.

**Why P1**: Sem o shell não há produto.

**Acceptance Criteria**:

1. WHEN the app starts THEN the system SHALL load `https://www.popmundo.com` in an InAppWebView filling the screen (system status bar allowed).
2. WHEN the site navigates or redirects to another host matching `*.popmundo.com` or `popmundo.com` THEN the system SHALL update the current origin to that host and keep the WebView on that URL.
3. WHEN the current origin changes THEN any later helper URL built by `getServerLink`/`HostTracker.resolve` SHALL use the new hostname, not a hardcoded `www.popmundo.com`.
4. WHEN the user follows a link whose host is not `popmundo.com` and not `*.popmundo.com` THEN the system SHALL open it in the OS browser and SHALL NOT replace the WebView session with that URL.

**Independent Test**: Unit tests on `HostTracker` with fake navigations; widget/config test that initial URL is `https://www.popmundo.com`.

---

### P1: Sessão persistente

**User Story**: As a player, I want to stay logged in after closing the app so that I do not type credentials every launch.

**Why P1**: Sem cookies persistentes o wrapper é inutilizável no dia a dia.

**Acceptance Criteria**:

1. WHEN the WebView is created THEN the system SHALL use the default (non-incognito) cookie store.
2. WHEN the app process is killed and relaunched THEN the system SHALL present the same WebView cookie store (no `incognito: true`).
3. WHEN the developer asks the debug overlay for cookies THEN the system SHALL list cookie names/domains without showing values unless an explicit reveal is used.

**Independent Test**: Assert InAppWebView settings `incognito == false`; overlay widget test hides cookie values by default.

---

### P1: Interceptor somente-observação

**User Story**: As a developer, I want a stream of network, navigation, and console events from the game page so that I can build helpers without mutating traffic.

**Why P1**: Requisito central do wrapper.

**Acceptance Criteria**:

1. WHEN the page performs `fetch` or `XMLHttpRequest` THEN the system SHALL emit a `NetworkEvent` with at least method, URL, and (when available) status, without altering the request.
2. WHEN the page writes to `console.log` / `warn` / `error` THEN the system SHALL emit a `ConsoleEvent` with level and message.
3. WHEN the WebView navigates THEN the system SHALL emit a `NavigationEvent` with the URL.
4. WHEN intercept callbacks run THEN they SHALL return the original request / allow navigation for popmundo hosts — they SHALL NOT return a custom `WebResourceResponse` that replaces the game response.
5. WHEN a response body is text/json THEN the event MAY include a truncated body of at most 32768 bytes; WHEN the body is binary or larger THEN the event SHALL omit or truncate the body and set a flag `bodyTruncated` or `bodyOmitted`.

**Independent Test**: Fake runtime / JS fixture emitting handler payloads; unit tests that observe-only policy never returns a replacement response object from a pure Dart policy helper.

---

### P1: TimedFetch com throttle

**User Story**: As a developer, I want serialized delayed fetches in page context so that helper calls do not log the player out.

**Why P1**: O jogo desconecta se houver rajada de requests.

**Acceptance Criteria**:

1. WHEN two TimedFetch calls are issued with empty cache THEN the system SHALL start the second network attempt only after the first completes AND at least 750 ms have elapsed since the previous attempt's completion timestamp.
2. WHEN `useCache` is true and the same `METHOD:URL` was already fetched successfully in this process THEN the system SHALL return the cached text and SHALL NOT start a new in-page fetch.
3. WHEN `useCache` is false THEN the system SHALL hit the network even if a cache entry exists.
4. WHEN the in-page fetch returns a non-2xx status THEN TimedFetch SHALL complete with an error (not a cached success).
5. WHEN the resource is a path starting with `/` THEN the fetch URL SHALL be resolved against the current sticky host (`https://{currentHost}{path}`).

**Independent Test**: `FakePopmundoRuntime` + fake clock; no live Popmundo.

---

### P1: Personagem, notifications e selectors

**User Story**: As a developer, I want Dart facades for character id/name, in-game notifications, and CSS/XPath queries so that I can script against the current page.

**Why P1**: Núcleo da lib extraída de `utils.js` / `notifications.js`.

**Acceptance Criteria**:

1. WHEN `div.idHolder` exists in the page THEN `Utils.getMyID` SHALL return that integer; WHEN it is missing THEN it SHALL return `0`.
2. WHEN the character name node `#ppm-content > div.box.ofauto.charPresBox > h2` exists THEN `Utils.getMyName` SHALL return its text; otherwise `''`.
3. WHEN `Notifications.createNotification` is called with level `success`|`error`|`normal` THEN the system SHALL create a notification div under `#notifications` with the corresponding CSS class; WHEN the container is missing THEN it SHALL not throw from Dart (result indicates failure).
4. WHEN `getPageNotifications` runs THEN it SHALL POST JSON `{ ts: "<millis>" }` to `/WebServices/A/Open.asmx/GetPageNotifications` via TimedFetch (`useCache: false`) on the current host.
5. WHEN `CssSelectorHelper.getSingle` / `getAll` are called THEN they SHALL run `querySelector` / `querySelectorAll` in page context and return serializable results (tag, id, class, text truncated).

**Independent Test**: Fake runtime returning fixture JSON/DOM scrape maps.

---

### P1: Storage sem chrome.*

**User Story**: As a developer, I want a storage API with the same logical keys as the extension exclude-list helpers so that later features can reuse shards without Chrome APIs.

**Why P1**: Port explícito de `chrome.storage` para Dart.

**Acceptance Criteria**:

1. WHEN `StorageService` get/set is used THEN values SHALL persist across Dart isolates/process restarts via `shared_preferences` (or equivalent local store), not `chrome.storage`.
2. WHEN `getExcludedIds(featureKey, myCharID)` is called after `toggleExclusion` added an id THEN the id SHALL be in the returned list; WHEN toggled again THEN it SHALL be absent.
3. WHEN `normalizeExcludeMap` receives null or a list THEN it SHALL return `{}`.
4. WHEN `excludeEntryId` receives `{id: 7}` or `7` THEN it SHALL return `7`; WHEN it receives garbage THEN it SHALL return null.

**Independent Test**: In-memory fake preferences; no plugin binding required in unit tests.

---

### P2: Overlay de debug

**User Story**: As a developer, I want an in-app panel showing host, requests, and console so that I can inspect the wrapper without USB debugging.

**Why P2**: Necessário para desenvolver em cima do wrapper, não para o jogador puro.

**Acceptance Criteria**:

1. WHEN the overlay is collapsed THEN pointer events SHALL pass through to the WebView except for the expand control. **Note (AD-009, `app-sidebar-menu`):** the expand control is no longer owned by `DebugOverlay` itself — it is the shell-level FAB (`menu-toggle`) in `AppShell`, which opens the sidebar item that reveals the panel. When collapsed (`visible: false`), `DebugOverlay` now renders no control of its own at all over the WebView.
2. WHEN expanded THEN the overlay SHALL show current host, a list of network events (method, URL, status), and console events.
3. WHEN the developer submits a JS snippet THEN the system SHALL `evaluateJavascript` it and show the string result or error.
4. WHEN clear is pressed THEN the in-memory event lists in the overlay SHALL become empty (underlying streams may continue).

**Independent Test**: Widget tests with fake event streams.

---

### P2: Scoring API (não auto-aplicada)

**User Story**: As a developer, I want Scoring/star/bar helpers available so that I can opt-in to QoL DOM changes.

**Why P2**: Está em `utils.js` mas auto-aplicar sairia do recorte utils-only.

**Acceptance Criteria**:

1. WHEN `Scoring.applyScoringNumbers` is not called THEN page load SHALL NOT inject score number spans by itself.
2. WHEN the developer calls the Scoring/star/bar APIs THEN the runtime SHALL evaluate the corresponding in-page helpers.

**Independent Test**: Default UserScripts fixture does not contain auto-run `applyScoringNumbers()`; API method exists and invokes runtime evaluate.

---

### P3: Logger

**User Story**: As a developer, I want a small logger that records warn/error with a ring buffer so that diagnostics are available without chrome.runtime.

**Why P3**: Presente em `common/logger.js`; útil, não bloqueia o MVP do shell.

**Acceptance Criteria**:

1. WHEN `Logger.warn` or `Logger.error` is called THEN the message SHALL be stored in a bounded in-memory ring buffer (capacity 200).
2. WHEN the buffer exceeds 200 THEN the oldest entries SHALL be dropped.

**Independent Test**: Unit test of ring buffer.

---

## Edge Cases

- WHEN the WebView fails to load (network error) THEN the system SHALL keep the last known origin and SHALL allow a reload; it SHALL NOT crash the app.
- WHEN UserScript injection fails or the JS handler is not ready THEN TimedFetch/helpers SHALL fail with a typed error, not a hang without timeout (timeout 30s).
- WHEN `www.popmundo.com` redirects to a numeric host THEN subsequent helper calls SHALL use the numeric host.
- WHEN TimedFetch is called before any successful navigation THEN it SHALL use `www.popmundo.com` as current host.
- WHEN notification level is unknown THEN `createNotification` SHALL fail (error), not create a div.
- WHEN two TimedFetch callers overlap THEN they SHALL not issue overlapping in-page fetches (serialize).
- WHEN a fetch URL is absolute on another origin THEN TimedFetch SHALL still pass it through to in-page `fetch` (no rewrite), but `getServerLink` only builds popmundo paths.
- WHEN `idHolder` text is non-numeric THEN `getMyID` SHALL return `0`.

---

## Implicit-requirement dimensions

| Dimension | Requirement or N/A |
| --------- | ------------------ |
| Input validation & bounds | Host allowlist `popmundo.com` / `*.popmundo.com`; body cap 32768; TimedFetch delay >= 0 |
| Failure / partial-failure states | Load error → reloadable; JS not ready → error; TimedFetch non-2xx → error |
| Idempotency / retry / duplicate handling | TimedFetch cache key `METHOD:URL`; no auto-retry beyond caller |
| Auth boundaries & rate limits | No app auth; game cookies; TimedFetch 750 ms serialize to respect game throttle |
| Concurrency / ordering | TimedFetch single-flight queue; HostTracker last-write-wins on navigation |
| Data lifecycle / expiry | Cookies persist until OS/WebView clear or site logout; fetch cache dies with process; overlay events in-memory |
| Observability | Overlay + Logger ring buffer; console stream |
| External-dependency failure | Popmundo down: WebView error callback, app stays up |
| State-transition integrity | Origin only updates from popmundo navigations; external links do not change sticky host |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| WRAP-01 | P1: WebView shell | Execute | Verified |
| HOST-01 | P1: Host sticky on redirect | Execute | Verified |
| HOST-02 | P1: getServerLink uses current host | Execute | Verified |
| HOST-03 | P1: External links leave WebView | Execute | Verified |
| SESS-01 | P1: Non-incognito cookie store | Execute | Verified |
| SESS-02 | P1: Overlay hides cookie values | Execute | Verified |
| INT-01 | P1: fetch/XHR events | Execute | Verified |
| INT-02 | P1: console events | Execute | Verified |
| INT-03 | P1: navigation events | Execute | Verified |
| INT-04 | P1: observe-only policy | Execute | Verified |
| INT-05 | P1: body truncation | Execute | Verified |
| UTIL-01 | P1: TimedFetch delay+serialize | Execute | Verified |
| UTIL-02 | P1: TimedFetch cache | Execute | Verified |
| UTIL-03 | P1: TimedFetch useCache false | Execute | Verified |
| UTIL-04 | P1: TimedFetch non-2xx error | Execute | Verified |
| UTIL-05 | P1: TimedFetch resolves relative to host | Execute | Verified |
| UTIL-06 | P1: getMyID / getMyName | Execute | Verified |
| UTIL-07 | P1: Notifications DOM | Execute | Verified |
| UTIL-08 | P1: getPageNotifications | Execute | Verified |
| UTIL-09 | P1: CssSelectorHelper | Execute | Verified |
| STOR-01 | P1: Storage persists without chrome | Execute | Verified |
| STOR-02 | P1: toggleExclusion / getExcludedIds | Execute | Verified |
| STOR-03 | P1: normalizeExcludeMap / excludeEntryId | Execute | Verified |
| DBG-01 | P2: Overlay pass-through when collapsed | Execute | Verified |
| DBG-02 | P2: Overlay lists host/events | Execute | Verified |
| DBG-03 | P2: Overlay JS eval | Execute | Verified |
| DBG-04 | P2: Overlay clear | Execute | Verified |
| SCORE-01 | P2: Scoring not auto-applied | Execute | Verified |
| SCORE-02 | P2: Scoring APIs invoke runtime | Execute | Verified |
| LOG-01 | P3: Logger ring buffer 200 | Execute | Verified |

**ID format:** `[CATEGORY]-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 31 total, 31 mapped to tasks, 0 unmapped

---

## Success Criteria

- [x] App loads Popmundo and follows `*.popmundo.com` host changes.
- [x] Developer can subscribe to network/console/navigation streams without mutating traffic.
- [x] TimedFetch serializes with 750 ms delay and caches `METHOD:URL` in memory.
- [x] Utils/notifications/storage work via FakePopmundoRuntime in unit tests without hitting the live site.
- [x] Overlay inspects host/events and evaluates JS.
