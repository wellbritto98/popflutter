# T2 — Independent native transaction foundation

Assumptions: numeric owned IDs authoritative; public labels only. Current mapped login /Default.aspx uses POST ./Default.aspx; gameplay form routes stay exact. Artist label uses title after scoped artist-ID verification, not the general-information sidebar. Endpoint reads do not imply notification draining.

Files: utils game_actions slice/barrel, minimal AuthSession.postJson/IO body limit, opt-in strict successful-controls/login builder, synthetic transport and loopback tests, local READMEs, opt-in read-only live test and these logs. Visible AutoLoginController unchanged.

Red: t2-red.log — new missing gateway/transport/DTO symbols before production implementation, test load fails.
Green: t2-green.log —341 tests passed (298 previous +43), zero failures/skips. t2-focused.log retains earlier40-test bounded subset before three extra failure assertions.
Analysis: t2-analyze.log — no issues. Default commands: dart test --reporter expanded; dart analyze, in packages/popmundo_utils. No game host contacted by these gates. Two IO tests use127.0.0.1 only. No prior test removed or weakened.

| Criterion / spec | Exact test assertion (game_actions_transport_test.dart unless named) | Spec outcome / covered |
| --- | --- | --- |
| SGA-02/03 fresh auth/owned catalog | :110 expect(result.toJson(), exact account/characters map) | account,3327035/Troy,2/Other; yes |
| SGA-03 empty jar/host-only redirect | :117/:118 headers.containsKey Cookie false; :147 selected.headers Cookie synthetic-private; :127 last.host74 | first and cross-host requests unseeded; private host-only jar; yes |
| SGA-04 whole login/current state | :119 body contains __VIEWSTATE=fresh-login&language=pt; :123 password override; :143 full exact choose body | current full form and intended submitter; yes |
| SGA-03 numeric identity, label rename allowed | :137 item choices exact Cubo mágico; :143 chooseTroy payload despite saved old name | authoritativeID, fresh profile; yes |
| SGA-03 wrong/duplicate/missing profile | :177 code characterMismatch; :182 target requests empty across3cases | no gameplay target; yes |
| SGA-03 duplicate owned ID | :191 code characterAmbiguous; :196 choose POSTs empty | no guessing; yes |
| SGA-03 absent owned target | :652 code characterUnavailable; :659 choose POSTs empty | zero choice/gameplay; yes |
| SGA-03 fresh credential/account errors | :222 code(kind); :229 requests empty; :230 closed true | accountChanged/missing/unavailable before HTTP; yes |
| SGA-03 fresh read per transaction | :489 username account; :490 accountChanged; :494 second requests empty | settings not cached across transactions; yes |
| SGA-03 every-hop strict host policy | :246 unsafeTarget; :250 URLs exact initialwww only | reject HTTP/external/lookalike/userinfo/port before transmit; yes |
| SGA-09 whole-transaction serialization | :395 second.requests empty; :399 results IDs[3327035,3327035]; :403/404 bothclosed; :405 second first Cookie false | full private transactions serial; yes |
| SGA-09 total cancellation and late replies | :270 transactionTimeout; :274 closed; :283 requests.length1 after late redirect | late task cannot send; yes |
| SGA-09 disposal active+queued | :293/:294 serviceUnavailable; :297 closed true; :298 requests.length1 | closed before queue ownership returns; yes |
| SGA-09 request deadline | :303 requestTimeout; :313 closed true | real context abort, no orphan continuation; yes |
| SGA-09 cooldown includes failure and next transaction | :436 first-next start gap750ms; :440 every delay750ms; :441 final gap750ms | minimum750 after previous finish; yes |
| SGA-09 body ceiling / sanitized network | :321 responseTooLarge; :334 networkError from raw token-like synthetic exception | no raw exception published; yes |
| SGA-09 actual IO decoded limit and preserved defaults | game_actions_io_limits_test.dart:18 exact bounded AuthHttpException; :53/:54 exact emoji body, :55 default ceilingnull, :56 old20s; :58..61 defaults120/20/2097152/750 | UTF8 bytes ceiling, old callers intact; yes |
| SGA-04 safe methods/routes | :455 routeMismatch; :460 gameplay POSTs empty, three wrong/missing method/action cases | fresh form cannot target another action; yes |
| SGA-04 successful controls and ownership | :499 exact ordered pairs incl repeats and firstLegend, excluding unchecked/disabled/foreign/submit/image; :508 old default retains disabledFieldset | strict game mode only; yes |
| SGA-04 outside serialized form | :618 empty items; :625 crew.bonuses empty | foreign controls cannot become action choices; yes |
| SGA-02 crew ID/name/quotes | :159 exact artist2774797/black panties +14cost225000/20cost12300000 | actual scoped ID/title/current quote; yes |
| SGA-06 price parsing fails closed | :646 offered levels[20] after invalid14cost across4cases | unsupported/ambiguous/overflow quote omitted; yes |
| SGA-04 strict current signal | :343 neutral empty; :344 normal neutral; :349 confirmed1; :355 failed2; :368 uncertain empty/mixed/unknown/missingText/invalid | no HTTP200-only confirmation; yes |
| SGA-04 malformed status types | :520 isNeutral false; :521 uncertain for null/bool/stringStatus | bounded conservative result; yes |
| SGA-04 preflight max2/JSON protocol | :569 exact bounded count; :570 ts1767225600000; :571 JSON contenttype; :575 only ASMXpath | 1neutral or2stale→normal reads; yes |
| SGA-04 preflight cannot establish neutrality | :599 preflightUnavailable; :605 counts1malformed/2stale; :606 gameplaySentfalse | zero gameplay authorization; yes |
| SGA-03/04 login missing/invalid errors | :687 exact formUnavailable/invalidCredentials; :691 allrequests Default; :695 closed | no target traffic, sanitized; yes |
| SGA-04 failed outcome HTTP | :716 exact uncertain/outcomeUncertain DTO after500 syntheticsecretbody | raw body not emitted; yes |

Reverse mapping: owned/auth/host/credentials tests→SGA-02/03; form and ownership tests→SGA-04; quote and parser tests→SGA-02.4/SGA-06.2; signal/preflight/outcome tests→SGA-04.4/SGA-08; total/per-request/IO limits, serialization/cooldown/disposal tests→SGA-09. Every assertion row above maps back to its named requirement; none beyond feature scope. No gameplay endpoint executes yet; T3/T4 implement those adapters, T5 claims/notices.

Adequacy: concrete returned payloads, identities, forbidden request sets, ordered form values, elapsed cooldown and closed-state assertions discriminate unsafe alternatives. CLAUDE.md specialist/TLC matrix followed. No SPEC_DEVIATION. Live test is opt-in, separate and not run by this gate; only numeric IDs/counts/safe codes, no captures or gameplay execute.
