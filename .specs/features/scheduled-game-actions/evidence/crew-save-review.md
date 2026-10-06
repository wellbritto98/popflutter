# Crew editor correction — 2026-10-06

User amendment (spec commit 24f1db3) replaces the former mandatory live quote/no-default20 rule: schedule maximum20 even when the game currently offers no bonus. A currently available quote remains a cap; without a quote, persist null cap and explain execution-time pricing. Preserve account, owned character and artist.

Root cause: crew discovery intentionally returns artist plus bonuses=[] when the select is absent. The editor required a selected current bonus and therefore could not construct an action from this valid unavailable-now response. Loading also disabled Save without visible activity feedback, and validation errors above the scrolled service controls were invisible. Device-specific disabled-button reproduction remains separate; this correction has synthetic widget/RPC evidence and sends no real gameplay.

Red: crew-save-updated-red.log, exit1, four failures before shell production changes: EN/PT unavailable view absent, discovery progress absent, invalid name error outside visible area. Initial crew-save-red.log captured the original requirements before the user amendment; no implementation based on those superseded assumptions was shipped. Existing seven editor tests passed in crew-save-existing.log.

Green: crew-save-green-focused.log, 13 tests; crew-save-green-full.log, 186 app tests, exit0. Initial full analyzer failed only on the in-flight device fixture raw strings (crew-save-analyze.log); device owner repaired those raw strings; final full analyzer t8-app-analysis.log passed with no issues in 6.3s before the shell commit. Existing lower-level bonus test updated explicitly because the user changed the default to20; its level14 choice, artist/character and quote-cap assertions remain. No tests skipped or deleted.

## Coverage and reverse mapping

Paths below are relative to apps/popmundo_app/test. Every row is necessary for the amended SGA-02 criteria or backward compatibility; no framework-only test.

| AC / behavior | Assertion evidence | Expected outcome / reverse mapping |
| --- | --- | --- |
| SGA-02.4 unavailable-now future rule EN/PT | scheduler_crew_save_regression_test.dart:148 expect(find.text(message).hitTestable(), findsOneWidget); :150 onPressed isNotNull; :159..166 individual persisted name/account/character/artist/bonus/cap assertions | Label explains future maximum20 and execution-time cost; saved ID/name target and null cap |
| SGA-02.4 current maximum quote | scheduler_crew_save_regression_test.dart:102 selected true; :112..118 individual persisted target, bonus20 and maxCostMinor900000 assertions | Default20; current synthetic quote retained as cap |
| SGA-02.6 visible discovery activity | scheduler_crew_save_regression_test.dart:189 loader findsOneWidget; :190 translated progress findsNWidgets(2); :191 disabled Save; :210 loader; :225 loader findsNothing; :226 enabled Save; :236..239 saved target/20/null | Both character and crew discovery communicate pending state, then unlock Save and permit future rule |
| SGA-02.5 visible invalid input | scheduler_crew_save_regression_test.dart:258 name offscreen; :260 error.hitTestable findsOneWidget; :264 api.creates0; :265 raw isNull | Reveal failed field, retain input and do not save until corrected |
| SGA-02.5 offline editing | scheduler_crew_save_regression_test.dart:79..85 same id/notificationId/nextDue/action, null cap, no discovery | Existing future crew rule edits without live requests or cap changes |
| SGA-01.3/SGA-02.4 engine RPC | scheduler_crew_rpc_test.dart:55 exact action map incl account, char id/name, artist id/name,20/null; :65 list exactmap; :66 persisted exactmap | Create, reply, list and stored snapshot preserve only non-secret action configuration |
| SGA-02.4 explicit lower choice | scheduler_game_editor_test.dart:178 expect(action.bonusLevel,14); :179 expect(action.maxCostMinor,225000) | Choosing14 still uses its exact quote and owned target |

Adequacy: all amended shell behaviors covered with state/value assertions. New tests cover six widget scenarios plus one RPC scenario; previous179 app tests remain, totaling186. Default tests use only synthetic data and never contact Popmundo. Independent feature verifier and Android proof remain root-owned final gates.
