# T6 — Android scheduler device gate

Owner: popmundo-e2e specialist. Scope: SCHED-06/07/08/09/10 native fixture; the supplementary weekly GMT proof covers SCHED-05/07/08. Device: retained Medium_Phone_API_36.1 AVD, emulator-5554, Android 16/API 36, x86_64. No physical device or overnight observation is claimed.

Only com.popmundo.popmundo_app.backgrounddebug is the owned synthetic fixture. No game WebView, HTTP, credentials or production data are used. production-baseline.txt records firstInstallTime=2026-08-20 01:55:00, ceDataInode=368644, deDataInode=156114; these values were independently rechecked on 2026-10-05 before any install. The AVD was resumed without wiping userdata or changing the system clock/time zone. The observed native zone is GMT.

## Commands and source attribution

- Integration analyzer must pass before device execution. The final fixture analyzer result is retained in weekly-integration-analysis.log.
- Patrol invocation used isolated application ID, profile AOT, x64, --no-uninstall and --no-check-compatibility. Exactly one patrolTest exists in scheduler_test.dart. The XML is authoritative: patrol-final-green.xml:2 gives tests="1" failures="0" errors="0" skipped="0"; the Dart teardown also says passed:true in patrol-final-green-stages.log.
- The retained green Patrol, Home, screen-off, Recents and reboot evidence was built from production source c56844c. Its interval behavior is unchanged by d83414f, which only switches the timezone database import to latest_all. Earlier interval snapshots consequently contain Unknown/Unavailable; they do not prove weekly scheduling.
- The supplementary 2026-10-05 weekly proof uses production source d83414f with fixture-only additions. Its exact APK/source hashes are retained separately. No inference is made about execution during the day-long gap.
- Build command: flutter build apk --profile --target integration_test/support/scheduler_reboot_harness.dart --target-platform android-x64. Temporary synthetic app ID, profile debugging/signing/minification settings, target-platform and promoted Patrol dependency are restored before this task's commit.
- Only native builds were executed sequentially. Existing Gradle environment uses process-scoped JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\popflutter-java-afunix-disabled\not-created. Generated profile APKs are removed before packaging to avoid stale zip archive gaps; no AVD/userdata is removed.

## Check A — forward coverage with exact outcomes

Paths in the assertion column are relative to apps/popmundo_app/integration_test. Evidence paths are relative to this directory.

| Criterion | Exact assertion or retained oracle | Spec outcome |
| --- | --- | --- |
| Real Portuguese management page / persisted form | scheduler_test.dart:131 `expect(find.text('Agendamentos'), findsOneWidget)`; :146 `expect(ui.name, 'Lembrete pela tela')`; :151 `expect(ui.action.title, 'Título salvo pela tela')`; :156 `expect(ui.action.body, 'Mensagem nativa persistida')`; :161 `expect(ui.enabled, isFalse)` | SCHED-01/02/03: actual native form persisted exact trimmed payload and pause state |
| Real FGS presence | scheduler_test.dart:107 `expect(await platform.isRunningService(), isTrue)` | SCHED-08: service exists |
| Home periodic work before reopening | scheduler_test.dart:207/:217 bounded waits require submitted and plannedUtc after Home/first occurrence; :227 `expect(second.lastClaim!.plannedUtc.isAfter(first.lastClaim!.plannedUtc), isTrue)`; :232 `expect(second.lastResult.atUtc!.isAfter(first.lastResult.atUtc!), isTrue)` | SCHED-04/08: two strictly advancing background executions |
| Exact OS cards and distinct negative IDs | scheduler_test.dart:34 `expect(scheduled, hasLength(expected.length))`; :39 `expect(scheduled.map((n) => n.id), unorderedEquals(expected))`; :54 `expect(card, hasLength(1))`; :59/:60 `expect(card.single.title, title)` / `expect(card.single.body, body)`; calls :239-241 | SCHED-07: total scheduled OS records exactly 2, IDs -2/-3, exact titles/bodies; positive FGS 1000 and OS aggregate 0 excluded |
| Same card after text edit | scheduler_test.dart:271 `expect(updated.notificationId, a.notificationId)`; :276 `expect((updated.recurrence as IntervalRecurrence).anchorUtc, (a.recurrence as IntervalRecurrence).anchorUtc)`; :292 `expect(tray.where((n) => n.title == 'Scheduler Home A'), isEmpty)`; :297-302 exact ID set/card | SCHED-03/04/07: same identity and cadence, old payload replaced with exact new payload |
| Pausing blocks new work while keepalive survives | scheduler_test.dart:325 `expect(r.enabled, isFalse)`; :326 `expect(r.nextDueUtc, isNull)`; :334 `_assertAndroidIds({})` after explicit fixture cancellation and 28s; :338/:343 claims/results equal prewait; :356 `expect(await platform.isRunningService(), isTrue)` | SCHED-03/08/10: no new claim/result/OS record after last pause, session service preserved |
| Auto-start disabled with no enabled rules | android-paused-boot-options.xml:5 and :9 have autoRunOnBoot=false / autoRunOnMyPackageReplaced=false; stopWithTask=false, allowWakeLock=true | SCHED-08: boot restoration disabled while existing keepalive configuration survives |
| Screen off | android-lock-observation.txt records Asleep at both observations; exact jq criterion below compares android-home-baseline.json, android-lock-first.json and android-lock-second.json plus real card | SCHED-08: two advancing claims and submissions while screen off; keyguard credential/security lock was not configured/tested |
| Task removed from Recents | android-recents-observation.txt records two actual own-task swipes #42 then #41; android-recents-after.txt and android-recents-after-delivery.txt report zero owned task records; exact jq comparison below plus native card | SCHED-08: delivery with no Activity task |
| Actual reboot / skip before future slot | android-reboot-observation.txt records ADB reboot 22:44:03Z, before missed firstDue 22:44:08.816289Z; android-reboot-system-start.log:1 records starter=system at 22:45:53.811874Z; valid post-start observation 22:46:14Z has unchanged old result, lastClaim=null, nextDue=22:47:08.816289Z and only FGS 1000 | SCHED-06/08: missed work skipped and future slot armed before delivery; no UI bootstrap |
| Post-reboot future delivery | jq exact criterion below: plannedUtc=22:47:08.816289Z, submitted at 22:47:08.869586Z, nextDue=22:50:08.816289Z, ID=-1 and exact title/body; actual card and Activity-free service retained | SCHED-06/07/08: n=2 future slot only, stable card and background engine |
| Native suppression sensor | native-suppression-mutant.patch bypasses OS show; patrol-native-mutant.xml reports failure; patrol-native-mutant-assertion.log:1-4 shows Expected length2 / Actual[] length0 at _assertAndroidIds; restored final-green XML passes | SCHED-07/08: persisted submitted alone cannot make this gate green; native no-op mutant killed |
| Weekly native GMT | scheduler_reboot_harness.dart:118 rejects non-GMT native identifier; :160 rejects `rule.zoneId != nativeZone || rule.nextDueUtc != target`; independent DateTime.utc fields +2min at :122 | SCHED-05/07/08: supplementary retained delivery criteria added below |

All waits in Patrol are bounded to 35s; notification action has the production five-second bound. standalone stage buttons are fixture entrypoints, not Patrol tests. Reboot necessarily kills instrumentation, so its gate combines durable JSON and actual OS service/notification/Activity evidence. Error/failure/concurrency/DST edge cases retain their core/shell exact assertion mapping in core-task-gates.md and shell-task-gates.md; this task does not claim every edge case is separately executed on Android.

## Reproducible retained evidence oracles

Run from this evidence directory with jq and rg. Each jq command must print true and exit 0 (-e). ISO timestamps here are UTC with identical date/format; lexical ordering is exact for these records.

Screen-off claims and results, with first claim after the Home baseline and second claim later:

```bash
jq -e -s '.[0].rules[0].lastClaim.plannedUtc < .[1].rules[0].lastClaim.plannedUtc and .[1].rules[0].lastClaim.plannedUtc < .[2].rules[0].lastClaim.plannedUtc and .[1].rules[0].lastResult.status == "submitted" and .[2].rules[0].lastResult.status == "submitted" and .[1].rules[0].lastResult.atUtc < .[2].rules[0].lastResult.atUtc and .[1].rules[0].notificationId == -1 and .[2].rules[0].notificationId == -1' android-home-baseline.json android-lock-first.json android-lock-second.json
rg -n 'mWakefulness=Asleep' android-lock-observation.txt
rg -n 'id=-1 tag=null|android.title=String \(Scheduler lifecycle fixture\)|android.text=String \(Home lock and Recents evidence\)' android-lock-cards.txt
```

Task removal: first claimed slot strictly after actual removal 22:32:09Z; two samples and unchanged stable card identity:

```bash
jq -e -s '.[0].rules[0].lastClaim.plannedUtc < .[1].rules[0].lastClaim.plannedUtc and .[1].rules[0].lastClaim.plannedUtc > "2026-10-04T22:32:09Z" and .[1].rules[0].lastClaim.plannedUtc < .[2].rules[0].lastClaim.plannedUtc and .[1].rules[0].lastResult.status == "submitted" and .[2].rules[0].lastResult.status == "submitted" and .[1].rules[0].lastResult.atUtc < .[2].rules[0].lastResult.atUtc and .[2].rules[0].notificationId == -1' android-recents-baseline.json android-recents-first.json android-recents-second.json
! rg -q 'com.popmundo.popmundo_app.backgrounddebug' android-recents-after.txt android-recents-after-delivery.txt
rg -n 'id=-1 tag=null|android.title=String \(Scheduler lifecycle fixture\)|android.text=String \(Home lock and Recents evidence\)' android-recents-cards.txt
```

Reboot skip and next future delivery. The early 22:45:30Z poll precedes delayed BOOT_COMPLETED/service start and is not counted as skip/failure evidence. The valid 22:46:14Z poll is after starter=system and before 22:47:08.816289Z:

```bash
jq -e -s '.[0].rules[0].nextDueUtc == "2026-10-04T22:44:08.816289Z" and .[1].rules[0].lastClaim == null and .[1].rules[0].lastResult == .[0].rules[0].lastResult and .[1].rules[0].nextDueUtc == "2026-10-04T22:47:08.816289Z" and .[2].rules[0].lastClaim.plannedUtc == .[1].rules[0].nextDueUtc and .[2].rules[0].lastAttemptUtc == .[1].rules[0].nextDueUtc and .[2].rules[0].lastResult == {"status":"submitted","atUtc":"2026-10-04T22:47:08.869586Z","errorCode":null} and .[2].rules[0].nextDueUtc == "2026-10-04T22:50:08.816289Z" and .[2].rules[0].notificationId == -1 and .[2].rules[0].action == {"type":"localNotification","title":"Scheduler reboot fixture","body":"Next future occurrence only"}' android-reboot-staged.json android-reboot-before-future.json android-reboot-future.json
rg -n 'starter=system' android-reboot-system-start.log
rg -c 'NotificationRecord.*id=-' android-reboot-before-future-cards.txt # 0; rg exits 1 because no negative card exists
rg -n 'id=-1 tag=null|android.title=String \(Scheduler reboot fixture\)|android.text=String \(Next future occurrence only\)' android-reboot-future-cards.txt
```

## Check C — reverse necessity and litmus

| Assertion/evidence group | Requirement / keep reason |
| --- | --- |
| Native page and exact persisted UI payload | SCHED-01/02/03; confirms actual form/storage channel beyond fake tests |
| Signed IDs, complete total, per-ID exact payload, replacement | SCHED-07; detects absent/duplicate/wrong platform notification |
| Two samples before reopening and Activity-free delivery | SCHED-08; rejects frozen clock/foreground-only execution |
| Cadence retained on text edit | SCHED-03/04; approved existing rule identity/cadence contract |
| Pause claim/result equality and preserved FGS/boot flags | SCHED-03/08/10; absence paired with service presence |
| Reboot exact skipped/next-future slot, OS card and system start | SCHED-06/08; rejects backlog replay and app-open bootstrap substitutes |
| Native GMT weekly calendar and localSlot | SCHED-05/07/08; real installed timezone/plugin path after alias fix |
| OS suppression mutation | T6 done-when + specialist rule; detects a realistic native no-op despite persisted submitted |

Adequacy: every T6 criterion maps to concrete assertions or reproducible retained criteria; payload values and total OS count are inspected separately. No assertion-only mock call count, skipped tests or unanchored framework tests are used. Guidelines: CLAUDE.md and .agents/agents/popmundo-e2e.md (one Patrol test, no game, analyzer before device, real execution, bounded waits, mutation red/restore green). Screenshot artifacts are supplemental and are not counted as gate assertions.

## Bounded limitations

One Android emulator/API/ABI. Home, screen off/Asleep, actual own Recents removal and ADB reboot were observed. No physical handset, OEM policy, PIN/keyguard authentication lock, force-stop bypass or overnight measurement is claimed. Android may delay boot/service startup and delivery; the exact observed slot/result/card are the evidence, not a promise of second-perfect Android delivery. Independent feature verification and normal production release/install belong to T7.

## Supplementary native weekly GMT — 2026-10-05

Production source: d83414f (full SHA in weekly-source-attribution.txt). Fresh profile APK hashes and fixture/runner file SHA256 values are in the same file. weekly-profile-build.log ends with exit-success artifact 37.0MB (40.7s); weekly-integration-analysis.log ends No issues found (4.2s), before installation. adb install -r succeeded for only the isolated package. PID 4991's android-weekly-start.log:1 explicitly reports rawZone=GMT. The weekly-ready native log line is truncated by logcat; complete saved android-weekly-staged.json and android-weekly-delivered.json are the authoritative records.

The target was computed in the fixture directly as DateTime.utc(current UTC year/month/day/hour/minute)+2min. In native GMT that equals local Monday 22:53. stage=weekly-ready reports expectedUtc=2026-10-05T22:53:00.000Z. Before any delivery the saved rule has exact weekdays[1], hour22, minute53, zoneGMT, nextDue 2026-10-05T22:53:00.000Z, neverExecuted and no claim. nextSequence advanced2→3; negative ID−2 was newly allocated. Rules previously enabled were paused and their own OS cards explicitly canceled by the fixture (:134-135); cancellation is test setup and is not claimed as production pause behavior.

android-weekly-home-activity.txt and android-weekly-after-activity.txt show NexusLauncherActivity topResumed, owned task visible=false and mLastPausedActivity. No app reopening occurs between these samples. Before target, android-weekly-before-cards.txt contains no negative card and FGS1000 exists. android-weekly-observation.txt samples include 22:52:51 before target and the subsequent delivery sample. After target, android-weekly-delivered.json records exact lastClaim planned 22:53:00.000Z / revision1 / localSlot 2026-10-05T22:53, lastAttempt 22:53:00.000Z, submitted 22:53:00.030766Z, nextDue 2026-10-12T22:53:00.000Z. Disabled previous rule is byte-value equal to its staged rule. The OS dump contains exactly one negative NotificationRecord, ID−2, exact title Scheduler weekly GMT fixture/body GMT alias database evidence, plus FGS 1000. The service dump confirms actual foreground service.

Reproduce all weekly oracle booleans (four true values are retained in weekly-oracles.log in command order):

```bash
jq -e -s '.[0].nextSequence == 2 and .[1].nextSequence == 3 and .[1].rules[0].enabled == false and .[1].rules[0].nextDueUtc == null and .[1].rules[1].id == "e2e-weekly-gmt" and .[1].rules[1].notificationId == -2 and .[1].rules[1].recurrence == {"type":"weekly","weekdays":[1],"hour":22,"minute":53} and .[1].rules[1].zoneId == "GMT" and .[1].rules[1].nextDueUtc == "2026-10-05T22:53:00.000Z" and .[1].rules[1].lastClaim == null and .[1].rules[1].lastResult.status == "neverExecuted" and .[1].rules[1].action == {"type":"localNotification","title":"Scheduler weekly GMT fixture","body":"GMT alias database evidence"}' android-weekly-preinstall.json android-weekly-staged.json
jq -e -s '.[0].rules[0] == .[1].rules[0] and .[1].nextSequence == .[0].nextSequence and .[1].rules[1].notificationId == .[0].rules[1].notificationId and .[1].rules[1].revision == 1 and .[1].rules[1].zoneId == "GMT" and .[1].rules[1].recurrence == {"type":"weekly","weekdays":[1],"hour":22,"minute":53} and .[1].rules[1].lastAttemptUtc == "2026-10-05T22:53:00.000Z" and .[1].rules[1].lastClaim == {"revision":1,"plannedUtc":"2026-10-05T22:53:00.000Z","localSlot":"2026-10-05T22:53"} and .[1].rules[1].lastResult == {"status":"submitted","atUtc":"2026-10-05T22:53:00.030766Z","errorCode":null} and .[1].rules[1].nextDueUtc == "2026-10-12T22:53:00.000Z" and .[1].rules[1].action == {"type":"localNotification","title":"Scheduler weekly GMT fixture","body":"GMT alias database evidence"}' android-weekly-staged.json android-weekly-delivered.json
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 1 and ([scan("NotificationRecord[^\n]* id=-2 tag=null")]|length) == 1 and contains("android.title=String (Scheduler weekly GMT fixture)") and contains("android.text=String (GMT alias database evidence)")' android-weekly-delivered-cards.txt
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 0 and contains("id=1000 tag=null")' android-weekly-before-cards.txt
rg -n 'topResumedActivity=.*NexusLauncherActivity|backgrounddebug.*visible=false|mLastPausedActivity' android-weekly-home-activity.txt android-weekly-after-activity.txt
rg -n 'isForeground=true' android-weekly-service.txt
```

The first two jq commands validate every calendar/claim/result/payload value; the latter two validate actual OS count independently. This closes the native alias path that interval evidence cannot establish.

## Cleanup and final T6 gate

After retaining all proof, `adb shell pm clear com.popmundo.popmundo_app.backgrounddebug` returned Success (android-fixture-cleanup.txt), clearing only the owned synthetic fixture, its FGS and notifications. production-after-t6.txt matches production-baseline.txt's firstInstallTime, ceDataInode and deDataInode and unchanged lastUpdateTime. No uninstall, data clearing, force-stop or userdata operation targeted production.

Explicit configuration paths were restored from HEAD: apps/popmundo_app/android/app/build.gradle.kts, apps/popmundo_app/android/gradle.properties, apps/popmundo_app/pubspec.yaml, pubspec.lock. Normal `flutter pub get` completed (device-config-restored-pub-get.log); git diff on all four paths is empty. A further analyzer after restoration passed (device-restored-integration-analysis.log). The normal release must rebuild without --no-pub to regenerate plugin registration without the temporary native Patrol promotion.

Retained oracle commands were executed fresh and all exited 0: device-retained-oracles.log contains seven true values (three durable JSON comparisons plus four exact native-card oracles), weekly-oracles.log four true values (weekly stage, delivery, exact OS card count/payload, no card before future). The original final native Patrol XML remains 1 test/0 failures/0 errors/0 skips. Suppression sensor red and subsequent restored green are both retained. T6 gate is PASS within the bounded device scope; independent full-feature verification and production release/install remain T7 responsibilities.

## Additional exact native-card oracles

Full source SHAs for every production stage are recorded in device-source-attribution.txt; the weekly fixture/APK fingerprints are in weekly-source-attribution.txt. In addition to the three durable JSON comparisons, these four actual NotificationManager assertions were executed and appended to device-retained-oracles.log (seven true values total, in this order: screen-off JSON, Recents JSON, reboot JSON, screen-off card, Recents card, pre-future card absence with FGS presence, reboot future card):

```bash
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 1 and contains("id=-1 tag=null") and contains("android.title=String (Scheduler lifecycle fixture)") and contains("android.text=String (Home lock and Recents evidence)")' android-lock-cards.txt
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 1 and contains("id=-1 tag=null") and contains("android.title=String (Scheduler lifecycle fixture)") and contains("android.text=String (Home lock and Recents evidence)")' android-recents-cards.txt
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 0 and contains("id=1000 tag=null")' android-reboot-before-future-cards.txt
jq -R -s -e '([scan("NotificationRecord[^\n]* id=-[0-9]+ tag=null")]|length) == 1 and contains("id=-1 tag=null") and contains("android.title=String (Scheduler reboot fixture)") and contains("android.text=String (Next future occurrence only)")' android-reboot-future-cards.txt
rg -n 'isForeground=true' android-lock-service.txt android-recents-service.txt android-reboot-before-service.txt android-reboot-future-service.txt
! rg -q 'com.popmundo.popmundo_app.backgrounddebug' android-reboot-before-future-activity.txt android-reboot-future-activity.txt
```

The four service files each contain isForeground=true at line32, foregroundId1000 and service type0x40000000. Empty package-filtered Activity files establish absence only in conjunction with these service records, system-start evidence and advancing durable claims. All of the jq assertions target complete synthetic-package OS records. They count all negative records, separately confirm the expected ID and confirm both exact payload fields. Their truth does not depend on screenshots or persisted submitted alone.
