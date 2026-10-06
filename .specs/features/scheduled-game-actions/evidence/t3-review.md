# T3 item endpoint adequacy

Red t3-red.log:19 behavior failures from unavailable hook. Green t3-green.log:361 passed; dart analyze exit0/no issues. No previous tests changed/deleted/skipped. One newly authored exact payload literal had event controls in a mistaken order; orchestrator explicitly authorized correcting only this literal to original DOM order, preserving every key/value/duplicate.

| AC | Exact assertion evidence in test/game_actions_item_test.dart | Spec outcome |
| --- | --- | --- |
| SGA-04.1/2,05.1/4 | 55 expect(transport.gameplay.single.body, exact full fresh payload);54 expect(host,'74.popmundo.com') | full form + preserved repeat/hidden fields + cleared events + only selected x/y=1 |
| SGA-05.2/3 | 79/80 expect(fields['newbtnUse.x/y'],'1');81 fresh hidden;82/83 wrong/tune/later button absent | first eligible matching row, tune excluded |
| SGA-05.1/3/5 |119 expect(status,unavailable);120 code itemUnavailable;121 gameplay isEmpty;122 no notification reads | absent/substring/tune/wear/disabled/hidden missing/nested row zero gameplay |
| SGA-04.4 |130 failed;131 preflightUnavailable;132 gameplay isEmpty;133 reads<=2 | stale/malformed preflight blocks effect |
| SGA-08.1 |52 confirmed;53 no error;155 failed;156 serverRejected | strict fresh success/rejection |
| SGA-08.2 |146 uncertain;147 outcomeUncertain;148 gameplay.length1 | empty/normal/malformed/mixed/unknown signal uncertain, never resent |
| SGA-08.2/09.4 |163 uncertain;164 outcomeUncertain;165 gameplay.length1;166 one baseline | response loss uncertain |
| SGA-09.3/4 |179 uncertain;180 closed true;183 length1;184 baseline only after late response | actual close and no late follow-on |

Reverse mapping: all assertions52..60=>SGA-03/04/05/08;74..83=>SGA-05;119..122=>SGA-05;130..133=>SGA-04;146..166=>SGA-08;179..184=>SGA-09. Every test necessary; payload values tested exactly, no shallow-only assertions. Existing T2 tests provide scoped identity/route/cookie/full-form/cooldown coverage. CLAUDE.md pure-Dart synthetic network boundary preserved. No spec deviation.

Domain review found two grounded gaps, corrected before commit: profile/target/final gameplay response must retain the established session origin, and missing/empty item form is unavailable. New red t3-origin-red.log kills all five variants; final green366 tests, analyze clean. Additional exact assertions test/game_actions_item_test.dart:201..204 failed/routeMismatch/zero gameplay/actual75 target;215..218 unavailable/formUnavailable/zero gameplay/no reads;253..259 failed/routeMismatch/zero target/gameplay;270..273 uncertain/outcomeUncertain/one POST/baseline only. These map to SGA-03.1/2/04.3 and SGA-08.1/2. Final references above match formatted source. Analyzer initially found one style info in test helper; interpolation fixed and analyze rerun clean before finalizing task commit.
