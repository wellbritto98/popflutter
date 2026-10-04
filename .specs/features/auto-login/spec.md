# Auto Login Specification

## Problem Statement

Quando a sessão do Popmundo expira, o jogador volta ao formulário ASP.NET em `/` ou `/Default.aspx`. Isso pode acontecer **sem a WebView navegar** — em especial com o app em segundo plano (keepalive). Detectar só a URL de login deixa a sessão morta até o jogador tocar na página.

O ciclo de Auto Login continua **silencioso e fora da WebView**: handshake em HTTP nativo `dart:io`, cookies copiados para o jar da WebView, uma navegação para `{host}/World/Popmundo.aspx`. Além da detecção por navegação, um **heartbeat** a cada 60 s faz GET em `{hostSticky}/World/Popmundo.aspx/Character` com os cookies da WebView; um 302 para `/Default.aspx` significa deslogado e dispara o mesmo ciclo de renovação. Personagem pelo **nome completo**. Feedback por snackbars; resultado final em segundo plano por notificação local (AD-020). Sem fallback visível (AD-018).

## Goals

- [x] Jogador configura usuário, senha, personagem (nome completo) e status no sidebar; senha fica em cofre seguro
- [x] Com Auto Login enabled, ao detectar página de login o app autentica via HTTP nativo (`AuthSession`) sem clicar no form
- [x] O personagem é identificado pelo `<h2>` da `div.box`, não pelo rótulo do botão (que só tem o primeiro nome)
- [x] Ao fim do ciclo o WebView vai sempre para `{origin}/World/Popmundo.aspx`
- [x] Cada etapa do ciclo aparece como snackbar localizado (EN/PT)
- [x] Com Auto Login enabled, um GET nativo a cada 60 s em `{hostSticky}/World/Popmundo.aspx/Character` detecta logout (302 → `/Default.aspx`) e renova a sessão — inclusive com o app em keepalive/background

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Clique no formulário de login (DOM fill) | Substituído por POST nativo (AD-018) |
| Facebook OAuth | Fora do fluxo mapeado |
| Telegram / notificações de logout | Userscript-only; não pedido |
| Polling mais frequente que 60 s / seguir o 302 do Character | Sobrecarregaria o jogo; o 302 já basta |
| Probe a partir do isolate do FGS | AD-012: isolate só emite tick de keepalive; não fala com o jogo |
| Heartbeat in-page (`TimedFetch` / JS da WebView) | Em background o JS congela; o transporte nativo já existe |
| E2E live contra popmundo.com | Wrapper policy / ToS |
| Restore da última URL visitada | Substituído por World home fixo (pedido do usuário) |
| Desambiguação por ID de personagem | Nome completo resolve; ID fica como hardening futuro |
| Mutar intercept (AD-003) | Observe-only permanece |
| Gameplay do userscript (saúde/humor/itens) | Outro produto |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Transporte | HTTP nativo `dart:io` (`AuthSession`), redirects seguidos à mão para capturar o `Set-Cookie` de cada hop | Fetch in-page morre no hop cross-origin (verificado em device) | y |
| Cross-origin | O login em `www` responde 302 para `N.popmundo.com//Login.aspx?t=…`; CORS bloqueia o fetch in-page. O host é atribuído por balanceamento a cada login | Log do device: `74.` num run, `75.` no seguinte | y |
| Sessão na WebView | Cookies do handshake copiados via `CookieSink` → `CookieManager.setCookie`; host-only gravado sem `domain` | O jar do `dart:io` é separado do da WebView | y |
| User-Agent | Copiado da WebView (`navigator.userAgent`) para o jogo ver um cliente só | Pedido de coerência | y |
| Corpo do POST | Serialização do `#aspnetForm` inteiro + overrides (`.set`), como `mass-item-sender.js:224-243` | Dialeto correto do WebForms | y |
| Verdict | `GetPageNotifications` após o POST de escolha, como `mass-item-sender.js:272` | Corpo do POST não é confiável | y |
| Senha | `flutter_secure_storage` via `SecretStore`; settings não-secretos em `KeyValueStore` | Pedido explícito (discuss) | y |
| Gatilho | Form de login visível (`/` / `/Default.aspx` / campos `ucLogin`) + enabled + credenciais | Alinhado ao userscript | y (agent) |
| Personagem | **Nome completo** do `<h2>` da `div.box`; o `name=` do submit dentro da mesma box vai no corpo. O `value` (`Escolher X`) só tem o primeiro nome e colide | Pedido explícito | y |
| Nome duplicado | Duas boxes com o mesmo nome completo ⇒ aborta (`ambiguous`), nunca chuta | Pedido explícito | y |
| `ddlStatus` | Default `0` (Normal); editável na UI | Captura de request | y (agent) |
| Destino final | Sempre `{origin}/World/Popmundo.aspx`; `LastUrlStore` removido | Pedido explícito | y |
| UI nativa | Localizada EN/PT via `easy_localization` (AD-014); item sempre visível | Padrão sidebar | y |
| Feedback | Stream AutoLoginStatus → snackbars na shell; done/failed em background → notificação local | Pedido explícito | y |
| Concurrency | Um auto-login por vez (`inFlight`); falha 200+form = parar | Evita loop / throttle abuse | y (agent) |
| Heartbeat intervalo | 60 s, um GET por tick | Pedido explícito ("a cada minuto"); saudável vs throttle do jogo | y |
| Heartbeat URL | `{HostTracker.currentOrigin}/World/Popmundo.aspx/Character` — host numerado (`74.`, `75.`, …), **nunca** `www` hardcoded e **nunca** `HostTracker.resolve` (trailing slash) | Sessão e cookies são host-only no `N.` atribuído no login (AD-007); captura do usuário | y |
| Heartbeat logout | GET **sem** seguir redirect; status 3xx cuja `Location` resolvida é path de login (`/` / `/Default.aspx`) ⇒ deslogado ⇒ mesmo ciclo de Auto Login | Seguir o 302 baixaria o HTML grande de `Default.aspx` à toa; a captura mostra `Location: /Default.aspx` | y (agent) |
| Heartbeat cookies | Antes de cada probe, copiar o jar da **WebView** (`CookieManager.getCookies` no origin sticky) para o jar do `AuthSession`; depois do relogin, `CookieSink.write` como hoje | O jar `dart:io` é in-memory e vazio após restart; a sessão viva está na WebView (AD-004) | y |
| Heartbeat background | Timer no isolate do `AutoLoginController` (o mesmo do app). O FGS (AD-012) só mantém o processo vivo; o isolate do FGS **não** faz o GET | Pedido: funcionar em keepalive/background sem violar AD-012 | y |
| Heartbeat só com Auto Login | Probe e renovação só se enabled + username + password + character | Sem credenciais não há o que renovar | y (agent) |
| Heartbeat skip `www` | Se `currentOrigin.host` ainda é `www.popmundo.com`, o tick é ignorado | Ainda não há host de jogo; cookies de sessão são do `N.` | y |
| Heartbeat erro de rede / 5xx / 200 | Não é logout; espera o próximo tick. 200 no Character = sessão ok (corpo ignorado) | Evita relogin em queda de rede | y (agent) |
| Heartbeat vs navegação | Detecção por URL de login **permanece**. Heartbeat é o segundo gatilho. `inFlight` cobre os dois | Idle/background não gera `NavigationEvent` | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Configurar Auto Login no sidebar ⭐ MVP

**User Story**: As a player, I want an "Auto Login" sidebar item where I save username, password, character name, and status so the app can relog me without typing each time.

**Why P1**: Sem config persistida não há o que orquestrar.

**Acceptance Criteria**:

1. WHEN the registry builds menu items with `includeDebugItem: false` THEN the system SHALL include an item with `id: 'auto-login'`, label `Auto Login`, always visible.
2. WHEN the user opens Auto Login THEN the system SHALL show a screen with enabled toggle, username, password (obscured), character name, status dropdown (0 Normal / 1 Busy / 2 Mobile / 4 Away / 3 Drunk), and Save.
3. WHEN the user taps Save THEN the system SHALL persist non-secret settings to `KeyValueStore` key `autologin.v1` and the password to `SecretStore` — and SHALL NEVER write the password into `KeyValueStore`.
4. WHEN Save is in progress THEN the Save control SHALL be disabled until the write completes.
5. WHEN settings are loaded THEN the password field MAY be empty (placeholder for "unchanged") but username/character/enabled/status SHALL reflect stored values; clearing password on save with empty field SHALL leave existing secret unless user explicitly clears via a clear-password action OR empty means "keep previous" (chosen: empty password on save keeps previous secret if one exists; if no secret exists, treat as missing).

**Independent Test**: Registry unit test; widget test with `MemoryKeyValueStore` + fake `SecretStore`; assert password absent from KV store after save.

---

### P1: Auto-login silencioso via HTTP nativo ⭐ MVP

**User Story**: As a player with Auto Login enabled, when my session expires I want to be signed back in without ever seeing the login or character pages.

**Why P1**: É o núcleo da feature.

**Acceptance Criteria**:

1. WHEN Auto Login is enabled, credentials+character are present, and a Popmundo navigation URL indicates the login page (path `/` or `/Default.aspx`) THEN the system SHALL start at most one in-flight cycle.
2. WHEN the cycle starts THEN the system SHALL GET the login page over native HTTP and build the POST body by serializing the **entire** `#aspnetForm`, overriding `__EVENTTARGET`, `__EVENTARGUMENT`, `…ucLogin$txtUsername`, `$txtPassword`, `$ddlStatus` and `$btnLogin` (`OK!`).
3. WHEN the login POST is sent THEN redirects SHALL be followed one hop at a time with `followRedirects` off, re-issuing each 302 as a GET, so every hop's `Set-Cookie` is captured — the auth cookie is only emitted by the final, numbered host.
4. WHEN every request is sent THEN it SHALL carry the WebView's own `User-Agent`.
5. WHEN the chain ends on a login path OR the body still contains the login form THEN the system SHALL abort with `invalidCredentials`, write no cookies, and not loop.
6. WHEN the chain succeeds THEN every subsequent URL SHALL be resolved against the host the chain actually ended on, never a stored origin — the game assigns the host at login.
7. WHEN the character has been chosen THEN the system SHALL copy the session cookies into the WebView's jar **before** navigating, preserving host-only scope (no `domain` where the server sent none), `HttpOnly`, `Secure` and `SameSite`.
8. WHEN the cycle succeeds THEN the WebView SHALL perform exactly one navigation, to `{assignedHost}/World/Popmundo.aspx`, and SHALL NOT have submitted any form or run any in-page fetch.
9. WHEN the native transport fails THEN the system SHALL abort with `networkError`. There is no visible fallback: the WebView is never navigated through the login flow.
10. WHEN Auto Login is disabled OR username/password/character missing THEN no cycle SHALL start and no status SHALL be emitted.
11. WHEN a cycle is already in flight THEN a second trigger SHALL be ignored.
12. WHEN requests are sequential THEN they SHALL be at least 750 ms apart (AD-006).

**Independent Test**: scripted fake server replaying the real `www` → `N` chain; assert the whole-form body, the hop-by-hop cookie capture, the UA, the single `loadUrl`, and that no in-page fetch or form submit happened.

---

### P1: Choose character por nome completo ⭐ MVP

**User Story**: As a player with two characters sharing a first name, I want the app to select the exact one I configured, by full name.

**Why P1**: O rótulo do botão só traz o primeiro nome — é onde a versão anterior errava.

**Acceptance Criteria**:

1. WHEN the ChooseCharacter HTML is available THEN the system SHALL read one candidate per `div.box`, taking the full name from that box's `<h2>` (nested elements flattened, entities decoded, whitespace collapsed) and the POST field name from that same box's `input[type=submit]`.
2. WHEN the configured name matches exactly one candidate (case- and whitespace-insensitive) THEN the system SHALL POST the whole `#aspnetForm` of that page with `__EVENTTARGET`/`__EVENTARGUMENT` empty and the matched button's `name`=`value` added.
3. WHEN the configured name matches no candidate — including when it is only a first name — THEN the system SHALL abort with `characterNotFound` and SHALL NOT navigate.
4. WHEN the configured name matches more than one candidate THEN the system SHALL abort with `characterAmbiguous` rather than choosing one.
5. WHEN ChooseCharacter HTML has zero character boxes THEN the system SHALL abort with `noCharacters`.
6. WHEN the choice POST completes THEN the system SHALL poll `GetPageNotifications`; on `error` it SHALL abort with `serverRejected` carrying the server text and SHALL NOT navigate.
7. WHEN the choice succeeds THEN the system SHALL `loadUrl` `{origin}/World/Popmundo.aspx`, where `origin` is the host actually landed on — not `HostTracker.currentOrigin`, which is stale during a silent cycle.

**Independent Test**: fixture with two characters named `Deon *`; assert each resolves to its own `btnChooseCharacter2` index, that `Deon` alone is `notFound`, and that duplicates are `ambiguous`.

---

### P1: Feedback do ciclo ⭐ MVP

**User Story**: As a player, I want to see what the auto-login is doing, so a silent cycle is not a black box.

**Why P1**: Sem navegação visível, snackbar é o único sinal.

**Acceptance Criteria**:

1. WHEN a cycle runs THEN the controller SHALL emit `AutoLoginStatus` on a broadcast stream: `detected` → `authenticating` → `choosingCharacter` → `done`, or `failed` with a typed `AutoLoginFailure`.
2. WHEN a status is emitted THEN the shell SHALL show exactly one snackbar for it, replacing the previous one, with `failed` in the error colour.
3. WHEN a status carries a character name or server message THEN the snackbar SHALL interpolate it.
4. WHEN any status is rendered in EN or PT THEN the text SHALL come from the catalogs — never a raw key, never an unfilled `{}` (AD-014).

**Independent Test**: widget test resolving every `AutoLoginFailure` in both locales.

---

### P1: Heartbeat de sessão no host sticky ⭐ MVP

**User Story**: As a player with Auto Login enabled, I want the app to notice that I was logged out even when the WebView did not navigate (idle or background keepalive), and silently renew the session on the same numbered host I was playing on.

**Why P1**: Sem probe, o keepalive mantém o processo mas a sessão ASP.NET expira; o jogador só descobre no próximo toque.

**Acceptance Criteria**:

1. WHEN Auto Login is enabled, credentials+character are present, `HostTracker.currentOrigin.host` is a Popmundo host other than `www.popmundo.com`, and no cycle is in flight THEN the system SHALL issue a native HTTP GET to `{currentOrigin}/World/Popmundo.aspx/Character` once per 60 seconds (first probe after `waitUntilReady`, then every 60 s).
2. WHEN that GET is issued THEN it SHALL use the WebView's cookies for that origin (seeded into the `AuthSession` jar immediately before the request), the WebView's User-Agent, and SHALL NOT follow redirects (`followRedirects` off, one hop only).
3. WHEN the response is a 3xx whose resolved `Location` is a login path (`/` or `/Default.aspx`) THEN the system SHALL treat the session as expired and start the existing silent Auto Login cycle (same handshake, same snackbars, same final `loadUrl` to `{assignedHost}/World/Popmundo.aspx`).
4. WHEN the response is 200 THEN the system SHALL treat the session as healthy, ignore the body, write nothing, navigate nowhere, and wait for the next tick.
5. WHEN the GET throws, times out, or returns a non-redirect error status (4xx/5xx other than the logout 3xx) THEN the system SHALL NOT start a login cycle and SHALL wait for the next tick.
6. WHEN `currentOrigin.host` is `www.popmundo.com` OR Auto Login is disabled OR credentials are missing OR a cycle is already in flight THEN that tick SHALL be a no-op (no GET).
7. WHEN the probe URL is built THEN it SHALL be `currentOrigin.replace(path: '/World/Popmundo.aspx/Character')` — not `HostTracker.resolve`, not a literal `www.popmundo.com`, not a stored origin from a previous login.
8. WHEN the app is in Android background with keepalive running THEN the probe timer SHALL keep firing on the main isolate; the FGS isolate SHALL NOT perform the GET, read cookies, or call `loadUrl`.
9. WHEN iOS suspends the process THEN probes MAY pause; this SHALL NOT be treated as logout.
10. WHEN a heartbeat-triggered cycle is in flight THEN a concurrent navigation trigger and the next heartbeat tick SHALL be ignored (`inFlight`).
11. WHEN sequential native calls run (probe then handshake, or handshake hops) THEN they SHALL remain at least 750 ms apart (AD-006).

**Independent Test**: fake `AuthHttpSend` + fake `CookieSource` + virtual clock; host sticky `https://75.popmundo.com`; 302 `Location: /Default.aspx` starts one cycle; 200 does not; `www` host skips the GET; seed cookies appear on the Cookie header of the Character GET; no second hop after the 302.

---

## Edge Cases

- WHEN the login page has no `#aspnetForm` THEN cycle SHALL abort (`missingForm`)
- WHEN the token GET throws THEN cycle SHALL abort with `networkError` and clear `inFlight`
- WHEN the choice POST throws THEN cycle SHALL abort with `networkError` and clear `inFlight`
- WHEN `GetPageNotifications` itself throws THEN the cycle SHALL proceed — a failed poll says nothing about the choice
- WHEN a `<h2>` is pretty-printed across lines or wraps an `<a>` THEN the name SHALL still match
- WHEN a `div.box` has no submit button (informational box) THEN it SHALL be skipped
- WHEN sequential calls run THEN throttle >=750 ms between them (AD-006)
- WHEN the sticky host is `N.` THEN no code path SHALL hardcode `www.popmundo.com` (AD-007)
- WHEN building the ChooseCharacter URL THEN `HostTracker.resolve` SHALL NOT be used — it appends a trailing slash
- WHEN the Character GET 302s to `/Default.aspx` THEN the system SHALL NOT fetch `Default.aspx` as part of the probe
- WHEN the Character GET 302s to a non-login path THEN the system SHALL NOT treat it as logout
- WHEN WebView cookies cannot be read (CookieManager unavailable) THEN that tick SHALL be skipped, not treated as logout
- WHEN the sticky host is `75.popmundo.com` THEN the probe SHALL go to `https://75.popmundo.com/World/Popmundo.aspx/Character` and the Cookie header SHALL only include cookies that match that host (host-only session cookies of `www` MUST NOT be sent)
- WHEN keepalive FGS ticks every 5 s THEN that SHALL NOT cause a Character GET every 5 s — the session probe stays on its own 60 s timer
- WHEN the login POST throws THEN the cycle SHALL abort with `networkError` (no form-navigation fallback; AD-018)

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| UI-01 | Config sidebar item | Execute | Done |
| UI-02 | Config screen fields | Execute | Done |
| UI-03 | Persist KV + SecretStore | Execute | Done |
| UI-04 | Save disabled in-flight | Execute | Done |
| UI-05 | Empty password keeps secret | Execute | Done |
| AUTH-01 | Trigger + inFlight | Execute | Done |
| AUTH-02 | Whole-form POST body | Execute | Done |
| AUTH-03 | redirect follow + landing URL | Execute | Done |
| AUTH-04 | Landed-on-login abort | Execute | Done |
| AUTH-05 | Form-navigation fallback | Execute | Done |
| AUTH-06 | Disabled/missing skip | Execute | Done |
| AUTH-07 | inFlight ignore | Execute | Done |
| AUTH-08 | 750 ms throttle | Execute | Done |
| NAV-01 | Parse boxes by `<h2>` | Execute | Done |
| NAV-02 | Exact full-name POST | Execute | Done |
| NAV-03 | Not-found abort | Execute | Done |
| NAV-04 | Ambiguous abort | Execute | Done |
| NAV-05 | Zero characters abort | Execute | Done |
| NAV-06 | Server-rejected abort | Execute | Done |
| NAV-07 | Always World home on landing host | Execute | Done |
| FDBK-01 | Status stream phases | Execute | Done |
| FDBK-02 | One snackbar per status | Execute | Done |
| FDBK-03 | Name/message interpolation | Execute | Done |
| FDBK-04 | EN/PT catalog coverage | Execute | Done |
| HB-01 | Probe 60 s on sticky host Character URL | Execute | ⚠️ Verified (60 s default untested) |
| HB-02 | Seed WebView jar; do not follow redirect | Execute | ✅ Verified |
| HB-03 | 302 → login path starts Auto Login cycle | Execute | ✅ Verified |
| HB-04 | 200 = healthy; network/5xx ≠ logout | Execute | ✅ Verified |
| HB-05 | Skip www / disabled / missing / inFlight | Execute | ❌ Needs Fix |
| HB-06 | URL from currentOrigin, not resolve/www | Execute | ✅ Verified |
| HB-07 | Main-isolate timer; FGS isolate does not probe | Execute | ⚠️ Spec-precision |
| HB-08 | iOS suspend ≠ logout | Execute | ⚠️ Spec-precision |
| HB-09 | Dual trigger + inFlight | Execute | ✅ Verified |
| HB-10 | 750 ms between probe and handshake | Execute | ❌ Needs Fix |

**Coverage:** 34 total, 32 mapped to tests, 2 unmapped (HB-05 missing-credentials on heartbeat path; HB-10 probe→handshake 750 ms) — see `.specs/features/auto-login/validation.md` Session Heartbeat (AD-019)

---

## Success Criteria

- [x] Two characters sharing a first name resolve to different buttons; a first name alone no longer matches
- [x] Duplicate full names abort instead of being guessed
- [x] The POST body carries the whole form, not just the three VIEWSTATE tokens
- [x] Password never appears in SharedPreferences/KeyValueStore dumps
- [x] The cycle ends on `{origin}/World/Popmundo.aspx` on the host actually landed on
- [x] Every status resolves in EN and PT
- [x] Unit/widget gates pass without live HTTP to popmundo.com
- [x] Logout on `75.popmundo.com` (302 from `/World/Popmundo.aspx/Character` to `/Default.aspx`) renews the session without the WebView having navigated
- [x] Probe never hits `www.popmundo.com/.../Character` after the sticky host is a numbered `N.`
- [x] One Character GET per minute, never per FGS 5 s tick; the 302 is not followed

## Background reliability amendment (2026-10-04, AD-020)

User-Agent resolvido por API nativa no app, ou captura inicial de bridge para clientes sem provider, com timeout de 2 s/cache; probe nativo não depende de renderer pronto. Sync de cookie conclui antes de done; resposta de navegação suspensa não bloqueia novos probes. done/failed em lifecycle não-resumed gera notificação local EN/PT id 2. Critérios e evidências: .specs/features/background-session-reliability/.

Handover em background: origin autenticado pendente guia probes, cookie reads e nova renovação até navegação nativa confirmar host; HostTracker não é mutado pelo HTTP. Navegação real retoma autoridade do tracker.
