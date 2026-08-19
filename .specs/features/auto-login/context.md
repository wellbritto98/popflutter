# Auto Login Context

> **Heartbeat (2026-08-19).** Segundo gatilho do Auto Login: probe nativo
> 60 s em `{HostTracker.currentOrigin}/World/Popmundo.aspx/Character` com o
> jar da WebView. 302 `Location: /Default.aspx` = deslogado → mesmo handshake
> AD-018. Não segue o redirect. Não usa `www` nem `HostTracker.resolve`.
> Timer no isolate do app; FGS só mantém o processo (AD-012). Ver `spec.md`.

> **Superseded in part by AD-017 (2026-08-19).** The `redirect: 'manual'` +
> `loadUrl(Location)` hop described below is not implementable — browser fetch
> returns an opaque redirect with no readable `Location`. The shipped flow is
> AD-018 native HTTP (not TimedFetch). `LastUrlStore` no longer exists.

**Gathered:** 2026-08-18; heartbeat 2026-08-19
**Spec:** `.specs/features/auto-login/spec.md`
**Status:** Spec updated — awaiting confirmation before Design/Execute

---

## Feature Boundary

Auto Login configures credentials in the sidebar, detects the ASP.NET login page, POSTs via TimedFetch (`useCache: false`, `redirect: 'manual'`), navigates the WebView on 302 to `Login.aspx?t=…`, POSTs Choose Character for the configured name, then restores the last non-auth Popmundo URL. No DOM click, no Facebook, no Telegram, no live e2e.

---

## Implementation Decisions

### Session heartbeat (2026-08-19)

- Intervalo 60 s; GET nativo único, sem seguir 302.
- URL: `{currentOrigin}/World/Popmundo.aspx/Character` no host numerado sticky (`74.`, `75.`, …).
- Logout = 3xx cuja Location resolvida é `/` ou `/Default.aspx` → ciclo Auto Login existente.
- Cookies: ler jar da WebView → semear `AuthSession` antes do probe; após relogin, `CookieSink.write` como hoje.
- Skip: host ainda `www`, Auto Login off, credenciais faltando, `inFlight`, CookieManager indisponível.
- 200 / rede / 5xx ≠ logout.
- Background: timer no isolate do controller; isolate do FGS não fala com o jogo.

### Login hop (302)

- TimedFetch exposes a response API that can accept 3xx when `acceptRedirect: true` / `redirect: 'manual'`.
- On 302 with `Location` to `*.popmundo.com/Login.aspx?t=…`, call `runtime.loadUrl(absoluteLocation)` so HostTracker and cookies update via real document navigation.
- Do not rely on silent fetch-follow alone to land the session on the game host.

### Password storage

- Non-secret settings (`enabled`, `username`, `characterName`, `status`) in `KeyValueStore` key `autologin.v1`.
- Password only in `SecretStore` (app: `flutter_secure_storage`).
- Empty password field on Save keeps the previous secret if one exists.

### Trigger & character

- Trigger when enabled + credentials present + login page (path `/` or `/Default.aspx`, or login field markers).
- Character matched by submit `value` prefix `Escolher ` or `Choose `; POST uses the button's ASP.NET `name`.
- `ddlStatus` default `0` (Normal).

### Last URL

- Persist full `NavigationEvent.url` for Popmundo hosts except `/`, `/Default.aspx`, `/Login.aspx`, `/World/Popmundo.aspx/ChooseCharacter`.
- Key: `session.last_url.v1`.
- After successful character select: `loadUrl(lastUrl)` or `{origin}/World/Popmundo.aspx`.
- Cold start: `PopmundoWebView(initialUrl: lastUrl ?? HostTracker.defaultOrigin)`.

### UI

- Sidebar item always visible, English strings, `Navigator.push` screen (Userscripts pattern).
- One in-flight auto-login; failure stops (no retry loop).

### Agent's Discretion

- Exact SnackBar copy on save success/failure.
- Whether login GET uses `/` vs `/Default.aspx` based on the triggering path.
- Deduping duplicate NavigationEvents before last-URL write.

### Declined / Undiscussed Gray Areas → Assumptions

All undiscussed items logged in spec Assumptions with agent defaults (trigger paths, character match, status, last-URL filter, English UI, inFlight).

---

## Specific References

- Userscript: `docs/🧚Scodelario's Monitor🧚.user.js` lines ~348 (performAutoLogin), ~349 (selectCharacter), ~672–712 (logout/login detection).
- Live capture: GET www → POST form → 302 `N.popmundo.com/Login.aspx?t=` → ChooseCharacter → character POST.
- Patterns: Userscripts screen + `buildAppMenuItems`; Notifications TimedFetch POST with `useCache: false`.

---

## Deferred Ideas

- Telegram logout alerts
- Facebook login
- Biometric unlock for secure storage
- Auto-retry with backoff
