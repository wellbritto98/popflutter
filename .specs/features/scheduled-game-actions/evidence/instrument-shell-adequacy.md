# F3 shell adequacy

Scope: SGA-11.1/2/4 and affected SGA-01.1/2/3, SGA-02.3/7/8, SGA-07.1/3. Core owns icon mapping, same-operation execution and legacy codec validation. No game requests, Patrol or APK commands were run by the shell worker.

## Gates

- RED: focused widget/RPC/notices 2 passed, 9 failed before production edits. Missing tuning labels/effects and duplicate same-name keys caused the expected failures. RPC generic transport already retained the new core field.
- GREEN focused: 11 passed (7 new widget cases, 1 new RPC case, 2 new native-notice cases and existing use-notice case).
- Full app: 196 passed, no skipped/deleted tests; previous baseline 186. Existing use/local/crew tests unchanged.
- Static analysis: full flutter analyze passed with No issues found (exit0); instrument-shell-analyze.log records the final result.

## Coverage mapping — evidence or zero

| Criterion | Assertion evidence | Spec-defined outcome | Covered |
| --- | --- | --- | --- |
| SGA-11.1 distinguish same-name operations | scheduler_instrument_editor_test.dart:55, :56, :64, :65, :67, :68 — expect(use/tune, findsOneWidget); selected true/false after each tap | Both choices visible; only the chosen operation selected | Yes |
| SGA-11.1 tune choice label EN/PT | scheduler_instrument_editor_test.dart:57 — expect(find.text(Afinar instrumento: Violino / Tune instrument: Violino), findsOneWidget) | Tuning is identified explicitly in either locale | Yes |
| SGA-11.2 create retains operation/character/account | scheduler_instrument_editor_test.dart:84, :85, :86, :90, :91 — expect(action.operation, GameItemOperation.tune); itemName Violino; character id42/name; boundUsername bound; JSON operation tune | Non-secret bound target plus authorized tune survives persisted snapshot decode | Yes |
| SGA-11.2 offline update | scheduler_instrument_editor_test.dart:128, :129, :130, :131, :132, :133, :134 — expect(updated.action.toJson(), instrumentAction().toJson()); IDs/recurrence/nextDue unchanged; discovery.charactersCalls0 | Offline rename keeps effect and cadence | Yes |
| SGA-11.2 RPC discovery/create/update | scheduler_instrument_rpc_test.dart:54, :58, :66, :70, :81, :85, :89 — names [Violino,Violino], operations [use,tune], returned action tune, emitted action exact JSON and persisted snapshot exact action | Operation crosses both discovery DTO and writer payload boundaries | Yes |
| SGA-11.2 invalid explicit operation | scheduler_instrument_rpc_test.dart:108, :109 — for null/wear, expect(replies.last.error, invalidAction); expect(store.raw, raw) | Writer rejects malformed operation without overwriting existing rule | Yes |
| SGA-02.8 operation-only edit | scheduler_instrument_editor_test.dart:197, :201, :202, :203, :204, :205 — operation tune; itemName Violino; ID/notificationId/recurrence/nextDue unchanged | Changing operation keeps rule identity and cadence | Yes |
| SGA-11.4 effect EN/PT without consumption | scheduler_instrument_editor_test.dart:69, :77, :117 — exact tunes/afina text; uses one/usa um absent | Effect describes tuning in create and offline edit | Yes |
| SGA-11.4 summary EN/PT | scheduler_instrument_editor_test.dart:149, :157 — exact Tune instrument/Afinar instrumento summary; use summary absent | Card identifies tuning | Yes |
| SGA-11.4 and SGA-07.1/3 native start/result EN/PT | game_notification_messages_test.dart:44, :45, :57 — ids [-42,-42], exact operation-specific start/result title and saved-character bodies | Native notice replacement retains operation and bound character in either locale | Yes |

Paths above are relative to apps/popmundo_app/test. Each cited number locates an assertion; each named field is asserted by value, not merely by invocation count.

## Reverse mapping and quality

| New test | Requirement | Keep |
| --- | --- | --- |
| EN/PT create and same-name selection (2) | SGA-11.1/2/4; SGA-02.3/7 | Yes |
| EN/PT offline rename (2) | SGA-11.2/4; SGA-02.8 | Yes |
| EN/PT summary cards (2) | SGA-11.4; SGA-02.8 | Yes |
| Operation-only update (1) | SGA-11.2; SGA-02.8 | Yes |
| Discovery/create/update/invalid writer RPC (1) | SGA-11.2; SGA-01.2/3 | Yes |
| EN/PT native notices (2) | SGA-11.4; SGA-07.1/3 | Yes |

Adequacy: all shell criteria have value/state assertions derived from SGA-11; none assert only a call count. Tests use existing localized widget, scheduler coordinator/store, runner/client and native-notice seams. Existing assertions remain unchanged. No speculative cases or platform/lifecycle scope added. Independent feature verifier is owned by the root orchestrator.
