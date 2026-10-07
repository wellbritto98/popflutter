# F3 — Instrument tuning: independent validation

Date: 2026-10-07 (America/Sao_Paulo). Verifier: independent sub-agent instrument_verifier; author ≠ verifier.

Spec: .specs/features/scheduled-game-actions/spec.md, SGA-11 and affected SGA-01/02/05/07. Diff: a330677..78e2b61. Core production: 0d24224; shell production: fdea551. Final inspected HEAD: 78e2b61daa6ba1e0524bb5b613a54bead6b77c7e.

**Verdict: PASS.** All four amendment ACs, affected regressions, current package gates, six behavioral discrimination mutations and the orchestrator release build/install gate passed.

## Scope and independence

This report covers the F3 amendment. The prior T1–T8 report validation.md remains historical and was not rewritten. Its 45-AC claim is not the basis for this verdict. Coverage below was re-derived from the current spec, source diff and assertion bodies; author adequacy narratives and red/green logs were inspected as history, not accepted as proof.

Reviewed changed production surfaces: scheduler_actions.dart and game_action_choices.dart codecs; game_forms.dart icon/candidate parsing; game_item_action.dart operation guard; game_actions_service.dart pair deduplication; shell scheduler_editor.dart, scheduler_game_fields.dart, scheduler_labels.dart and game_notification_messages.dart; both translation catalogs. Reviewed all five changed/new test files plus affected existing model, dispatch, editor and item tests. Reviewed changed official docs, module READMEs, spec/design/context/research/tasks and STATE. Author-generated evidence changes are historical artifacts. No lifecycle, transport ownership, platform configuration or WebView implementation changed.

F3-core and F3-shell deliverables are implemented and verified below. Root owns the final task/traceability/handoff status update and release gate. No production code or tests were edited by this verifier. Only this report and fresh sanitized evidence logs/patches were written in the main tree.

## Spec-anchored acceptance criteria

Test path prefixes: core = packages/popmundo_utils/test/; app = apps/popmundo_app/test/. Each citation identifies an actual assertion; expected outcomes come from the spec, not the implementation.

| AC | Required outcome | Located assertion and value | Result |
| --- | --- | --- | --- |
| SGA-11.1: inventory distinguishes normalized name plus use/tune; editor names tuning | Exactly Cubo mágico/use, Violino/tune and Violino/use; mixed case/whitespace duplicate tune collapsed; same-name operations selectable separately; EN/PT tuning label | core/game_actions_tune_test.dart:84 — choices JSON equals [{'name':'Cubo mágico'}, {'name':'Violino','operation':'tune'}, {'name':'Violino'}]. app/scheduler_instrument_editor_test.dart:55/56 finds both choices; :57 finds exact Afinar instrumento: Violino / Tune instrument: Violino; :64–68 asserts selected true/false before and after switching. | PASS |
| SGA-11.2: save/offline/RPC retain operation and character; legacy absent means use; invalid explicit rejects without catalog overwrite | Saved tune payload and target unchanged across JSON, storage, editor and RPC; absent/explicit use canonical legacy payload; explicit null/unknown/malformed rejected with invalidAction | core/game_actions_tune_test.dart:27–30 exact tune JSON, character ID/name and account; :34–44 absent/explicit use action and DTO equal legacy JSON; :49 exact tune DTO JSON; :63/67 throws SchedulerException(code=invalidAction) for null, wear, Tune, empty, integer and bool. app/scheduler_instrument_editor_test.dart:84–91 operation=tune, name=Violino, character={id:42,name:Saved Character}, account=bound, JSON operation=tune; :128 exact offline action, :134 discovery calls=0. app/scheduler_instrument_rpc_test.dart:58 operations=[use,tune], :66/:81 created/updated operation=tune, :70/:85 sent action equals exact configured JSON, :89 stored action same JSON; :108 error=invalidAction and :109 store.raw unchanged for null/wear. | PASS |
| SGA-11.3: first exact-name same-operation row only; no fallback; missing operation unavailable/zero POST | Tune skips homonymous use and later tune; entire fresh form posts once with only first tune button coordinates; default use never tunes and tune never uses | core/game_actions_tune_test.dart:111 status=confirmed, :112 error=null, :113 entire body equals fresh viewstate/repeated controls/all current hidden fields plus row2btnUse.x=1/row2btnUse.y=1; gameplay.single enforces one POST; :117 reads=2. :163–166 status=unavailable, error=itemUnavailable, gameplay empty, notification reads=0 for both fallback directions, ambiguous row, disabled button, wear, discard, wrong basename and missing hidden state. | PASS |
| SGA-11.4: effect, summary and start/result EN/PT identify tuning without consumption; legacy behaviors preserved | Exact tuning effect/card/native messages, no use/consumption label, same stable negative notification ID and saved character | app/scheduler_instrument_editor_test.dart:69 exact Each eligible occurrence tunes the instrument Violino for Saved Character. / Cada ocorrência elegível afina o instrumento Violino para Saved Character.; :77 consumption text absent; :117 same effect offline; :149 exact Tune instrument/Afinar instrumento card; :157 use card absent. app/game_notification_messages_test.dart:44 ids=[-42,-42]; :45 exact tuning start and confirmed-result titles in EN/PT; :57 exact saved-character bodies twice. Existing use notice assertions :79/:88/:92/:100/:125 retain Usar item/Use item semantics. Full suites retain local/crew behavior. | PASS |

Amendment: 4/4 ACs have concrete value/state evidence; no spec-precision gap found. Icon mapping is checked behaviorally by the discovery/body/no-fallback assertions and mutant M3, rather than only by checking a parser call.

## Affected existing criteria: current regression evidence

This matrix covers the existing behavior touched by the F3 contracts/UI. It does not re-certify unrelated old ACs or device lifecycle claims.

| Existing criterion | Current assertion evidence and expected outcome | Result |
| --- | --- | --- |
| SGA-01.1 compatibility | core/scheduler_models_test.dart:165 exact schemaVersion=1 snapshot includes nextSequence=2, ID schedule-1, notificationId=-1, recurrence and title/body; core/scheduler_coordinator_test.dart:355 exact local submitted ID/title/body payloads; app/scheduler_game_editor_test.dart:234 offline discovery=0 and :245–252 preserves rule cadence/target semantics. | PASS |
| SGA-01.2 invalid action cannot overwrite | core/game_actions_tune_test.dart:63/67 rejects explicit invalid operation; app/scheduler_instrument_rpc_test.dart:108 error=invalidAction and :109 raw catalog unchanged. Existing core/scheduler_game_actions_models_test.dart:130 rejects malformed unknown types. | PASS |
| SGA-01.3 non-secret target payload | core/game_actions_tune_test.dart:27 exact whitelisted tune payload; app/scheduler_instrument_rpc_test.dart:70/:85/:89 exact sent/stored payload contains account, character, item and operation only. Existing core/scheduler_game_actions_models_test.dart:151 exact crew whitelist and :152 no synthetic secret extras. | PASS |
| SGA-02.3 eligible item and operation retained | core/scheduler_game_actions_models_test.dart:73 normalized Cubo mágico; :80 length=120 and :88 rejects 122 UTF-16 units; core/game_actions_tune_test.dart:84 exact eligible choices; app/scheduler_instrument_editor_test.dart:84 operation=tune with persisted character. | PASS |
| SGA-02.5 offline readability; changing target uses fresh choices | app/scheduler_instrument_editor_test.dart:128 exact saved tune payload and :134 no automatic discovery. Existing app/scheduler_game_editor_test.dart:251/:252 retains saved target offline, :257 fresh discovery after change target, :260/:265 unchanged after invalid target, :270/:271 persists fresh valid target. | PASS |
| SGA-02.7 effect authorization summary | app/scheduler_instrument_editor_test.dart:69 exact tuning effect; :77 no consumption claim; :84 save persists the selected tune operation. Existing app/scheduler_game_editor_test.dart:103 use effect, :168 crew effect. | PASS |
| SGA-02.8 cards and action-only cadence | app/scheduler_instrument_editor_test.dart:149 tuning card; :197 operation=tune and :202–205 unchanged rule ID, native ID, recurrence and next due after operation-only edit. Existing app/scheduler_game_editor_test.dart:324/:328/:329 card has configured effect, confirmed result and next due. | PASS |
| SGA-05.1 exact scoped name | core/game_actions_tune_test.dart:109 executes whitespace/case-normalized VIOLINO and :113 selects the tune row; existing core/game_actions_item_test.dart:101–128 rejects absent/substring/nested rows with unavailable/itemUnavailable and zero gameplay. | PASS |
| SGA-05.2 first eligible matching operation | core/game_actions_tune_test.dart:113 full POST has row2 coordinates, not homonymous row1 use or later row3 tune; existing core/game_actions_item_test.dart:85–89 uses first eligible use row and excludes tune/later use. | PASS |
| SGA-05.3 observed image mapping; no implicit operation change | core/game_actions_tune_test.dart:84 includes only use/tune choices; :163–166 unavailable and zero gameplay for changed operation, unsupported/wrong icon, disabled/ambiguous rows. M1/M3 empirically detect wrong operation dispatch. | PASS |
| SGA-05.4 fresh complete form and one image submit | core/game_actions_tune_test.dart:113 exact full form with repeated names, all fresh hidden fields, cleared event fields and only .x/.y=1; gameplay.single enforces one POST. Existing core/game_actions_item_test.dart:61 confirms equivalent unchanged use full form. | PASS |
| SGA-05.5 unavailable outcome; next future slot | core/game_actions_tune_test.dart:163–166 unavailable/itemUnavailable with zero gameplay. Unchanged generic scheduler dispatch: core/scheduler_game_dispatch_test.dart:286 persists unavailable in the status loop; :294 nextDue=anchor+20seconds; :306 only one effect for claimed occurrence. F3 does not alter enable/recurrence writers. | PASS |
| SGA-07.1 claim/start/HTTP order plus tune text | core/scheduler_game_dispatch_test.dart:64 durable claim exists at start; :296 start then result event payloads exact; app/game_notification_messages_test.dart:45 exact tuning start title and :57 character body. The unchanged core beforeHttp seam retains start-before-HTTP behavior; historical native order evidence remains separately bounded. | PASS |
| SGA-07.3 truthful same-ID result | app/game_notification_messages_test.dart:44 ids=[-42,-42] and :45 exact tuning result; core/scheduler_game_dispatch_test.dart:286–304 exact persisted status/code/time and same-ID start/result payload for each outcome; :346 confirmed survives final notice failure, :353 effect count remains 1. | PASS |
| SGA-07.4 local semantics | core/scheduler_coordinator_test.dart:334 submitted; :355 exact local title/body/negative IDs, :360 no replay. Dispatch code is outside F3 diff; current full core/app suites pass. | PASS |

## Reverse mapping and test integrity

| Changed/new test group | Count | Requirement/edge covered | Necessity |
| --- | --- | --- | --- |
| core/game_actions_tune_test.dart: explicit tune action roundtrip | 1 | SGA-11.2; SGA-01.3 | Detect lost authorization/target |
| absent/explicit-use legacy JSON | 1 | SGA-11.2; SGA-01.1 | Detect silent legacy tuning |
| tune discovery DTO JSON roundtrip | 1 | SGA-11.2 | Detect lost operation on wire |
| null/wear/Tune/empty/integer/bool operation | 6 | SGA-11.2; SGA-01.2 | Reject explicitly invalid field values |
| normalized pair discovery | 1 | SGA-11.1; SGA-02.3 | Preserve both effects and deduplicate equivalent rows |
| first tune fresh full POST | 1 | SGA-11.3; SGA-05.1/2/4 | Detect wrong row/button or stale/incomplete payload |
| two fallback directions plus six ineligible-row forms | 8 | SGA-11.3; SGA-05.3/5 | Zero effect on unavailable/unsafe candidates |
| existing game_actions_transport_test.dart assertion expanded | 0 new | SGA-11.1; SGA-02.3 | Include newly authorized tune while retaining use/identity expectations |
| EN/PT create and same-name operation selection | 2 | SGA-11.1/2/4; SGA-02.3/7 | Selected operation and localized effect stored correctly |
| EN/PT saved tuning offline edit | 2 | SGA-11.2/4; SGA-02.5/8 | Preserve authorized effect without discovery |
| EN/PT tuning cards | 2 | SGA-11.4; SGA-02.8 | Show true effect |
| operation-only edit | 1 | SGA-11.2; SGA-02.8 | Preserve identity and cadence |
| client/runner discovery/create/update/invalid RPC | 1 | SGA-11.2; SGA-01.2/3 | Real codec/storage boundary and atomic rejection |
| EN/PT native tuning notices | 2 | SGA-11.4; SGA-07.1/3 | Correct operation/character/stable ID payload |

19 new core tests and 10 new app tests; no test removed, skipped or weakened. The one prior discovery expectation was expanded because tune became authorized. Every new test maps to a spec outcome or the ineligible-row safety boundary. Assertions compare values and complete payloads, not just call counts.

## Current package gates

All below ran afresh in the main checkout, sequential SDK ownership, without test_live, production credentials, real Popmundo or a new Patrol run. Logs under evidence/ are verifier-generated; all runner/analyzer processes exited 0. Initial core wrapper incorrectly tried to exit with an empty shell variable after a successful runner; it was repeated with a direct command, yielding runner exit0 and the final retained log below. That wrapper error is not a product failure or mutant kill.

| Gate | Command and location | Outcome | Log |
| --- | --- | --- | --- |
| Core | packages/popmundo_utils: dart.bat test --reporter expanded | 438 passed, 0 failed/skipped | f3-verifier-core-tests.log |
| App | apps/popmundo_app: flutter.bat test --reporter expanded | 196 passed, 0 failed/skipped | f3-verifier-app-tests.log |
| WebView | packages/popmundo_webview: flutter.bat test --reporter expanded | 31 passed, 0 failed/skipped | f3-verifier-webview-tests.log |
| Core analyzer | root: flutter.bat analyze packages/popmundo_utils | No issues found | f3-verifier-core-analyze.log |
| App analyzer | root: flutter.bat analyze apps/popmundo_app | No issues found | f3-verifier-app-analyze.log |
| WebView analyzer | root: flutter.bat analyze packages/popmundo_webview | No issues found | f3-verifier-webview-analyze.log |

Total current default suite: 665 passed versus a330677 baseline 636 (419/186/31); delta +29. No decrease. git diff --check a330677..78e2b61 passed. Commands use cmd.exe /d /c to run installed Windows SDK .bat files from bash with workdir set.

## Discrimination sensor — scratch only

Scratch: /mnt/c/Users/Wellington/Documents/projetos/popflutter-f3-verifier, detached 78e2b61. Created using git worktree add; flutter pub get independently resolved its own .dart_tool/package_config.json (workspace package rootUri values are relative to that scratch workspace). No .dart_tool copied from the main tree. Clean pre-mutation baseline: 19 core F3 tests plus 4 focused RPC/notices tests. Each mutation was injected with sed, exact diff retained, relevant test runner failed by behavioral assertion, then the single source file restored with git restore. No test source changed.

| Mutant | Source location and fault | Discriminating failure | Result |
| --- | --- | --- | --- |
| M1 | packages/popmundo_utils/lib/src/game_actions/game_item_action.dart:15 — remove saved-operation predicate | 3 failures: tune POST uses row1 use coordinates instead of expected row2 tune at test:113; both no-fallback cases become confirmed instead of unavailable at :163 | KILLED |
| M2 | packages/popmundo_utils/lib/src/scheduler/scheduler_actions.dart:19 — absent legacy operation defaults to tune | 2 failures: exact legacy JSON gains operation=tune at test:34; legacy use rule tunes instead of unavailable at :163 | KILLED |
| M3 | packages/popmundo_utils/lib/src/game_actions/game_forms.dart:118 — Item_Tune.png maps to use | 3 failures: discovery loses tune payload at test:84; authorized tune becomes unavailable at :111; default use wrongly confirms at :163 | KILLED |
| M4 | packages/popmundo_utils/lib/src/scheduler/scheduler_actions.dart:23 — invalid explicit operation silently defaults to use | 6 failures: action decode does not throw invalidAction for null/wear/Tune/empty/integer/bool at test:63 | KILLED |
| M5 | packages/popmundo_utils/lib/src/scheduler/scheduler_actions.dart:83 — omit tune field from action serialization | RPC create returns use instead of tune at app/scheduler_instrument_rpc_test.dart:66 | KILLED |
| M6 | apps/popmundo_app/lib/scheduler/game_notification_messages.dart:43 — invert tune/use message condition | 3 failures: EN/PT tune titles become Use item/Usar item at test:45; existing use notice becomes tuning at :79 | KILLED |

Evidence: f3-verifier-m1.patch through m6.patch and matching .log files contain exact injected diff and Expected/Actual assertion failures. No compiler/analyzer/environment failure is counted as a kill. M1's shell status variable printed blank, so kill classification relies on the retained test runner's three assertion failures/Some tests failed, not the wrapper exit. Other mutants explicitly emitted KILLED from the command's nonzero-runner branch.

After restoring all mutations: 19 core and 11 focused editor/RPC/notice tests passed (f3-verifier-scratch-core-restored.log; f3-verifier-scratch-app-restored.log), processes exited 0. git status in scratch was clean. Verified absolute scratch location and registered worktree, then removed only that worktree using git worktree remove --force. Main tree production/tests never mutated. The unrelated popflutter-bsr-verifier worktree and unrelated untracked files were untouched.

Sensor depth: critical-operation manual expansion. 6 injected, 6 killed, 0 survived. SDK released to root before release build/install; no SDK/Gradle jobs overlap.

## Quality, documentation and boundary

Changes are confined to the requested use/tune operation and its presentation. Typed enum, shared codec, existing fresh-form helpers, serial gateway and client/runner patterns are reused. No new platform engine, transport or speculative abstraction. Default use serialization retains the legacy shape; explicit invalid operation cannot overwrite the catalog. The source diff adds no persisted secret/authenticated HTML/session state.

Official architecture/product/module docs describe explicit tuning and its no-fallback guard consistently. STATE/tasks/spec still had in-progress statuses during this independent pass because release/verification closure is root-owned; they must be closed against this report when the release gate finishes.

Historical Android evidence: t8-device-gates.md and its retained raw XML/oracles cover the existing secondary-engine/Keystore/native notices/Home/Recents/reboot boundaries on emulator-5554. F3 changes none of their platform/lifecycle paths. That prior evidence is carried forward only for those unchanged boundaries; it does not prove a tuning POST on Android or a live server effect. No new Patrol, real Popmundo, device manipulation or human UAT was performed by this verifier. EN/PT UI text/selection/storage behavior is established by widget tests; actual game tuning success is established here only against synthetic fixtures.

No new gaps, surviving mutants or SPEC_DEVIATION found. No lesson signal to distill; machine-owned LESSONS.md/lessons.json untouched. Guidelines applied: CLAUDE.md; .agents/skills/tlc-spec-driven/SKILL.md; references/validate.md, sub-agents.md and coding-principles.md; explicit user restriction to cat/sed/git tools for file manipulation.

## Release gate supplied by orchestrator


Read the orchestrator's raw f3-release-build.log, f3-apk-fingerprint.txt, f3-production-install.log, f3-production-before.txt, f3-production-after.txt, f3-production-launch.log, f3-production-service.txt, f3-production-activity.txt and f3-release-source.txt after SDK handoff. Release is a normal universal APK, production package com.popmundo.popmundo_app version 1/1.0.0, minSdk 24/targetSdk 36. assembleRelease succeeded in 87.5 seconds; output 62556850 bytes. Fingerprint lists both libapp.so and libflutter.so for arm64-v8a, armeabi-v7a and x86_64, so this is not inferred solely from plugin native-code badging. SHA256 bbb316e2d730360265dc23e924ee6733b72895fd0e19320720f4b2a1c2e5b640 was independently rehashed by the verifier and matches the retained fingerprint.

The release source artifact identifies inspected HEAD 78e2b61 and eight production source hashes; verifier independently checked all eight using sha256sum -c: OK. Platform/config diff for the four fixture-related paths is empty. The build emits the existing Patrol/KGP future-compatibility warning; it did not fail the release gate. This warning is not device runtime proof or a killed mutation.

On observed emulator-5554, install -r returned Success. Before/after retain firstInstallTime=2026-10-07 01:43:25, ceDataInode=353749 and deDataInode=41024; lastUpdateTime advances from 01:43:25 to 11:15:08. This demonstrates in-place replacement preserving this current installation's data directories, not preservation of the already-absent August installation. It does not claim byte-level verification of every saved preference/secret.

Launch evidence reports Status: ok, LaunchState: WARM and MainActivity. Activity evidence identifies topResumedActivity MainActivity; service evidence identifies production ForegroundService isForeground=true, foregroundId=1000, types=0x40000000, startRequested=true. No actual item tuning or crew effect was submitted by this gate. Android release actions were performed by the orchestrator after the verifier released exclusive SDK ownership; this verifier only read/checked the retained evidence.

Overall: PASS for F3. SGA-11 can move Implementing → Verified; affected previously Verified requirements stay Verified. No ranked fix gaps. Historical device/lifecycle and real-game limits remain as delimited above. No report/evidence commit performed by the verifier; root owns final documentation closure and commit.
