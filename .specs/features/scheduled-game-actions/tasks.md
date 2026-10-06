# Scheduled Game Actions — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Use tlc-spec-driven Execute and Critical Rules. Tests derive from spec outcomes; red test before production; gate then one atomic commit per task. Do not weaken/delete tests. Fresh independent verifier after last task. Repo CLAUDE.md requires domain specialists; this overrides inline authoring default. Specialists execute sequentially, no SDK/Gradle overlap. User approved scope/HTTP/character binding; tools already specified (skill, embedded browser, connected Android, repo shell/git). No further permission gate.

Design: design.md. Status: In Progress. Baseline: core277, WebView31, app164 tests passed. Eight cohesive deliverables; no phase-batch offer needed.

## Test Coverage Matrix

Generated from CLAUDE.md Commands/Device-real tests, analysis_options, existing scheduler/auth tests, scheduler editor/client/runner widget tests and integration_test scheduler fixtures. Required coverage: every spec AC and listed edge case; fixture payload expectations independent from implementation.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Action codecs/configuration | unit | Legacy roundtrip, invalid/unknown payload, character persistence, no secrets | packages/popmundo_utils/test/*scheduler* | dart test |
| Native auth/forms/endpoints | unit/integration | Every identity/route/form/price/eligibility/outcome branch, cancellation/late request/serialization | packages/popmundo_utils/test/*game_actions* | dart test |
| Scheduler coordinator/store | unit/integration | Claim/notice/HTTP order, outcomes, no replay, legacy local semantics | packages/popmundo_utils/test/*scheduler* | dart test |
| App RPC/engine/notification | unit/widget | Fresh credentials, sanitized RPC, lifecycle/locale, failure branches | apps/popmundo_app/test/*scheduler* | flutter test |
| Editor/cards | widget | Three services, target/quotes/effects, offline edit, retain inputs, errors EN/PT | apps/popmundo_app/test/*scheduler* | flutter test |
| Android engine boundary | device e2e | Real Keystore/HTTP/notification, background/recents/reboot, persisted char, no game host | apps/popmundo_app/integration_test/* | flutter analyze integration_test; patrol test --target <fixture> -d <observed-device> |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Core task | From packages/popmundo_utils: dart test --reporter expanded; flutter analyze packages/popmundo_utils from root |
| Full | App task | From apps/popmundo_app: flutter test --reporter expanded; flutter analyze apps/popmundo_app from root |
| Build | Final integration | Above + WebView flutter test/analyze + release APK + actual isolated Patrol device run |

Windows commands use cmd.exe /d /c with installed .bat executables, WSL bash workdir and pipefail logs. Device IDs are discovered, never invented. Counts must not fall below baseline without documented legitimate consolidation.

## Execution Plan

Phase1 foundation: T1 -> T2. Phase2 endpoints/coordinator: T3 -> T4 -> T5. Phase3 shell: T6 -> T7. Phase4 proof: T8. Overall strictly T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> T7 -> T8.

## Task Breakdown

### T1 — Action configuration component
What: validated sealed action/DTO codecs, preserving local public constructor; Draft/Rule integration waits for T5 for compilation.
Where: utils scheduler models/actions and co-located tests/docs.
Depends on: None. Owner: popmundo-utils. Reuses: existing scheduler JSON validation.
Requirement: SGA-01, SGA-02, SGA-03 account/character binding.
Done when: roundtrip retains char ID/name/account/item/bonus/cap; malformed/unknown rejects; no secret fields; baseline preserved.
Tests: unit. Gate: Quick. Commit: feat(game-actions): add typed action configuration.
Status: done; commit09b83bc; red then298 core tests passed, analyze clean (evidence/t1-*).

### T2 — Isolated HTTP transaction component
What: GameActionsService auth/discovery/forms/strict outcome/cancellation contracts; endpoint execution hooks remain for T3/4.
Where: utils game_actions slice, minimal AuthSession/IO extensions, tests/docs.
Depends on: T1. Owner: popmundo-utils with domain review. Reuses: AuthSession and html.
Requirement: SGA-02/03/04/09.
Done when: private empty jar, assigned-host routing, char verified, no visible runtime collaborator, fresh-account validation, limits/throttle/abort prevent late request and overlap; discovery exposes non-secret DTOs; forms retain successful repeated controls; neutral preflight/outcome fixtures strict.
Tests: unit/integration. Gate: Quick. Commit: feat(game-actions): isolate native transactions and discovery.
Status: done; commit3a7e0fb;341 core tests passed, analyze clean; opt-in live probe found initial-login routeMismatch; fixF1 committed1e5535d,342 core tests and analyze clean, opt-in read-only live discovery and fresh visible-session isolation passed.

### T3 — Use item endpoint
What: one eligible row/button POST adapter and outcomes.
Where: utils game_actions item endpoint and tests.
Depends on: T2. Owner: popmundo-utils with domain review.
Requirement: SGA-04/05/08/09.
Done when: exact name/first eligible direct row; only Item_Use.png; fresh hid preserved; .x/.y only; unavailable zero POST; uncertain no retry.
Tests: unit/integration. Gate: Quick. Commit: feat(game-actions): execute scheduled item use.
Status: done; commit18e26aa;366 core tests passed, analyze clean, domain host/form gaps reproduced red and corrected (evidence/t3-*).

### T4 — Crew bonus endpoint
What: selected artist/bonus/price guarded single POST adapter.
Where: utils game_actions crew endpoint and tests.
Depends on: T3. Owner: popmundo-utils with domain review.
Requirement: SGA-04/06/08/09.
Done when: positive scoped artist guard, offered explicit14..20, integer-cent cap, fresh complete form, no substitute, missing/changed/weekly form zero POST; strict outcome.
Tests: unit/integration. Gate: Quick. Commit: feat(game-actions): execute guarded crew bonuses.
Status: done; commit25ded07;383 core tests passed, analyze clean, domain review passed (evidence/t4-*).

### T5 — Scheduler game dispatcher component
What: typed Draft/Rule integration and durable game execution routing with start/result ordering.
Where: utils scheduler coordinator/models/store and tests. App specialist owns minimal local-action casts if needed to keep compile.
Depends on: T4. Owner: popmundo-utils; shell bridge by app-shell.
Requirement: SGA-01/07/08/09.
Done when: old catalog roundtrip and cadence unchanged; claim before notice before HTTP; notice failure zero game requests; truthful persisted outcomes; no retry after effect/late notice; game dispose aborts; no5s orphan timeout.
Tests: unit/integration. Gate: Quick + app compilation/tests after owned bridge. Commit: feat(scheduler): dispatch isolated game actions.
Status: done; commit3cb4ecf;405 core and165 app tests passed, analyses clean; shutdown race red/green and typed bridge included (evidence/t5-*).

### T6 — App engine gateway component
What: production service factory, GameActionsApi RPC, fresh secrets/settings/locale, mandatory native notifications/lifecycle wiring.
Where: app scheduler/background/notifications/AppWiring and tests/docs.
Depends on: T5. Owner: popmundo-app-shell.
Requirement: SGA-02/03/07/08/09/10.
Done when: secondary engine reconstructs isolated service; fresh secure reads; DTO-only RPC; start notification includes saved char; EN/PT; close cancels game traffic; local path preserved; AppWiring owns lifecycle.
Tests: unit/widget. Gate: Full. Commit: feat(scheduler): wire native game execution gateway.
Status: done; 172 app tests passed, analyze clean (evidence/t6-green.log).

### T7 — Game action editor component
What: service/character/item/bonus selection, effect summaries, translated statuses and cards.
Where: app scheduler editor/presentation/translations and tests/docs.
Depends on: T6. Owner: popmundo-app-shell.
Requirement: SGA-01/02/06/07/08.
Done when: explicit owned char ID/name persists; valid discovered choices required; no automatic20; quote cap saved; offline existing edit; action-only change retains cadence; cancellation/errors retain input; weekly/item effect stated; cards show char/action/outcome in EN/PT.
Tests: widget. Gate: Full. Commit: feat(scheduler): configure scheduled game actions.
Status: pending.

### T8 — Android proof fixture component and maintenance handoff
What: isolated loopback-backed real secondary engine proof fixture, evidence and final docs/build sync.
Where: app integration_test/support; fixture-owned Android configs temporarily; maintenance docs/evidence.
Depends on: T7. Owner: popmundo-e2e; module fixes routed to owners.
Requirement: SGA-10 plus device boundaries SGA-01/03/07/08/09.
Done when: analyze clean and Patrol run on observed device; real Keystore/HTTP/notification plus background/recents/reboot retaining target ID; default fixture cannot load Popmundo; release install preserves production data; final all tests/analyzers green; official docs consistent. Report physical/overnight limits truthfully.
Tests: device e2e + regression. Gate: Build. Commit: test(game-actions): prove Android engine execution.
Status: pending.

## Task Granularity Check

T1 configuration component; T2 transaction component; T3 one item endpoint; T4 one crew endpoint; T5 dispatcher component; T6 gateway component; T7 editor component; T8 device fixture component. Each includes its own tests/docs; all PASS.

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | None | PASS |
| T2 | T1 | T1->T2 | PASS |
| T3 | T2 | T2->T3 | PASS |
| T4 | T3 | T3->T4 | PASS |
| T5 | T4 | T4->T5 | PASS |
| T6 | T5 | T5->T6 | PASS |
| T7 | T6 | T6->T7 | PASS |
| T8 | T7 | T7->T8 | PASS |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1 | config/codecs | unit | unit | PASS |
| T2 | transaction/discovery | unit/integration | unit/integration | PASS |
| T3 | item endpoint | unit/integration | unit/integration | PASS |
| T4 | crew endpoint | unit/integration | unit/integration | PASS |
| T5 | coordinator/store | unit/integration | unit/integration | PASS |
| T6 | gateway/engine | unit/widget | unit/widget | PASS |
| T7 | editor/cards | widget | widget | PASS |
| T8 | Android fixture | device e2e | device e2e + regression | PASS |

## Evidence protocol

Per task retain red/green gate logs, exact tests/assertions covering ACs, test counts and commit hash. Final validation includes reverse test->AC mapping and a fresh independent scratch discrimination sensor (at least five gameplay behavior faults). Do not store raw account credentials, cookies, query tokens, form values or authenticated HTML. Synthetic fixtures only.

## Fix F1 — Native login route diagnosis

Found after T2 opt-in live probe: routeMismatch before gameplay; no item/payment POST. First gather sanitized method/host/path/status/form-action route shape, then reproduce actual shape in a red unit test. Implement only evidence-backed auth-route correction, preserve strict gameplay routes, full core gate/analyze and atomic fix commit. Re-run opt-in read-only discovery and check visible Troy ID unchanged. No credentials, cookies, body, query tokens or authenticated HTML in evidence. Execute before T3; routine required fix already authorized by user continue/debug request.
