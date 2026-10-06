# T4 guarded crew bonus adequacy

Red t4-red.log:17 behavior failures from missing crew adapter. Target green17; full t4-green.log383 passed (366+17), dart analyze exit0/no issues. Domain specialist read-only final review found no further concrete gaps. Existing tests unchanged/deleted/skipped: none. No spec deviation or real gameplay POST.

| AC | Exact assertion evidence test/game_actions_crew_test.dart | Spec outcome |
| --- | --- | --- |
| SGA-04.1/2,06.2/3 |52 expect(gameplay.single.body, exact entire fresh payload);49 confirmed;50 no error;51 assignedhost;56 two reads | explicit14 + actual button value, fresh viewstate/repeated controls, events cleared, unrelated submit omitted |
| SGA-06.2/3 |63 confirmed with explicit20/cap12300000;70 expect(field ddlCashBonus,'20');71 expect(btnCashBonus,'Entregar bônus') | level20 requires explicit configuration and cap |
| SGA-06.1/2/4 |131 expect(status,unavailable);132 bounded errorCode;141 gameplay isEmpty;142 notificationReads0 | artist changed/missing, select/level/button missing/disabled, empty button, invalid/ambiguous/overbudget price, missing form all zero payment; no substitute |
| SGA-08.1/2 |151 exact failed/uncertain by server fixture;157 serverRejected/outcomeUncertain;161 gameplay.length1 | strict outcome, no resend |

Reverse mapping: assertions49..56=>SGA-04/06/08;63..74=>SGA-06;131..142 each listed variant=>SGA-06;151..161=>SGA-08. All17 tests necessary, payload values explicitly asserted. Shared T2/T3 unit assertions cover baseline failure, malformed/mixed signals, actual IO cancellation, lost POST responses and origin guards across the common transaction path. Default gates never contact real game. Opt-in live diagnostics remain test-only and read-only; no auth HTML or secrets retained. CLAUDE.md ownership and pure-Dart boundaries preserved.
