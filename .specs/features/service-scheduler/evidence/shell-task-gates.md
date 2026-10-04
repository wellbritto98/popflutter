# Shell task evidence

## T4 — Android service runtime and transport

Assumptions: approved Android-only local notification scope; pure core T1–T3 contracts are authoritative; native lifecycle evidence belongs to T6. Files: scheduler client/store/runner/device zone/environment, existing FGS platform/handler and strict local-notification adapter, Android subtype description, app dependency/lock, four scheduler test files. No main-isolate scheduler writer.

Red: scheduler_runtime_test + scheduler_client_test failed compilation because the new files/APIs were absent; scheduler_platform_test failed compilation because showScheduledNotification did not exist. Exit 1 observed before production implementation.

Green: 15 focused scheduler tests pass. Complete app gate flutter test --no-pub: 116 passed, zero failures. flutter analyze --no-pub: No issues found. Existing menu, session, GM, overlay and notification tests remain green. Native Android build intentionally deferred to T6.

| Requirement / edge | Exact assertion evidence | Expected outcome |
| --- | --- | --- |
| SCHED-03/10 authoritative mutation IPC | scheduler_client_test.dart:114 — expect(sent.last['draft'], {name:'saved',enabled:true,recurrence:draft.recurrence.toJson(),action:{type:'localNotification',title:'title',body:'body'}}); :133 — expect(sent.last['revision'],1); :135 — expect(SchedulerSnapshot.decode(store.raw!).rules.single.name,'edited') | Exact validated draft/revision transmitted, durable returned catalog |
| SCHED-07 saved native notification payload | scheduler_platform_test.dart:143 — expect(payload['id'],-5); :144 — expect(payload['title'],'Saved'); :145 — expect(payload['body'],'Message') | Stable negative ID and saved title/body |
| SCHED-09 truthful native failure | scheduler_platform_test.dart:109–119 — expectLater(...,throwsA(SchedulerException code notificationInitializationFailed)); expect(calls.where(method show),isEmpty); :125–137 permissionDenied assertion; :157 submission PlatformException | No false success/no submission after failed initialization/permission |
| SCHED-08 complete enabled boot options | scheduler_platform_test.dart:81–87 — expect(options.autoRunOnBoot,true); expect(options.autoRunOnMyPackageReplaced,true); expect(options.allowWakeLock,true); expect(options.stopWithTask,false); expect(eventAction,repeat(5000)) | Boot/package restoration enabled without changing heartbeat/wake/Recents contract |
| SCHED-08 empty/disabled/corrupt startup nonregression | scheduler_platform_test.dart:38–49 — expect(isInitialized,true); expect(autoRunOnBoot,false); expect(autoRunOnMyPackageReplaced,false); expect(prefs.getString(storageKey),raw) | Existing session initialization survives; blob retained; scheduler boot fails closed |
| SCHED-09 permission denied/boot update failure | scheduler_runtime_test.dart:141–146 — expect(reply.error,'permissionDenied'); expect(coordinator.rules,isEmpty); expect(reply.error,'bootConfigurationFailed'); expect(durableRule.id,'stable') | No activation on denied permission; no ACK after uncertain boot configuration; persisted identity retained |
| SCHED-10 coalesced reconciliation | scheduler_runtime_test.dart:173 — expect(identical(first,second),true); :176 — expect(refreshes,2) | At most one in-flight heartbeat/timer reconciliation |
| SCHED-03/09 fresh storage and false write | scheduler_edge_test.dart:31 — expect(await store.read(),'external'); :32–35 — expectLater(write('next'),throwsA(SchedulerException code writeFailed)) | Fresh-engine changes observed; false writes fail |
| SCHED-05 zone failures / changes | scheduler_edge_test.dart:48/51/54/57 — expect(zone.identifier,'Unknown/Unavailable'/'America/Sao_Paulo'/'America/Sao_Paulo'/'America/New_York') | Bounded first failure without UTC default; last-valid retained; actual change detected |
| SCHED-04/08 timer independent of heartbeat | scheduler_edge_test.dart:99 — expect(action.calls,[-1]); after delete expect(action.calls,[-1]); expect(coordinator.rules,isEmpty) | Seconds timer executes; delete cancels subsequent delivery |
| SCHED-09 corrupt/recoverable runtime | scheduler_edge_test.dart — expect(reply.error,'corruptSnapshot'); expect(store.raw,'corrupt'); after fresh read expect(reply.snapshot,SchedulerSnapshot().toJson()) | Fail closed/preserve corruption, recover without restart |
| SCHED-10 request correlation | scheduler_client_test.dart:23 — expect(requestId0,isNot(requestId1)); :34/35 nextSequence 2/1; remote revisionConflict/invalidResponse exact code assertions | Out-of-order replies isolated; errors typed; malformed snapshots rejected |

Adequacy: each test maps to SCHED-03/04/05/07/08/09/10; payload-bearing assertions compare actual fields, not calls alone. No test deleted/skipped/weakened. Existing LocalNotificationsService initialize/no-op behavior retained; only scheduled actions use strict checks. Notification initialization uses installed FLN named arguments and signed IDs. flutter_timezone 5.1.1 installed source confirms getLocalTimezone()->TimezoneInfo.identifier; bounded lookup caches last valid IANA zone. Public package source: https://pub.dev/packages/flutter_timezone .

Review boundaries: true Home/Recents/boot/platform tray delivery remains T6 evidence; no overnight observation or device success claimed here.

## T5 — Native sidebar and authoritative editor

Assumptions: approved existing Material theme, local notifications only, Android continuous service and localized iOS explanation. Files: native scheduler screen/editor/recurrence/permission/label/connection helpers, composition root, menu registry, EN/PT catalogs, fake API and widget tests. The UI issues RPCs and never writes scheduler preferences.

Red: initial scheduler editor/screen widget tests failed compilation while the new page/editor APIs were absent; registry callback expectation failed before the approved item was added. Later exact runtime-result assertions exposed the need for separate execution-failure labels. Form validation uses a finite mounted form so offscreen fields still participate. The readiness test initially hung because its fake timer and real clock disagreed; an injectable clock now preserves the exact bounded-unavailable assertion, without skipping it or leaving a polling loop after expiry.

Green: flutter test --no-pub completed with 132 passed, zero failures, exit 0 (116 previous + 16 new). flutter analyze --no-pub: No issues found, exit 0. jq empty accepted both localization catalogs; scoped git diff --check found no whitespace errors. Native build/device evidence remains T6.

Check A — sufficient coverage (all paths below are relative to apps/popmundo_app/test):

| Requirement / done-when | Exact assertion evidence | Spec-defined outcome | Covered |
| --- | --- | --- | --- |
| SCHED-01 release sidebar / localization | app_menu_registry_test.dart:23 — expect(schedules.label,'Schedules'); :24 — expect(schedules.subtitle,'Recurring local reminders'); :26 — expect(calls,1); :27 — expect(items.any(id debug),false); :42 — expect(PT schedules.label,'Agendamentos') | Approved release item routes once; both catalogs resolve; existing debug gate retained | Yes |
| SCHED-01 empty/iOS state | scheduler_screen_test.dart:129 — expect(find.text('No schedules yet'),findsOneWidget); :141 — expect(find.text('Agendamentos'),findsOneWidget); :142 — expect(find.text('Os agendamentos contínuos estão disponíveis apenas no Android.'),findsOneWidget); :148 — expect(find.byKey(Key('schedule-add')),findsNothing) | Empty Android catalog; truthful localized unavailable iOS state | Yes |
| SCHED-02 fields/default interval/action | scheduler_editor_test.dart:112 — expect(rule.name,'Reminder'); :113 — expect(rule.action.title,'Saved title'); :114 — expect(rule.action.body,'Saved body'); :115 — expect(interval.quantity,1); :116 — expect(interval.unit,IntervalUnit.minutes); :120 — expect(decodedPersisted.rules.single.id,rule.id) | Trimmed saved values and default one-minute recurrence match durable returned rule | Yes |
| SCHED-02 invalid text/number/overlong | scheduler_editor_test.dart:138 — expect(find.text('Use a whole number from 1 to 9999'),findsOneWidget) for 0/10000/1.5; :146/:147/:148 — expect(exact 1–80/120/1000 field errors,findsOneWidget); :149 — expect(api.store.raw,isNull); :42/:43/:44 PT exact validators | Invalid pasted decimal and all overlong values produce field errors, no truncation or mutation | Yes |
| SCHED-02 day interval / 24h / weekly | scheduler_editor_test.dart:65 — expect(interval.unit,IntervalUnit.days); :66 — expect(interval.quantity,2); :67 — expect(rule.nextDueUtc,DateTime.utc(2026,10,6,12)); :76 — expect(MediaQuery.of(TimePickerDialog).alwaysUse24HourFormat,true); :165 — expect(find.text('Choose at least one weekday'),findsOneWidget); :174/:175/:176 — expect(weekly.weekdays,{1,4}); expect(hour,9); expect(minute,0) | Elapsed 24h days; explicit 24h picker; nonempty ISO weekdays and saved intended time | Yes |
| SCHED-03 no optimistic ACK / pending | scheduler_editor_test.dart:102 — expect(saveButton.onPressed,isNull); :108 — expect(saved,isNull); :120 — expect(decodedPersisted.rules.single.id,rule.id) after completion | Save remains pending until authoritative persistence reply | Yes |
| SCHED-03 cancel/edit cadence | scheduler_editor_test.dart:277 — expect(after.notificationId,before.notificationId); :278 — expect(after.interval.anchorUtc,before.interval.anchorUtc); :282 — expect(after.nextDueUtc,before.nextDueUtc); :288 — expect(api.store.raw,raw) after cancel | Text edit keeps card/cadence; cancel leaves persisted rule unchanged | Yes |
| SCHED-03 authoritative pause/delete | scheduler_screen_test.dart:186 — expect((await api.list()).rules.single.enabled,false); :187 — expect(find.text('Paused'),findsOneWidget); :192 — expect(rules,hasLength(1)) after cancel; :197 — expect(rules,isEmpty) after confirm; :198 — expect(find.text('No schedules yet'),findsOneWidget) | Pause follows durable reply; delete requires confirmation; visible catalog matches | Yes |
| SCHED-08 current permission/background status | scheduler_screen_test.dart:210/:211/:212 — expect(exact Notifications denied / Background battery optimized / Service running texts,findsOneWidget); :217 — expect(find.text('Notifications: allowed'),findsOneWidget) after action | Permission/battery/service statuses and actionable permission flow visible | Yes |
| SCHED-09 lookup failure / readable catalog | scheduler_screen_test.dart:232 — expect(find.text('Readable'),findsOneWidget); :233 — expect(find.text('Could not read permission or background status. Try again.'),findsOneWidget) | Permission lookup failure is visible without hiding readable rules | Yes |
| SCHED-09 denied/failed saves retain values | scheduler_editor_test.dart:190 — expect(api.creates,0); :191 — expect(nameController.text,' Reminder '); :198 — expect(find.text('Allow notifications to enable this schedule.'),findsOneWidget); :205 — expect(exact saveFailed text,findsOneWidget); :211 — expect(titleController.text,' Saved title '); :218 — expect(api.store.raw,isNull) | Denial prevents activation; error preserves draft and catalog | Yes |
| SCHED-03/09 lost save reply / adoption | scheduler_editor_test.dart:234 — expect(saveButton.onPressed,isNull) after failed refresh; :240 — expect(editor,findsOneWidget); :246/:247 — expect(api.creates,1); expect(api.updates,1); :248 — expect(rules.single.id,id); :249 — expect(nextSequence,2) | Failed reread blocks blind resubmit; recovered stable ID is adopted with no duplicate | Yes |
| SCHED-08 bounded first RPC readiness | scheduler_connection_test.dart:21 — expectLater(pending,throwsA(SchedulerException code serviceUnavailable)) after deadline; :53 — expect(sent,isEmpty) before heartbeat; :56 — expect(sent,hasLength(1)) after heartbeat; :62 — expect((await pending).rules,isEmpty) | Native-running flag alone cannot drop first request; bounded typed unavailable error and authoritative ready reply | Yes |
| SCHED-01/09 visible current next/result | scheduler_screen_test.dart:82 — expect(find.text('Submitted to Android'),findsOneWidget); :83 — expect(find.text(nextText(DateTime.utc(2026,10,4,12,0,20))),findsOneWidget); :87/:109 — expect(find.text(at.toLocal().toString().split('.').first),findsOneWidget); :105 — expect(find.text('Failed: Notification service could not initialize.'),findsOneWidget) | Visible list refreshes next due and truthful submission/failure with timestamp without manual action; oracle portable across host zones | Yes |
| SCHED-01/10 visible-route refresh bounded | scheduler_screen_test.dart:33 — expect(api.lists,before+1) while read pending across 20s; :40 — expect(api.lists,paused); :43 — expect(api.lists,paused+1) on resume; :117 — expect(api.lists,reads) while editing | Coalesced reads; inactive/editor polling stops; disposal cancels timer | Yes |

Check C — necessary reverse mapping:

| Test group and assertion | Maps to | Keep |
| --- | --- | --- |
| registry :23/:42 label and :26 callback; old callback/debug assertions preserved | SCHED-01, existing sidebar compatibility | Yes |
| editor :42 PT validation and :65/:76 days/24h | SCHED-01/02 | Yes |
| editor :112 actual rule fields and :120 persisted identity | SCHED-02/03 | Yes |
| editor :138/:149 invalid input and unchanged store | SCHED-02/09 | Yes |
| editor :165/:174 weekdays/time | SCHED-02 | Yes |
| editor :191/:211 retained inputs and :218 unchanged store | SCHED-09 | Yes |
| editor :234/:248/:249 timeout adoption | SCHED-03/09 | Yes |
| editor :277/:282/:288 cadence/cancel | SCHED-03 | Yes |
| screen :33/:40/:82/:105/:117 coalesced live feedback | SCHED-01/09/10 | Yes |
| screen :129/:142 empty/iOS | SCHED-01/08 | Yes |
| screen :186/:192/:197 pause/delete | SCHED-03 | Yes |
| screen :210/:217/:232/:233 status/action/error | SCHED-08/09 | Yes |
| connection :21/:53/:62 deadline/readiness | SCHED-08/09/10 | Yes |

Adequacy verdict: every T5 criterion has concrete payload/state evidence; no skipped/deleted tests or weakened existing callback/debug assertions. Check B uses actual persisted values, submitted/result fields and error retention rather than call counts alone. Check D follows existing app widget/fake-platform/EasyLocalization conventions and the task coverage matrix. No SPEC_DEVIATION. Successful submission means Android accepted the native notification request, not guaranteed user visibility. Final native lifecycle and independent discrimination verification remain with T6/T7 owners.

Final test inventory for T5 files: editor 8, screen 5, connection 2, menu registry 9 = 24 tests (8 existing registry cases + 16 new cases), all included in the successful 132-test full app gate.

## Follow-up fix — recover transient runner factory failure

Problem: a failure before createSchedulerRunner returned left the handler permanently without a runner. Later heartbeat/RPC now retries a completed failed creation. _startupWork tracks the underlying factory/start Future independently of the five-second _starting deadline, retaining sole ownership when that deadline expires. A late factory result after destruction is disposed without start; existing-runner catalog errors still recover through reconcile.

Red: scheduler_task_handler_test failed compilation against the original handler (missing injectable factory/send/Android seam), exit 1, before implementation. Four spec-derived channel/lifecycle tests then passed. Full flutter test --no-pub completed 136 passed, zero failed, exit 0. Analyzer reported one missing-braces info in the fixture; corrected with no outcome change, then flutter analyze --no-pub: No issues found, exit 0 and four focused tests reconfirmed. No native build/pub get ran for this fix.

| AC / edge (Check A) | Exact assertion in apps/popmundo_app/test/scheduler_task_handler_test.dart | Expected outcome / covered |
| --- | --- | --- |
| SCHED-09 transient startup recovery + SCHED-10 authoritative read | :66 — expect(sent.single,{'heartbeat':at.toIso8601String()}); :70 — expect(attempts,2); :71 — expect(runner.starts,1); :72 — expect(sent.last,{type:'scheduler.response',requestId:'recovered',snapshot:SchedulerSnapshot().toJson()}) | Heartbeat retained; successful second factory owns runner; exact catalog reply / Yes |
| SCHED-09 RPC recovery after completed failure | :97 — expect(attempts,2); :98 — expect(sent.single['snapshot'],SchedulerSnapshot().toJson()); :99 — expect(sent.single['requestId'],'rpc') | RPC can recover without another tick and returns authoritative matching response / Yes |
| SCHED-09 bounded unavailable + SCHED-10 single writer | :126 — expect(attempts,1) after five-second deadline and three ticks; :127 — expect(heartbeatMessages,hasLength(3)); :128 — expect(sent.last,{type:'scheduler.response',requestId:'pending',error:'runtimeUnavailable'}); :137 — expect(attempts,1); :138 — expect(runner.starts,1); :139/:140 exact snapshot/ready requestId | Timeout cannot start overlapping factories; heartbeat/RPC bounded; eventual same runner accepted / Yes |
| SCHED-08 service destruction cleanup | :164 — expect(runner.disposals,1); :165 — expect(runner.starts,0); :168 — expect(attempts,1); :169 — expect(sent.single,{'heartbeat':at.toIso8601String()}) | Late result disposed, no Timer armed or replacement writer created / Yes |

| Test assertion (Check C) | Maps to | Keep |
| --- | --- | --- |
| :66/:72 recovery heartbeat and exact snapshot envelope | SCHED-09/10 startup recovery | Yes |
| :98/:99 exact RPC snapshot/correlation | SCHED-09/10 recovery route | Yes |
| :126/:128/:139 underlying-owner count plus bounded typed error and eventual state | SCHED-09/10 single writer / timeout | Yes |
| :164/:165/:169 late disposal/no-start/heartbeat | SCHED-08/09 cleanup | Yes |

Adequacy: real SchedulerRunner/coordinator behind an injected factory, exact response payloads plus ownership/disposal assertions. No UTC fallback, game runtime, skipped tests or weaker existing assertions. Existing corrupt-catalog recovery test remains green. Guidelines: app fake-platform/channel/widget conventions; no device behavior claimed.
