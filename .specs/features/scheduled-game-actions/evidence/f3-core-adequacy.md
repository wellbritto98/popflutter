# F3 item-operation core — 2026-10-07

SGA-11 authorized instrument tuning as a distinct saved operation. Assumption/source: user-authorized live DOM identifies enabled Item_Tune.png controls for Deon's instruments; no endpoint or gameplay signal changes. All executions here use synthetic transports, never the live game.

Owned files: scheduler_actions.dart, game_action_choices.dart, game_forms.dart, game_item_action.dart, game_actions_service.dart; new game_actions_tune_test.dart; existing discovery assertion expanded to include the newly approved tune choice; core/game_actions/scheduler READMEs synchronized. Existing default-use exclusions, origin/auth/form/notification/cancellation tests remain intact.

Steps: introduce failing behavioral tests → minimal operation codec/candidate/execution changes → full core gate → atomic commit. No new WebView JS or adapter needed.

## Evidence

- f3-core-red.log: 19 tests, 12 failed / 7 passed before implementation. It detects lost operation, invalid operation acceptance, missing discovery, wrong use/tune execution and ambiguous candidate admission.
- f3-core-normalized-red.log: 1 failed / 18 passed before lowercasing the discovery deduplication key. Display name is retained from the first eligible row.
- f3-core-tests.log: full core suite 438 passed, baseline419 +19 new tests.
- f3-core-analyze.log: No issues found.

## Coverage / necessary-test reverse mapping

All new citations are packages/popmundo_utils/test/game_actions_tune_test.dart.

| Requirement | Evidence and asserted outcome | Keep |
| --- | --- | --- |
| SGA-11.2 action operation + bound target roundtrip | 27–30: toJson equals exact tune payload; character ID/name and boundUsername equal saved values | Yes |
| SGA-11.2 legacy and explicit use compatibility | 34–44: absent/explicit use action and DTO preserve exact legacy JSON | Yes |
| SGA-11.2 discovery DTO wire roundtrip | 49–51: decoded DTO equals name Violino and operation tune | Yes |
| SGA-11.2 invalid/null/unknown operation rejected | 63–69: action and DTO each reject invalidAction for null, wear, Tune, empty, integer and bool | Yes |
| SGA-11.1 normalized-name/operation pair discovery | 84–88: exactly Cubo/use, Violino/tune, Violino/use; mixed-case/whitespace duplicate tune collapsed | Yes |
| SGA-11.3 first exact matching-operation row with fresh full form | 111–117: confirmed, no error; entire POST equals fresh hidden/repeated controls plus only row2.x/y=1; first-use homonym skipped, later tune skipped | Yes |
| SGA-11.3 no use↔tune fallback; SGA-04 guards | 163–166: unavailable/itemUnavailable, zero gameplay/preflight for default-use-only-tune, tune-only-use, ambiguous row, disabled button, wear, discard, wrong basename and missing hidden state | Yes |
| Existing SGA-02 discovery gains instrument, retains identity proof | game_actions_transport_test.dart:139–141 retains Cubo/use and adds Violino/tune; all existing account/character/session assertions retained | Yes |

Adequacy A–D: every changed contract maps to a spec-defined value/state assertion; tests detect behavioral regressions and add no speculative requirements. No test deleted, skipped or weakened. Canonical use serialization intentionally omits operation for compatibility; explicit null is rejected instead of defaulted. Enum defaults are use; tune must be explicitly saved. Authentication/origin, successful-control ownership, throttle, durable claim, outcome verification and no-replay behavior remain unchanged and pass the full suite. Independent amendment verification belongs to the orchestrator after shell/device work.
