# F1 fresh-session isolation evidence

Date: 2026-10-06. Embedded browser + opt-in native discovery; no gameplay action.

Old cached browser document was expired when reloaded, so it was not accepted as proof. Renewed authorized browser login, chose Troy, then fresh GET /World/Popmundo.aspx/Character on assigned host74:
- title: Popmundo - Troy Drinkwater
- unique .charPresBox .idHolder: 3327035
- login form: absent

Ran test_live/game_actions_discovery_live_test.dart with independent native jars. Trace in f1-live-fresh-sessions.log contains only method/host/path/status/form-action metadata. Result PASS: owned7, selected3155712 (Peter), itemChoices2. The selection/inventory transaction also received assigned host74.

Reloaded browser profile after native test completed:
- title: Popmundo - Troy Drinkwater
- unique .charPresBox .idHolder: 3327035
- selected character label: Troy Drinkwater
- login form: absent

Conclusion: in this observed run a separate native login/jar and selection did not replace or log out the visible session, even on the same assigned host. This verifies the requested isolation boundary for the tested session; it is not an overnight reliability measurement.
