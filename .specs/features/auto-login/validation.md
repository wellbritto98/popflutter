# Auto Login Validation (re-verify iteration 1)

**Date**: 2026-08-18
**Spec**: `.specs/features/auto-login/spec.md`
**Diff range**: uncommitted working tree vs `a3a75ff` (feature not yet committed; surface under `packages/popmundo_utils`, `packages/popmundo_webview`, `apps/popmundo_app`, `.specs/features/auto-login`)
**Verifier**: independent sub-agent (author ≠ verifier), re-verify after Fix 1 / UI-02 / NAV-02 / edges

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 InPageFetchResult + loadUrl | ✅ Done | Contract + FakePopmundoRuntime |
| T2 TimedFetch.fetchResponse | ✅ Done | acceptRedirect + tests |
| T3 SecretStore + settings + LastUrlStore | ✅ Done | Memory stores + filter + `resolveInitialUrl` |
| T4 AspNetForm | ✅ Done | tokens / PT-EN match / login path |
| T5 AutoLoginController | ✅ Done | happy path + abort/skip/inFlight + World-home + VIEWSTATE |
| T6 hooks.js Location | ✅ Done | webview source assert |
| T7 InAppPopmundoRuntime.loadUrl + headers | ✅ Done | map + throw-if-detached |
| T8 Menu registry | ✅ Done | UI-01 tests |
| T9 AutoLoginScreen + secure store | ✅ Done | widget tests incl. status 0/1/2/4/3 |
| T10 Wire controller + initialUrl | ✅ Done | `app.dart` uses `LastUrlStore.resolveInitialUrl`; NAV-04 unit evidence |

---

## Spec-Anchored Acceptance Criteria

### P1: Configurar Auto Login no sidebar

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| UI-01 menu item always present | `id: 'auto-login'`, label `Auto Login`, with `includeDebugItem: false` | `apps/popmundo_app/test/app_menu_registry_test.dart:14-15` — `expect(items.map((e) => e.id), ['auto-login', 'userscripts'])`; `expect(items.first.label, 'Auto Login')` | ✅ PASS |
| UI-02 screen fields | enabled, username, password obscured, character, status 0/1/2/4/3, Save | Keys `auto_login_screen_test.dart:36-50`; status set `auto_login_screen_test.dart:98-107` — keys `autologin-status-0/1/2/4/3` + labels Normal/Busy/Mobile/Away/Drunk | ✅ PASS |
| UI-03 persist KV + SecretStore; never password in KV | `autologin.v1` without password; secret in SecretStore | `auto_login_screen_test.dart:58-64` — `containsKey('password')` isFalse; `secrets.read(...)` `'test-password-not-real'`; also `autologin_stores_test.dart:21-23` | ✅ PASS |
| UI-04 Save disabled while saving | Save `onPressed` null in-flight | `auto_login_screen_test.dart:134` — `expect(button.onPressed, isNull)` | ✅ PASS |
| UI-05 empty password keeps previous secret | Leave secret unchanged on empty save | `auto_login_screen_test.dart:86-89` — `expect(...read..., 'keep-me')` | ✅ PASS |

### P1: Auto-login via TimedFetch + loadUrl

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| AUTH-01 trigger + at most one cycle | Login path starts cycle; inFlight lock | Path trigger covered via controller nav to `/` + `AspNetForm.isLoginPath` (`aspnet_form_test.dart:51-54`); concurrency `auto_login_controller_test.dart:213` — `expect(getStarts.length, 1)`. Note: HTML `looksLikeLoginForm` helper tested (`aspnet_form_test.dart:32-34`) but not used as alternate nav trigger (path `/` / `/Default.aspx` is the live gate). | ✅ PASS |
| AUTH-02 GET tokens + POST form fields + useCache:false + redirect manual | Tokens + named fields + `redirect: 'manual'` + accept 3xx | Happy path `auto_login_controller_test.dart:82-84` — `redirect`/`body` username+password; TimedFetch `timed_fetch_test.dart:118-125` acceptRedirect; impl body fields `auto_login_controller.dart:86-105` | ✅ PASS |
| AUTH-03 302 → loadUrl(Location) | `runtime.loadUrl` with absolute Location | `auto_login_controller_test.dart:122-126` — `loadUrlCalls` non-empty; contains `74.popmundo.com/Login.aspx`; webview `popmundo_webview_test.dart:69-71`, `:85` | ✅ PASS |
| AUTH-04 200+form abort | No choose; no loop | `auto_login_controller_test.dart:165-169` — `loadUrlCalls` empty; no ChooseCharacter fetch | ✅ PASS |
| AUTH-05 disabled/missing skip | No cycle | `auto_login_controller_test.dart:184` / `:193` — `fetchCalls` empty | ✅ PASS |
| AUTH-06 inFlight ignore second | Second trigger ignored | `auto_login_controller_test.dart:213` — `getStarts.length == 1` | ✅ PASS |

### P1: Choose character + restore last URL

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| ------------------------- | -------------------- | ----------------------- | ------ |
| NAV-01 ChooseCharacter GET+POST match | Match Escolher/Choose; POST button name | Happy path body contains encoded button name `auto_login_controller_test.dart:99-106`; match PT/EN `aspnet_form_test.dart:40-47` | ✅ PASS |
| NAV-02 restore last URL else World home | loadUrl last eligible OR `{origin}/World/Popmundo.aspx` | Happy path last URL `auto_login_controller_test.dart:140-143`; ELSE World home `auto_login_controller_test.dart:254-257` — `https://74.popmundo.com/World/Popmundo.aspx` | ✅ PASS |
| NAV-03 persist non-auth NavigationEvent | Key `session.last_url.v1`; reject auth paths | `autologin_stores_test.dart:44-64` — auth → null; Character path persisted; wiring `app.dart:103-104` | ✅ PASS |
| NAV-04 cold start initialUrl | Persisted last eligible else defaultOrigin | Seam `autologin_stores_test.dart:67-81` — eligible kept; `null`/`''` → `HostTracker.defaultOrigin`; composition `app.dart:204` — `initialUrl: LastUrlStore.resolveInitialUrl(_initialUrl)` | ✅ PASS |
| NAV-05 missing character abort | No forced restore navigation | `auto_login_controller_test.dart:317-322` — no `Character/99` in loadUrlCalls | ✅ PASS |

**Status**: ✅ All 15 ACs have `file:line` evidence (prior gaps NAV-04 / UI-02 / NAV-02 closed)

---

## Discrimination Sensor

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| 1 | `last_url_store.dart:resolveInitialUrl` | Always return `HostTracker.defaultOrigin` (ignore stored last URL) | ✅ Killed — `resolveInitialUrl uses last eligible…` expected Character URL, got `www.popmundo.com` |
| 2 | `auto_login_controller.dart` World-home branch | `loadUrl` path `/World/WRONG.aspx` instead of `/World/Popmundo.aspx` | ✅ Killed — `null last URL restores World home (NAV-02)` expected Popmundo.aspx, got WRONG.aspx |

**Sensor depth**: lightweight (2 targeted mutations on previously failing ACs)
**Result**: 2/2 killed — PASS ✅
**Scratch**: `/tmp/*.bak`; md5 restored to pre-mutation; no `SENSOR MUTANT` left; autologin_stores + auto_login_controller suites re-green after restore.

---

## Interactive UAT Results

Not performed (automated Verifier pass only; live popmundo.com e2e out of scope).

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns (TimedFetch / FakeRuntime / sidebar) | ✅ |
| Spec-anchored outcome check | ✅ |
| Per-layer Coverage Expectation | ✅ Domain + UI + adapter covered; NAV-04 via testable seam (not full PopmundoHome widget mount) |
| Every test maps to AC / edge / Done-when | ✅ |
| Documented guidelines: `CLAUDE.md` / tasks matrix | ✅ |

---

## Edge Cases

- [x] Login HTML lacks VIEWSTATE → abort — `auto_login_controller_test.dart:260-273`
- [ ] Relative Location resolved before loadUrl — **impl** `_resolveLocation` (`auto_login_controller.dart:184-199`); **no dedicated test**
- [ ] Non-Popmundo Location abort — **impl** `isPopmundoUri` check (`:119`); **no dedicated test**
- [x] Zero / unmatched character buttons abort — missing-character test
- [ ] TimedFetch throws → abort + clear inFlight — **impl** catch (`:124-128`, `:175-178`); **no dedicated test**
- [x] Throttle ≥750 ms between sequential calls — `timed_fetch_test.dart:34-49` (shared queue)
- [x] No hardcoded sticky host after navigate — TimedFetch via `currentOrigin`
- [x] ChooseCharacter path without getServerLink trailing slash — absolute path in controller

Remaining untested edges are hardening-only; not blocking MVP ACs.

---

## Gate Check

- **Gate command**:
  - `cd packages/popmundo_utils && dart test` → **103 passed**, 0 failed
  - `cd packages/popmundo_webview && flutter test` → **24 passed**, 0 failed
  - `cd apps/popmundo_app && flutter test` → **36 passed**, 0 failed
- **Tests**: 163 passed across three packages, 0 failed, 0 skipped
- **Delta vs prior validation (159)**: +4 (NAV-02 World-home, VIEWSTATE abort, UI-02 status dropdown, NAV-04 resolveInitialUrl)
- **Failures**: none

---

## Fix Plans

None — prior Fix 1 / UI-02 / NAV-02 / VIEWSTATE gaps closed.

Optional hardening (non-blocking): relative Location, non-Popmundo Location, TimedFetchException clears inFlight.

---

## Requirement Traceability Update

| Requirement | Previous Status (iter 0) | New Status |
| ----------- | ------------------------ | ---------- |
| UI-01 | ✅ Verified | ✅ Verified |
| UI-02 | ⚠️ Shallow | ✅ Verified |
| UI-03 | ✅ Verified | ✅ Verified |
| UI-04 | ✅ Verified | ✅ Verified |
| AUTH-01 | ⚠️ Partial | ✅ Verified (path gate) |
| AUTH-02 | ✅ Verified | ✅ Verified |
| AUTH-03 | ✅ Verified | ✅ Verified |
| AUTH-04 | ✅ Verified | ✅ Verified |
| AUTH-05 | ✅ Verified | ✅ Verified |
| AUTH-06 | ✅ Verified | ✅ Verified |
| NAV-01 | ✅ Verified | ✅ Verified |
| NAV-02 | ⚠️ Partial | ✅ Verified |
| NAV-03 | ✅ Verified | ✅ Verified |
| NAV-04 | ❌ Needs Fix | ✅ Verified |
| NAV-05 | ✅ Verified | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready (PASS)

**Spec-anchored check**: 15/15 PASS with `file:line` evidence
**Sensor**: 2/2 mutations killed (NAV-04 + NAV-02)
**Gate**: 163 tests passed

**What works**: Settings UI + SecretStore isolation, status dropdown 0/1/2/4/3, TimedFetch redirect-manual, controller happy path (302→loadUrl→choose→restore), World-home fallback, VIEWSTATE abort, cold-start `resolveInitialUrl`, last-URL auth filter.

**Issues found**: none blocking. Optional edge tests still absent (relative/non-Popmundo Location; TimedFetchException).

**Next steps**: Feature verification complete; commit when requested.

## Lessons signals

None — clean PASS (no surviving mutants, no AC gaps, no gate_fail).
