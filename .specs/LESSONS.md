# LESSONS — auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation — do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 — Assert the concrete persistence mechanism in unit tests and keep OS-level session survival as a device UAT criterion
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `webview-session` · harmful: 0
- features: popmundo-wrapper
- evidence: SESS-01 validation.md cookie relaunch (webview-session)
- last seen: 2026-08-18T00:05:39Z

### L-002 — Assert empty HTTP response bodies are rejected with zero catalog writes, not only network/parse failures
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/userscript` · harmful: 0
- features: userscript-manager
- evidence: edge: empty response body (packages/popmundo_utils/userscript)
- last seen: 2026-08-18T02:39:06Z

### L-003 — When UI disables actions during an in-flight operation, assert the disabled state in a widget test with a deferred/async stub
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: userscript-manager
- evidence: edge: import-in-progress disables add (apps/popmundo_app)
- last seen: 2026-08-18T02:39:06Z

### L-004 — Every rejected header in an honor/reject matrix needs a dedicated unit assertion, not only sibling headers
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/userscript` · harmful: 0
- features: userscript-manager
- evidence: USM-04 @inject-into (packages/popmundo_utils/userscript)
- last seen: 2026-08-18T02:39:06Z

### L-005 — Composition wiring that sets WebView initialUrl from a store must have a widget or fake-runtime test asserting the exact URL, not only the production bootstrap code
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: auto-login
- evidence: NAV-04 / validation.md Gap (apps/popmundo_app)
- last seen: 2026-08-18T14:16:03Z

### L-006 — When a settings screen AC lists exact enum option values, assert the option set in the widget test rather than only exercising one save path
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: auto-login
- evidence: UI-02 status dropdown / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T14:16:03Z

### L-007 — Controller abort branches listed in the feature edge-case table need dedicated tests, not only happy-path and one miss path
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils` · harmful: 0
- features: auto-login
- evidence: edge cases / validation.md Edge Cases (packages/popmundo_utils)
- last seen: 2026-08-18T14:16:03Z

### L-008 — When a spec names an exact user-visible string (notification title, label), assert that string in a test — production-only presence is not evidence-or-zero
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: FGS-01 / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

### L-009 — Independence claims (bootstrap must not block WebView) need an explicit test or a documented UAT/checklist item — wiring comments alone do not close the AC
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: BG-01 / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

### L-010 — For isolate or cross-isolate callbacks, assert that garbage or missing payloads leave prior state intact and do not throw
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: edge: TaskHandler isolate unreachable / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

### L-011 — Patrol roda UM teste Dart por processo do app: os completers do PatrolAppService sao final e nunca reciclados, entao o 2o patrolTest de um bundle falha com 'Invalid response 500'. Escreva exatamente um patrolTest por arquivo e agrupe criterios relacionados num teste sequencial com reason em cada expect.
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/integration_test` · harmful: 0
- features: mobile-e2e-tests
- evidence: leancodepl/patrol#2005 (apps/popmundo_app/integration_test)
- last seen: 2026-08-19T01:10:55Z

### L-012 — Rode 'flutter analyze integration_test' antes de pedir qualquer execucao em device: uma rodada foi queimada em dois erros de compilacao Dart (import de flutter_test faltando) que o analisador acha em 2s sem Gradle.
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/integration_test` · harmful: 0
- features: mobile-e2e-tests
- evidence: T2 device run (apps/popmundo_app/integration_test)
- last seen: 2026-08-19T01:10:55Z

### L-013 — Para saber se uma API de terceiro existe, leia a fonte do pacote instalado em ~/AppData/Local/Pub/Cache, nao a documentacao: os docs do Patrol omitem getNotifications(), que existe em patrol-4.9.0 native_automator.dart:205.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `dependencias-terceiros` · harmful: 0
- features: mobile-e2e-tests
- evidence: design.md Risks row 1 (dependencias-terceiros)
- last seen: 2026-08-19T01:10:55Z

### L-014 — Quando o erro vem de dependencia de terceiro, busque issues conhecidas do projeto ANTES de teorizar sobre o proprio codigo: duas hipoteses plausiveis (clearPackageData, FGS impedindo restart) custaram 3 execucoes e o sintoma era o titulo literal de uma issue aberta.
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `debugging` · harmful: 0
- features: mobile-e2e-tests
- evidence: 3 rodadas perdidas em hipoteses (debugging)
- last seen: 2026-08-19T01:10:56Z

### L-015 — When a test injects a short timeout to keep itself bounded, assert the elapsed wall-clock time is within that bound, not just the resulting exception's type and message.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: mobile-e2e-tests
- evidence: apps/popmundo_app/integration_test/userscripts_test.dart:120-130 (US-04) (apps/popmundo_app)
- last seen: 2026-08-19T01:27:26Z

### L-016 — An idempotency criterion (no duplicate action on repeat call) needs an assertion on the action's call count or side effect, not just that the end-state boolean stays true afterward.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: mobile-e2e-tests
- evidence: apps/popmundo_app/integration_test/keepalive_test.dart:79-89 (KA-04) (apps/popmundo_app)
- last seen: 2026-08-19T01:27:32Z

### L-017 — Patrol (leancodepl/patrol) runs exactly one Dart test per app process per install -- design device-test task breakdowns as one patrolTest per file from the start, not one task per acceptance criterion.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `patrol` · harmful: 0
- features: mobile-e2e-tests
- evidence: commits 315c27d, dacb11c, 45771fd (T3/T4/T5, T6/T7/T8, T9/T10 merges) (patrol)
- last seen: 2026-08-19T01:27:39Z

### L-018 — Assert translated copy on the production widget under the non-default locale, not only on a probe Text(key.tr()).
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `app-shell` · harmful: 0
- features: app-i18n
- evidence: app_sidebar.dart:28 mutant 3 (app-shell)
- last seen: 2026-08-19T02:23:59Z

### L-019 — An Independent Test that names a production widget must pump that widget, not a stand-in that calls the same translation key.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `app-shell` · harmful: 0
- features: app-i18n
- evidence: P1 AC1 localization_boot_test.dart:29-32 (app-shell)
- last seen: 2026-08-19T02:23:59Z

### L-020 — When a spec requires fallback-to-English for a missing catalog key, assert the English value and the absence of the raw key at runtime, not only that a library flag appears in source.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `app-shell` · harmful: 0
- features: app-i18n
- evidence: I18N-05 localization_boot_test.dart:48 (app-shell)
- last seen: 2026-08-19T02:23:59Z

### L-021 — When adding a nested i18n namespace, check the prefix is not already a leaf key — the new map shadows the existing string and throws at render time
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/assets/translations` · harmful: 0
- features: auto-login
- evidence: autologin.status leaf shadowed by autologin.status.* (auto-login validation.md) (apps/popmundo_app/assets/translations)
- last seen: 2026-08-19T16:18:38Z

### L-022 — A WebView navigation callback fires before the new document commits — read location.href, readyState and markup in one evaluate and poll until they match the expected page, never parse on the first callback
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: live DOM read returned the previous document (auto-login validation.md) (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T16:50:23Z

### L-023 — Masking structured field logs is not enough — a raw HTML dump carries submitted credentials as plain value attributes, so redact secrets in the dump path too
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: page dump printed the password in clear text (auto-login validation.md) (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T16:50:23Z

### L-024 — An in-page fetch cannot follow a redirect that leaves the document origin — if a flow depends on a cross-host handover, plan for a transport outside the WebView from the start
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: in-page fetch blocked by CORS on the www to N.popmundo.com handover (AD-018) (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T17:12:30Z

### L-025 — Authenticating over a native HTTP client logs in nobody until its cookies are copied into the WebView jar, host-only cookies written without a domain
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: dart:io jar is separate from the WebView jar (AD-018) (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T17:12:30Z

### L-026 — Sequential native calls that share a game throttle must use one cooldown clock, and tests must assert the gap between probe and handshake not only between two probes
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: HB-10 auto_login_controller.dart:228+305 (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T19:09:21Z

### L-027 — A skip-guard copied onto a second trigger path needs its own test on that path; covering the guard on navigation does not discriminate a heartbeat-only deletion
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: HB-05 checkSession credential guard (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T19:09:21Z

### L-028 — Platform-suspend behavior that unit tests cannot exercise must be flagged as a spec-precision gap, not counted as covered
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `autologin-heartbeat` · harmful: 0
- features: auto-login
- evidence: HB-08 iOS suspend (autologin-heartbeat)
- last seen: 2026-08-19T19:09:21Z

### L-029 — A production default interval that tests override still needs one assertion of that default so a shorter cadence cannot survive
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/autologin` · harmful: 0
- features: auto-login
- evidence: HB-01 heartbeatInterval default (packages/popmundo_utils/autologin)
- last seen: 2026-08-19T19:09:21Z

### L-030 — An isolate-boundary must-not-call requirement needs an assertion on that isolate entrypoint, not only a README
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/background` · harmful: 0
- features: auto-login
- evidence: HB-07 FGS isolate (apps/popmundo_app/background)
- last seen: 2026-08-19T19:09:21Z

### L-032 — When a real-plugin implementation wraps its own initialize() in a swallow-all try/catch (matching the FlutterForegroundTaskPlatform zero-unit-test precedent), explicitly note in the Test Coverage Matrix that the catch branch itself has no forced-failure test in either tier, so it isn't silently assumed covered by the device-real test alone.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/lib/notifications` · harmful: 0
- features: local-notifications
- evidence: NOTIF-08 / apps/popmundo_app/lib/notifications/local_notifications_service.dart:27-46 (apps/popmundo_app/lib/notifications)
- last seen: 2026-08-20T00:25:31Z

### L-033 — Before wiring a new Flutter plugin with native Android setup requirements (e.g. flutter_local_notifications), check its pub.dev Gradle setup section (via Context7) for build.gradle.kts prerequisites like core library desugaring - a plugin can compile/analyze cleanly while still failing the first real Gradle build over a missing native setup step.
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `android-gradle` · harmful: 0
- features: local-notifications
- evidence: apps/popmundo_app/android/app/build.gradle.kts checkDebugAarMetadata (android-gradle)
- last seen: 2026-08-20T00:53:47Z

## Quarantined (failed when applied — ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

### L-031 — Agent sandbox sessions on this machine cannot complete patrol test's Gradle build step (java.io.IOException: Unable to establish loopback connection, JDK17+ restriction); device-real Patrol runs must be executed from the user's own terminal, not delegated to an agent.
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `apps/popmundo_app/integration_test` · harmful: 2
- features: local-notifications
- evidence: patrol test --target integration_test/notifications_test.dart (apps/popmundo_app/integration_test)
- last seen: 2026-08-20T01:06:18Z
