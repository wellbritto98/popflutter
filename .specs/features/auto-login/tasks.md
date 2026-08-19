# Auto Login Heartbeat Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user — do not proceed without it.**

---

**Design**: `.specs/features/auto-login/design.md`
**Status**: Done

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec — confirm before Execute. Guidelines found: `CLAUDE.md`, `packages/popmundo_utils` agent (`dart test`, FakePopmundoRuntime, never live HTTP), `packages/popmundo_webview` agent (`flutter test`).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Domain (`CookieSource`, `AuthSession.probe`, `checkSession`) | unit | 1:1 to HB-01..HB-10 ACs + listed edge cases | `packages/popmundo_utils/test/*.dart` | `cd packages/popmundo_utils && dart test` |
| Adapter (`InAppCookieSink.read` / `gameCookieFromInApp`) | unit | Conversion mapping + host-only | `packages/popmundo_webview/test/in_app_cookie_sink_test.dart` | `cd packages/popmundo_webview && flutter test` |
| App wiring | none | Composition only | — | analyze / existing widget tests |
| Docs | none | — | `docs/`, module README | build gate (files exist) |

## Gate Check Commands

> Generated from codebase — confirm before Execute.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After utils unit tasks | `cd packages/popmundo_utils && dart test` |
| Full | After webview adapter tests | `cd packages/popmundo_webview && flutter test` |
| Build | After wiring/docs or phase end | `dart analyze packages/popmundo_utils && flutter analyze packages/popmundo_webview && flutter analyze apps/popmundo_app` plus the test commands of layers touched |

---

## Execution Plan

```
T1 → T2 → T3 → T4 → T5
```

Single batch (5 tasks). Execute inline.

---

## Task Breakdown

### T1: CookieSource port

**What**: Add `CookieSource.read` and make `MemoryCookieSink` implement it with `seed()`.
**Where**: `packages/popmundo_utils/lib/src/autologin/cookie_sink.dart`, `packages/popmundo_utils/test/cookie_source_test.dart`
**Depends on**: None
**Reuses**: `GameCookie.matches`
**Requirement**: HB-02, HB-05 (source skip is controller; jar matching is here)

**Done when**:

- [ ] `CookieSource.read(Uri)` returns cookies that `matches` the URL
- [ ] `MemoryCookieSink.seed` makes cookies readable without `write`
- [ ] A host-only cookie for `www.popmundo.com` is NOT returned for `https://75.popmundo.com/`
- [ ] Gate: `cd packages/popmundo_utils && dart test test/cookie_source_test.dart`

**Tests**: unit
**Gate**: quick
**Commit**: `feat(autologin): add CookieSource to seed the native jar from the WebView`

---

### T2: AuthSession.seed + probe

**What**: Seed the jar and GET once without following redirects.
**Where**: `packages/popmundo_utils/lib/src/autologin/auth_http.dart`, `packages/popmundo_utils/test/auth_session_test.dart`
**Depends on**: T1
**Reuses**: `_headersFor`, `_absorb`, `_cooldown`, `_resolveLocation`
**Requirement**: HB-02, HB-03 (response shape), HB-10

**Done when**:

- [ ] `probe` records exactly one GET and returns the 302 (no second hop to Default.aspx)
- [ ] Seeded host-only cookies appear on the Cookie header of that GET
- [ ] www host-only cookies are not sent to a 75 URL
- [ ] Probe honors the 750 ms cooldown
- [ ] Gate: `cd packages/popmundo_utils && dart test test/auth_session_test.dart`

**Tests**: unit
**Gate**: quick
**Commit**: `feat(autologin): probe Character without following redirects`

---

### T3: Controller session heartbeat

**What**: `checkSession` + 60 s `Timer.periodic`; 302 login path starts `_runLoginCycle`.
**Where**: `packages/popmundo_utils/lib/src/autologin/auto_login_controller.dart`, `packages/popmundo_utils/test/auto_login_controller_test.dart`
**Depends on**: T2
**Reuses**: `_runLoginCycle`, `AspNetForm.isLoginPath`
**Requirement**: HB-01, HB-03, HB-04, HB-05, HB-06, HB-07, HB-08, HB-09, HB-10

**Done when**:

- [ ] Sticky `75.` + 302 `/Default.aspx` starts one cycle (login GET on **75**, not www)
- [ ] Character URL is `currentOrigin.replace(path: '/World/Popmundo.aspx/Character')` — no trailing slash, no www
- [ ] 200 does not start a cycle and does not follow a second hop
- [ ] www host / disabled / missing creds / inFlight / source throw = no GET
- [ ] Network error ≠ cycle
- [ ] Timer uses `Timer.periodic`, not `_sleep` (existing tests stay non-looping)
- [ ] Gate: `cd packages/popmundo_utils && dart test`

**Tests**: unit
**Gate**: quick
**Commit**: `feat(autologin): renew session when Character heartbeat 302s to login`

---

### T4: InAppCookieSink.read

**What**: Implement `CookieSource` on `InAppCookieSink`; pure `gameCookieFromInApp`.
**Where**: `packages/popmundo_webview/lib/src/in_app_cookie_sink.dart`, `packages/popmundo_webview/test/in_app_cookie_sink_test.dart`
**Depends on**: T1
**Reuses**: `sameSitePolicyFor` inverse
**Requirement**: HB-02

**Done when**:

- [ ] `gameCookieFromInApp` maps name/value; null/`url.host` domain → host-only
- [ ] Domain cookie `.popmundo.com` keeps `domainAttribute`
- [ ] `InAppCookieSink` implements `CookieSource`
- [ ] Gate: `cd packages/popmundo_webview && flutter test test/in_app_cookie_sink_test.dart`

**Tests**: unit
**Gate**: full
**Commit**: `feat(webview): read WebView cookies into GameCookie for heartbeat`

---

### T5: App wiring + docs

**What**: Pass the same `InAppCookieSink` as sink and source; sync docs.
**Where**: `apps/popmundo_app/lib/app.dart`, `docs/ARQUITETURA.md`, `docs/OBJETIVO.md`, autologin READMEs, spec traceability
**Depends on**: T3, T4
**Reuses**: existing `InAppCookieSink()` construction
**Requirement**: HB-02, HB-07 (docs: FGS isolate does not probe)

**Done when**:

- [ ] `AutoLoginController` receives `cookieSource` (same instance as sink)
- [ ] ARQUITETURA 6.3 / OBJETIVO fluxo 4 mention heartbeat
- [ ] Module READMEs list CookieSource + Character probe
- [ ] Spec HB-* status → Implementing/Done as appropriate
- [ ] Gate: `flutter analyze apps/popmundo_app`

**Tests**: none
**Gate**: build
**Commit**: `docs(autologin): wire CookieSource and document session heartbeat`

---

## Phase Execution Map

```
Phase 1:  T1 ──→ T2 ──→ T3
Phase 2:  T4 (parallel-ok with T3 after T1; run after T3 in this batch)
Phase 3:  T5
```

Execution is strictly sequential in this batch: T1 → T2 → T3 → T4 → T5.

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 CookieSource | 1 port + test double | ✅ |
| T2 probe/seed | 1 session API | ✅ |
| T3 checkSession | 1 controller behavior | ✅ |
| T4 InApp read | 1 adapter method | ✅ |
| T5 wiring+docs | composition + docs | ⚠️ cohesive finish |

## Diagram-Definition Cross-Check

| Task | Depends On (body) | Diagram Shows | Status |
| ---- | ----------------- | ------------- | ------ |
| T1 | None | start | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T1 | T1 → T4 (after T3 in batch) | ✅ |
| T5 | T3, T4 | T3/T4 → T5 | ✅ |

## Test Co-location Validation

| Task | Code Layer | Matrix Requires | Task Says | Status |
| ---- | ---------- | --------------- | --------- | ------ |
| T1 | Domain | unit | unit | ✅ |
| T2 | Domain | unit | unit | ✅ |
| T3 | Domain | unit | unit | ✅ |
| T4 | Adapter | unit | unit | ✅ |
| T5 | Wiring/docs | none | none | ✅ |
