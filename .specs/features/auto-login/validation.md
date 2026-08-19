# Auto Login Validation (rework: full-name matching + silent cycle)

**Date**: 2026-08-19
**Spec**: `.specs/features/auto-login/spec.md`
**Decision**: AD-017 (supersedes AD-011)
**Diff range**: uncommitted working tree vs `6e5dbaa`
**Scope**: `packages/popmundo_utils/lib/src/autologin/**`, `apps/popmundo_app/lib/app.dart`, `apps/popmundo_app/lib/autologin/auto_login_messages.dart`, `apps/popmundo_app/assets/translations/{en,pt}.json`

---

## Spec-Anchored Acceptance Criteria

### Auto-login silencioso via TimedFetch

| Criterion | `file:line` evidence | Result |
| --------- | -------------------- | ------ |
| AUTH-01 trigger + one cycle | `auto_login_controller.dart:104-116` sync `_inFlight` lock; `auto_login_controller_test.dart` *a second trigger while in flight is ignored* — `expect(getStarts, 1)` | PASS |
| AUTH-02 whole-form POST body | `auto_login_controller.dart:145-152`; test *login POST carries the whole form, not just the tokens* asserts `ddlLanguage=2` survives alongside the three tokens and `btnLogin=OK!` is set explicitly | PASS |
| AUTH-03 redirect follow + landing URL | `auto_login_controller.dart:156-168` (no `redirect` key ⇒ browser default); verdict from `result.url` at `:170-176` | PASS |
| AUTH-04 landed-on-login abort | test *landing back on the login page means bad credentials* — no `loadUrl`, `failure == invalidCredentials` | PASS |
| AUTH-05 form-navigation fallback | `auto_login_controller.dart:177-183`; test *submits a real form when the login POST fails cross-origin* asserts `form.submit()` carries `__VIEWSTATE` + username, and *completes from the live DOM after the navigation lands* drives it to World home | PASS |
| AUTH-06 disabled/missing skip | test group *guards* — three cases assert `posts` and `statuses` both empty | PASS |
| AUTH-07 inFlight ignore | as AUTH-01 | PASS |
| AUTH-08 750 ms throttle | test *keeps at least 750ms between the sequential calls (AD-006)* asserts the virtual-clock gap between all three calls | PASS |

### Choose character por nome completo

| Criterion | `file:line` evidence | Result |
| --------- | -------------------- | ------ |
| NAV-01 parse boxes by `<h2>` | `aspnet_form.dart:parseCharacterChoices`; tests cover nested `<a>`, `&#233;` entities, whitespace-collapsed heading, and skipping a box with no submit | PASS |
| NAV-02 exact full-name POST | test *choice POST targets the landing host and the matched button* — body contains `…repCharacters$ctl01$…`, not `ctl00`, and `__VIEWSTATE=VS2` from the login response document | PASS |
| NAV-03 not-found abort | tests *a first name alone no longer matches* (unit) and *a first name alone no longer matches anything* (controller) | PASS |
| NAV-04 ambiguous abort | tests *two boxes with the same full name are ambiguous, never guessed* and *duplicate full names abort instead of guessing* | PASS |
| NAV-05 zero characters abort | test *zero character boxes aborts* | PASS |
| NAV-06 server-rejected abort | test *a server error notification stops before navigating* — `serverMessage == 'Character unavailable'`, `loadUrlCalls` empty | PASS |
| NAV-07 World home on landing host | test *logs in, picks the character and lands on world home* — `loadUrlCalls == ['https://75.popmundo.com/World/Popmundo.aspx']` while the tracker still points at `74.` | PASS |

### Feedback do ciclo

| Criterion | `file:line` evidence | Result |
| --------- | -------------------- | ------ |
| FDBK-01 status phases | test *emits detected → authenticating → choosing → done* asserts the exact ordered list | PASS |
| FDBK-02 one snackbar per status | `app.dart:_onAutoLoginStatus` — `removeCurrentSnackBar()` then `showSnackBar`, error colour on `failed` | PASS |
| FDBK-03 interpolation | `auto_login_messages_test.dart` — *character name is interpolated*, *the server message is surfaced verbatim* | PASS |
| FDBK-04 EN/PT coverage | *every failure resolves in both catalogs (no raw keys)* iterates all `AutoLoginFailure` × {en, pt}, rejecting raw keys and unfilled `{}` | PASS |

**Status**: 24/24 criteria with evidence.

---

## Discrimination Sensor

| # | Mutation | Killed? |
| - | -------- | ------- |
| 1 | `matchCharacterChoice` matches the submit `value` suffix — i.e. the original first-name bug | Killed — 10 tests fail, incl. *distinguishes characters sharing a first name* |
| 2 | Ambiguous match silently returns `hits.first` | Killed — *two boxes with the same full name are ambiguous, never guessed*, *duplicate full names abort instead of guessing* |
| 3 | `AspNetFormData.fromDocument` serializes only `__`-prefixed fields (the old cherry-pick) | Killed — 7 tests fail, incl. *keeps controls a token-only body would drop* |
| 4 | Choose POST built from `runtime.host.currentOrigin` instead of the landing host | Killed — *choice POST targets the landing host and the matched button* |

**Result**: 4/4 killed. Files restored and re-verified green (md5 checked; `dart test` back to 145 passed).

---

## Gate Check

| Command | Result |
| ------- | ------ |
| `flutter analyze packages/popmundo_utils packages/popmundo_webview apps/popmundo_app` | No issues found |
| `flutter analyze integration_test` (app) | No issues found |
| `cd packages/popmundo_utils && dart test` | 145 passed |
| `cd packages/popmundo_webview && flutter test` | 25 passed |
| `cd apps/popmundo_app && flutter test` | 78 passed |

**Total**: 248 passed, 0 failed. Baseline before this change was 163 (+85).

---

## Issues Found During Execution

1. **`autologin.status` key collision.** The new snackbar namespace was first added as `autologin.status.*`, which overwrote the existing `autologin.status` Status-dropdown label; `AutoLoginScreen` then threw `_Map<String, dynamic> is not a subtype of String`. Caught by four pre-existing `auto_login_screen_test.dart` tests. Namespace renamed to `autologin.cycle.*` and the `status` label restored from `HEAD`; a key-diff against `HEAD` confirms nothing else was removed or changed except the intended `characterHelp` rewrite, with EN/PT at full parity.
2. **`FakePopmundoRuntime` navigation does not update `HostTracker`.** Production `onNativeNavigation` does both; the fake keeps them separate, so the first controller test posted to `www.popmundo.com`. Tests now call `runtime.host.onNavigation(...)` alongside `emitNavigation(...)` to mirror production.

---

## Not Verified

- **No live run against popmundo.com.** The repo bans live e2e, and the session could not authenticate. The ChooseCharacter DOM contract (`div.box` > `h2` + `input[type=submit]`) comes from the user's Puppeteer snippet, the captured POST payload, and `Popmundo-Utils/features/manage-player-db.js`. Login form field names and the host-only auth cookie **were** confirmed against the live public endpoints without authenticating.
- **Which branch runs on cold start** (silent vs form-navigation fallback) depends on whether the game's login 302 crosses origins from `www`. Both paths are implemented and tested; the real-world answer still needs one DevTools capture.
- Device UAT (steps in the plan) is pending.

---

## Summary

**Overall**: Ready — 24/24 criteria evidenced, 4/4 mutations killed, 248 tests green.

**What changed behaviourally**: characters are matched by full name and duplicates abort instead of being guessed; POST bodies carry the whole form; the cycle is silent with a navigation fallback and ends on the world home page of the host it landed on; every step reports through a localized snackbar; `LastUrlStore` is gone.

## Instrumentation (2026-08-19, follow-up)

The cycle failed on device with the character not being found, so the controller
was instrumented end to end. `AutoLoginTrace` is an injectable sink
(`auto_login_trace.dart`); the default writes to `dart:developer` under the
`autologin` tag, and the controller tests inject a capturing list.

Traced: listener attach, every navigation with its path and flags, guard
outcomes, the login GET, the full login POST body (**password masked**, long
values elided), the POST result with `status`/`landedOn`/body size, every parsed
candidate, and on failure `AspNetForm.describeDocument` plus the raw HTML in
800-char chunks (logcat truncates ~4 KB per entry).

`describeDocument` deliberately reports more than the parser uses — `div.box`
counts alongside `.box`, `[class*=box]`, every heading, every submit, `<button>`,
`input[type=image]`, anything named `*ChooseCharacter*`, and links to
`/Character/` — so a theme whose markup differs from the desktop capture is
identifiable from one log instead of a guess.

Covered by four tests in the *diagnostics* group, including one asserting the
password value never reaches the trace while the field name does, and one
asserting a non-`div.box` layout is reported rather than silently counted as
zero.

### `test_live/` repaired

The pre-existing (untracked) live tier did not compile: `auto_login_flow_test.dart`
referenced a `LiveCredentials` type that was never written and did not import
`support/live_config.dart`. Added the type and the import; the suite now analyzes
clean and skips with a clear reason when the environment is unset. It is the
fastest route to the real ChooseCharacter markup, since it runs outside the app.

## Device run (2026-08-19) — root cause found and fixed

The instrumented build gave a conclusive trace.

**Confirmed by the log**: the login POST *is* cross-origin. `www.popmundo.com` →
`74.popmundo.com//Login.aspx?t=…` was blocked with *"No 'Access-Control-Allow-Origin'
header"*, the fallback fired, and the injected-form navigation carried the session
through — exactly the branch AD-017 predicted. That answers the open question left
in the plan: **on cold start the fallback path is the one that runs.**

**Root cause of the failure**: the fallback read the live DOM too early. The
navigation callback fires while the *previous* document is still mounted, so
`document.documentElement.outerHTML` returned the login page. The dump proved it —
`<h1>Bem vindo ao Popmundo</h1>`, `inputs named *ChooseCharacter*: 0`, and the
controller's own injected `<form>` still in the markup. The two "candidates" it
found were the login and mobile-theme boxes. Callback order from the log:

```
onLoadStop          {url: …/ChooseCharacter}
[autologin] fallback: landed on ChooseCharacter, reading live DOM
[autologin] live DOM read: 54162 chars      <- read here
onLoadStart         {url: …/ChooseCharacter} <- new document only starts now
onPageCommitVisible {url: …/ChooseCharacter}
```

**Fix**: `_readDomSnapshot` now takes `location.href`, `document.readyState` and
the markup in **one** `evaluate`, so they cannot describe different documents.
`_runChooseCharacterFromLiveDom` polls that snapshot (20 × 300 ms) until the
location is ChooseCharacter and the document has parsed, then proceeds; it aborts
with `networkError` if the budget runs out, and a `_choosing` guard stops a second
navigation event from starting a parallel poll. `div.box`/`h2` was never disproven
— the parser had simply never been shown the right page.

**Regression, found by this run**: the page dump printed the password in clear
text, because the injected form keeps it as a plain `value` attribute and only
`describeFields` was masking. `traceChunked` now redacts through
`redactSecrets`, which strips both the literal secret the caller passes and any
`value` on a password-named input. Verified against the exact markup from the log.

### Sensor (follow-up)

| # | Mutation | Killed? |
| - | -------- | ------- |
| 5 | Accept the first DOM snapshot without checking its URL (the shipped bug) | Killed — 4 stale-DOM tests |
| 6 | `traceChunked` dumps the body unredacted | Killed — *a page dump never contains the password* |
| 7 | Drop literal-secret redaction, keep only the structural regex | Survived — by design; the regex already covers the observed case |

Gate after the fix: analyzer clean; **154 / 25 / 78 = 257 tests**, 0 failed.

## Native HTTP handshake (2026-08-19, AD-018)

The instrumented run proved the cross-origin hop is structural, not incidental:
the login POST on `www` answers `302` to `N.popmundo.com//Login.aspx?t=…` and the
in-page fetch dies with *"No 'Access-Control-Allow-Origin' header"*. Two
consecutive runs were assigned `74.` and then `75.`, so the host is picked per
login and cannot be pinned in advance. On the user's decision (after the headless
alternative was offered), the handshake moved to native `dart:io`.

**New surface**

| File | Role |
| ---- | ---- |
| `autologin/game_cookie.dart` | `Set-Cookie` model + parser; keeps `host` and `domainAttribute` apart so a host-only cookie is never widened |
| `autologin/auth_http.dart` | `AuthSession`: cookie jar, manual hop-by-hop redirects, 750 ms cooldown, injectable transport |
| `autologin/auth_http_io.dart` | The only file that touches `dart:io` |
| `autologin/cookie_sink.dart` | Port + `MemoryCookieSink` |
| `popmundo_webview/in_app_cookie_sink.dart` | `CookieManager.setCookie` adapter |

The controller now runs the whole handshake off-screen and copies the jar into
the WebView **before** the single `loadUrl`. `_planChoice` was extracted so the
native and fallback paths share one matching implementation.

### Criteria evidence

| Criterion | Evidence | Result |
| --------- | -------- | ------ |
| Whole-form login body | `auto_login_controller_test.dart` *the login POST carries the whole form* — `ddlLanguage=50` survives | PASS |
| Hop-by-hop cookie capture | `auth_session_test.dart` *captures the auth cookie, which only the last host sets* | PASS |
| 302 after POST becomes GET | *a 302 after POST is re-issued as GET without the body* | PASS |
| Host-only scope preserved | *a host-only cookie goes to its host and nowhere else*; *sends the numbered host cookie on the last hop only* | PASS |
| WebView User-Agent | *sends the WebView user agent, not the Dart default* | PASS |
| Host from the chain, not stored | *signs in and lands on the world home of the assigned host* | PASS |
| Cookies synced before navigating | *syncs cookies before navigating, or the load is unauthenticated* | PASS |
| Nothing visible | *never navigates the WebView through the login pages* — no `form.submit()`, no in-page fetch, one `loadUrl` | PASS |
| No visible path at all | *never navigates the WebView through the login pages* + the fallback machinery is gone | PASS |
| 750 ms cooldown | *holds the 750ms cooldown between hops (AD-006)* | PASS |

Cookie parsing is tested against the **verbatim** `Set-Cookie` lines observed on
device and by curl, including the dashed expiry spelling and the cleared auth
cookie.

### Sensor

| # | Mutation | Killed? |
| - | -------- | ------- |
| 1 | Skip `cookieSink.write` | Killed |
| 2 | Treat every cookie as a domain cookie | Killed — 4 tests |
| 3 | Use the starting origin instead of the assigned host | Killed — 4 tests |
| 4 | Keep POST across a 302 instead of switching to GET | Killed — 3 tests |
| 5 | Send every jar cookie regardless of host | Killed |
| 6 | Fall back to the default UA instead of the WebView's | Killed |

**6/6 killed**, files restored, suites green.

Gate: analyzer clean (3 packages + `integration_test`); **173 / 28 / 78 = 279
tests**, 0 failed.

### Not verified

The handshake has **not been run against the live game**. Every assertion above
is against a scripted server replaying the observed chain. What a device run
still has to confirm: that the game accepts the native client at all (it may
fingerprint beyond the UA), and that the synced cookies really authenticate the
WebView's next page load. The trace prints the full chain and the cookies being
synced, so a failure will be readable.

## Cleanup (2026-08-19)

With the native handshake proven in tests, everything the old in-page design
left behind was removed, so there is one path and no second one to reason
about:

| Removed | Why it was there |
| ------- | ---------------- |
| `_startFormNavigationFallback`, `_submitFormNavigation` | The visible `<form>` submit that worked around CORS |
| `_runChooseCharacterFromLiveDom`, `_readDomSnapshot`, `_DomSnapshot`, `domPoll*` | DOM polling, only ever needed because a navigation preceded the parse |
| `_chooseCharacter` (in-page variant), `_awaitingChooseCharacter`, `_choosing` | State machine of the navigation flow |
| `timedFetch` and `notifications` on the controller | Only reachable from the fallback; `TimedFetch` is still used by `GmHostHandler`, `Notifications` predates this feature and stays in the package |
| `InPageFetchResult.locationHeader` | Added for the `redirect: 'manual'` design that was never implementable |
| `AspNetForm.describeAncestry` | Diagnostic helper that ended up never being called |

Also de-duplicated: the controller was rebuilding the login body by hand
alongside `AutoLoginRequests.loginBody`; it now calls it, so the live tier and
the controller exercise the same builder.

**Consequence, deliberate**: a transport failure now aborts with `networkError`
instead of degrading to a visible login. If the game refuses the native client,
Auto Login fails rather than falling back.

Sensor re-run after the cleanup — 5/5 killed (no cookie sync; host-only widened
to a domain cookie; starting origin instead of the assigned host; `btnLogin`
dropped from the login body; POST kept across a 302).

Gate after cleanup: analyzer clean on three packages + `integration_test`;
**172 / 28 / 78 = 278 tests**, 0 failed.

## Lessons signals

- A new i18n key namespace can silently shadow an existing leaf key of the same name. Worth a catalog-shape check (leaf vs map) whenever a nested namespace is introduced under an existing prefix.
