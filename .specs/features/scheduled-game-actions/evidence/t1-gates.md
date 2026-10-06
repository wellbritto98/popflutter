# T1 — Typed action configuration

Assumptions: approved IDs authoritative and positive, names labels; item whitespace normalized, UTF16 limit120; account bound per action; cap in cents of M$. No game HTTP/visible dependencies. Draft/Rule retain local-only type until T5.

Files: scheduler_models.dart plus scheduler_actions.dart/game_action_choices.dart parts, scheduler_game_actions_models_test.dart, scheduler README and this evidence. No tests deleted/skipped; format-only interpolation correction preserves original Unicode overflow assertion.

Red: t1-red.log — missing public action/DTO symbols, loading failure before implementation.
Green: t1-green.log — 298 tests passed (277 baseline +21), zero skips/failures.
Analysis: t1-analyze.log — no issues. Commands from utils: dart test --reporter expanded; dart analyze.

| Spec/criterion | Assertion in test/scheduler_game_actions_models_test.dart | Expected / covered |
| --- | --- | --- |
| SGA-01.1 existing local constructor/JSON | :30 expect(ScheduledAction.fromJson(action.toJson()).toJson(), exact local map); :35/:36 title/body | Reminder / Body preserved; yes |
| SGA-01.2/3 item and char/account codec | :43 expect(action.toJson(), item); :44/:45/:46/:47 boundUsername, id, name, itemName | account/3327035/Troy Drinkwater/Cubo mágico; yes |
| SGA-01.2/SGA-06 explicit bonus/cap | :59 expect(action.toJson(), crew); :60..63 fields | 2774797/black panties/14/225000; yes |
| SGA-02.3 normalized item+UTF16 | :73 exact normalized map; :80 accepted length120; :88 invalidAction beyond120 | normalized, no truncation; yes |
| SGA-01.2 malformed/unknown actions | :130..137 throws invalidAction across14 cases | zero silent fallback; yes |
| SGA-01.3 no secret output | :151 exact whitelisted crew; :152 isNot(contains('synthetic')) | extras not emitted; yes |
| SGA-02 discovery DTOs | :160/165/173 exact catalog/item/crew maps; :180/184 immutable collections | owned public choices only; yes |
| SGA-01.2/SGA-02 malformed DTO types | :220..228 each decoder throws invalidAction | invalid account/char/item/artist/bonus/cost rejected; yes |

Reverse map: local test→SGA-01.1; item→SGA-01.2/3,SGA-03 binding; crew→SGA-01.2/SGA-06; normalized/UTF16→SGA-02.3; all14 malformed cases→SGA-01.2/SGA-06.2; whitelist→SGA-01.3; DTO roundtrip/malformed→SGA-02/SGA-01.2. Each assertion above retains its mapped requirement. No unrelated tests.

Adequacy: all task configuration criteria covered by exact public/persistable values and typed rejection. Existing scheduler snapshot/execution assertions remain unchanged; game-rule migration belongs T5. Guidelines: CLAUDE.md, popmundo-utils.md and TLC matrix. No SPEC_DEVIATION.
