# Future crew bonus core correction — 2026-10-06

Authorized by the user's weekly-bonus/default-maximum clarification and amended SGA-02.4 / SGA-06. No live gameplay POST. Assumption: an absent quote cap authorizes only the saved level at a freshly parsed valid positive price; it does not invent a quote or permit a replacement level.

Owned implementation: scheduler_actions.dart, game_crew_action.dart. Tests: crew_future_bonus_test.dart. Documentation: utils/package, scheduler and game_actions READMEs.

RED: initial 12 cases produced 6 failures (all absent/null cap flows rejected invalidAction), 6 passes. Two additional uncapped invalid/zero-price cases were then added before production edits. GREEN: full pure-Dart suite 419 passes (baseline 405 plus 14), dart analyze reports No issues found. Evidence: crew-future-core-red.log, crew-future-core-tests.log, crew-future-core-analyze.log.

## Coverage and reverse mapping

All citations below are packages/popmundo_utils/test/crew_future_bonus_test.dart.

| Acceptance criterion | Evidence / assertion | Exact expected outcome | Keep |
| --- | --- | --- | --- |
| SGA-02.4 / SGA-01: null or omitted quote cap roundtrips, retaining target | 32–39: expect(action.maxCostMinor, isNull); expect(decoded.toJson(), {...futureBonusJson(), 'maxCostMinor': null}); account, character ID/name, artist ID/name and level assertions | Null cap, account, Troy3327035, artist2774797, level20 | Yes |
| SGA-01 malformed non-null caps still reject | 44–57: expect(decode, throwsA(SchedulerException having code invalidAction)) | Zero, negative, string, decimal and bool reject invalidAction | Yes |
| SGA-06 fresh price allowed without cap, exact saved maximum | 68–77: expect(outcome.status, confirmed); fields[ddlCashBonus] ==20; fields[btnCashBonus] ==Entregar bônus; ViewState fresh-crew | Fresh124000 quote, one exact20 POST, current button/form, fresh success | Yes |
| SGA-06 legacy cap preserved and enforced | 88–93: cap12300000; unavailable/bonusUnavailable; gameplay empty; notificationReads0 | Higher12300001 quote performs no gameplay | Yes |
| SGA-06 no form/op20, invalid/zero quote or changed artist still safe | 121–127: unavailable; artistMismatch or bonusUnavailable; gameplay empty; notificationReads0 | No payment, no replacement or preflight | Yes |

Checks A–D: each change has a spec outcome and located value/state assertions; no assertions weakened/deleted/skipped, no unrelated tests. Existing capped bonus, artist/form/option/price guards remain in game_actions_crew_test.dart and pass. Endpoint/form parsing, origin isolation, throttle, admission, deadlines and notification handling are unchanged. No adapter WebView JS needed. Final independent feature Verifier remains orchestrator responsibility after T8.
