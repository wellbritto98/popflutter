# Auto Login Specification

## Problem Statement

Quando a sessão do Popmundo expira, o jogador volta ao formulário ASP.NET em `/` ou `/Default.aspx`. O userscript de referência preenche o DOM e clica; no Popflutter o login deve ser um POST in-page via TimedFetch (throttle AD-006), com hop 302 como navegação real do WebView (host sticky AD-007), escolha de personagem e restore da última URL Popmundo visitada antes do disconnect — configurável pelo item de sidebar "Auto Login".

## Goals

- [ ] Jogador configura usuário, senha, personagem e status no sidebar; senha fica em cofre seguro
- [ ] Com Auto Login enabled, ao detectar página de login o app autentica via TimedFetch + `loadUrl` sem clicar no form
- [ ] Após Choose Character, o WebView restaura a última URL Popmundo não-auth (ou World home)

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Clique no formulário de login (DOM fill) | Substituído por POST TimedFetch |
| Facebook OAuth | Fora do fluxo mapeado |
| Telegram / notificações de logout | Userscript-only; não pedido |
| Retry infinito / polling agressivo | Um ciclo por detecção; inFlight bloqueia |
| E2E live contra popmundo.com | Wrapper policy / ToS |
| i18n | Strings nativas em inglês |
| Mutar intercept (AD-003) | Observe-only permanece |
| Gameplay do userscript (saúde/humor/itens) | Outro produto |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Hop 302 | TimedFetch `redirect: 'manual'` + `runtime.loadUrl(Location)` | Pedido explícito (discuss) | y |
| Senha | `flutter_secure_storage` via `SecretStore`; settings não-secretos em `KeyValueStore` | Pedido explícito (discuss) | y |
| Gatilho | Form de login visível (`/` / `/Default.aspx` / campos `ucLogin`) + enabled + credenciais | Alinhado ao userscript | y (agent) |
| Personagem | Nome; match no `value` do submit (`Escolher X` / `Choose X`); usa `name=` ASP.NET real | Captura + userscript | y (agent) |
| `ddlStatus` | Default `0` (Normal); editável na UI | Captura de request | y (agent) |
| Last URL | Persistir `NavigationEvent.url` Popmundo exceto paths de auth; cold start `initialUrl` | Pedido + HostTracker só guarda origin | y (agent) |
| UI nativa | Inglês; item sempre visível | Padrão sidebar | y (agent) |
| Concurrency | Um auto-login por vez (`inFlight`); falha 200+form = parar | Evita loop / throttle abuse | y (agent) |

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

### P1: Auto-login via TimedFetch + loadUrl ⭐ MVP

**User Story**: As a player with Auto Login enabled, when I land on the login page I want the app to POST credentials and follow the game redirect so I reach Choose Character without filling the form.

**Why P1**: É o núcleo da feature.

**Acceptance Criteria**:

1. WHEN Auto Login is enabled, credentials+character are present, and a Popmundo navigation URL indicates the login page (path `/` or `/Default.aspx`, or HTML containing login username field markers) THEN the system SHALL start at most one in-flight auto-login cycle.
2. WHEN the cycle starts THEN the system SHALL GET the login page HTML via TimedFetch with `useCache: false`, parse `__VIEWSTATE`, `__VIEWSTATEGENERATOR`, `__EVENTVALIDATION`, and POST `application/x-www-form-urlencoded` to the current sticky origin path `/` (or `/Default.aspx` if that was the page) with fields `ctl00$cphRightColumn$ucLogin$txtUsername`, `txtPassword`, `ddlStatus`, `btnLogin=OK!` plus the ASP.NET tokens, using TimedFetch with `useCache: false` and `redirect: 'manual'` (accept 3xx).
3. WHEN the login POST returns status 302 with a `Location` header to `*.popmundo.com/Login.aspx?t=…` THEN the system SHALL call `runtime.loadUrl` with that absolute Location (updating HostTracker via real navigation).
4. WHEN the login POST returns status 200 (or any non-redirect success that still looks like the login form) THEN the system SHALL abort the cycle without Choose Character and without looping.
5. WHEN Auto Login is disabled OR username/password/character missing THEN the system SHALL NOT start a cycle.
6. WHEN a cycle is already in flight THEN a second trigger SHALL be ignored until the first finishes (success or abort).

**Independent Test**: `FakePopmundoRuntime` + TimedFetch with virtual clock; assert POST options, `useCache: false`, `loadUrl` called with Location, no choose on 200+form.

---

### P1: Choose character + restore last URL ⭐ MVP

**User Story**: As a player after successful login hop, I want my configured character selected and then return to the page I was on before disconnect.

**Why P1**: Sem personagem o jogo não entra; sem last URL o cold start sempre cai em www.

**Acceptance Criteria**:

1. WHEN navigation reaches `/World/Popmundo.aspx/ChooseCharacter` during an in-flight cycle THEN the system SHALL GET that page via TimedFetch (`useCache: false`), find the submit whose `value` matches the configured character name with prefix `Escolher ` or `Choose `, and POST the button's `name` + ASP.NET tokens to `/World/Popmundo.aspx/ChooseCharacter` with `useCache: false`.
2. WHEN the character POST succeeds (2xx after follow or document navigation equivalent) THEN the system SHALL `loadUrl` the persisted last URL if present and eligible; ELSE `loadUrl` `{currentOrigin}/World/Popmundo.aspx`.
3. WHEN a Popmundo `NavigationEvent` fires for a URL that is NOT an auth path (`/`, `/Default.aspx`, `/Login.aspx`, `/World/Popmundo.aspx/ChooseCharacter`) THEN the system SHALL persist that full URL to `KeyValueStore` key `session.last_url.v1`.
4. WHEN the WebView is first created THEN `initialUrl` SHALL be the persisted last eligible URL if any, ELSE `HostTracker.defaultOrigin`.
5. WHEN the character button matching the configured name is not found THEN the system SHALL abort the cycle without restoring last URL via forced navigation (stay on Choose Character).

**Independent Test**: Unit tests for last-URL filter + character button match (PT/EN); controller test for choose POST + restore; widget/composition test that `initialUrl` is passed when store has a value (fake).

---

## Edge Cases

- WHEN login HTML lacks VIEWSTATE tokens THEN cycle SHALL abort
- WHEN Location is relative THEN system SHALL resolve against the response URL / current origin before `loadUrl`
- WHEN Location host is not Popmundo THEN system SHALL abort (no openExternal for auth hop)
- WHEN ChooseCharacter HTML has zero character buttons THEN cycle SHALL abort
- WHEN TimedFetch throws (non-2xx without acceptRedirect, timeout, bridge not ready) THEN cycle SHALL abort and clear inFlight
- WHEN GET tokens and POST login are sequential THEN throttle ≥750 ms between them (AD-006)
- WHEN absolute `www.popmundo.com` is hardcoded after sticky host is already `N.` THEN system SHALL NOT do that — use `currentOrigin` (AD-007)
- WHEN `getServerLink`/`resolve` would add trailing slash to ChooseCharacter THEN auto-login SHALL NOT use it for these paths

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| UI-01 | P1: Config sidebar | Design | Pending |
| UI-02 | P1: Config screen fields | Design | Pending |
| UI-03 | P1: Persist KV + SecretStore | Design | Pending |
| UI-04 | P1: Save disabled in-flight | Design | Pending |
| AUTH-01 | P1: Trigger + inFlight | Design | Pending |
| AUTH-02 | P1: GET tokens + POST login | Design | Pending |
| AUTH-03 | P1: 302 → loadUrl | Design | Pending |
| AUTH-04 | P1: 200 abort | Design | Pending |
| AUTH-05 | P1: Disabled/missing skip | Design | Pending |
| AUTH-06 | P1: inFlight ignore | Design | Pending |
| NAV-01 | P1: Choose character POST | Design | Pending |
| NAV-02 | P1: Restore last URL | Design | Pending |
| NAV-03 | P1: Persist last URL | Design | Pending |
| NAV-04 | P1: Cold start initialUrl | Design | Pending |
| NAV-05 | P1: Missing character abort | Design | Pending |

**Coverage:** 15 total, 0 mapped to tasks, 15 unmapped

---

## Success Criteria

- [ ] Com Auto Login configured, landing on login page completes hop to Choose Character then selected character without DOM click
- [ ] Password never appears in SharedPreferences/KeyValueStore dumps
- [ ] After reconnect, WebView returns to last non-auth Popmundo path when one was stored
- [ ] Unit/widget gates pass without live HTTP to popmundo.com
