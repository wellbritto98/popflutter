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

Additional read-only probe: t4-live-discovery-signals.log PASS29s. Private notification endpoint returned HTTP200, valid=true, statuses=[], neutral=true on both reads. Fresh private crew discovery for Troy3327035 returned artist2774797 and explicit levels14..20 with quoted integer cents matching the browser mapping. After probe, fresh browser reload again retained unique profile ID3327035 and no login form. Neither probe submitted item use or payment.
