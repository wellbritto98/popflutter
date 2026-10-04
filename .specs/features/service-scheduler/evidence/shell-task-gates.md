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
