# Pure-Dart core task gates

## T1 — validated snapshot

Assumptions: approved SCHED-02 bounds/versioned JSON; pure Dart, no plugin/game/JS. Files: scheduler_models.dart, barrel export, scheduler_models_test.dart, this evidence. No test weakening/deletion/skips. Full roundtrip compares each named field to the literal expected payload.

Red: dart test test/scheduler_models_test.dart exited 1 (missing classes). Green focused 15 passed. Full dart test --reporter expanded 239 passed (224 existing +15 new); dart analyze clean. CLAUDE.md/popmundo-utils guidelines followed. No SPEC_DEVIATION.

Evidence paths below are relative to packages/popmundo_utils/test/. Multi-line assertions cite their first line; literal expected object remains in source.

| Criterion (A) | Exact file:line + expression | Spec outcome | Covered |
| --- | --- | --- | --- |
| SCHED-02 trim/default | scheduler_models_test.dart:21 expect(draft().name, 'Reminder'); :22 expect(draft().action.title, 'Title'); :23 expect(draft().action.body, 'Message'); :24 expect(interval().duration, const Duration(minutes: 1)) | Trimmed, one minute | Yes |
| Counts | :28 expect(() => interval(count), throwsA(isA<SchedulerException>())); :32 expect(interval(1).quantity, 1); :33 expect(interval(9999).quantity, 9999) | Reject 0/10000, inclusive bounds | Yes |
| Weekdays/time | :41 expect(() => WeeklyRecurrence(weekdays: days, hour: 9, minute: 0), throwsA(isA<SchedulerException>())); :54 expect(() => WeeklyRecurrence(weekdays: {1}, hour: time[0], minute: time[1]), throwsA(isA<SchedulerException>())) | Reject empty/0/8, hour -1/24, minute -1/60 | Yes |
| Text | :62 expect(() => draft(name: text), throwsA(isA<SchedulerException>())); :65 title equivalent; :68 body equivalent; :70 expect(draft(name: 'a' * 80, title: 'a' * 120, body: 'a' * 1000).name.length,80); :74 expect(draft(title: 'a' * 120).action.title.length, 120); :75 expect(draft(body: 'a' * 1000).action.body.length, 1000) | Reject blanks/above maximum; accept maxima | Yes |
| JSON payload/immutability | :103 expect(decoded.toJson(), {schemaVersion:1,nextSequence:2,rules:[literal all-field object]}); :139 expect(() => decoded.rules.clear(), throwsUnsupportedError); :140 expect(WeeklyRecurrence.fromJson({...}).toJson(), {type:weekly,weekdays:[1,4],hour:9,minute:30}) | Every field exactly preserved | Yes |
| SCHED-07 IDs | :158 expect(SchedulerSnapshot().nextNotificationId, -1); :159 expect(SchedulerSnapshot(nextSequence: 2147483648).nextNotificationId,-2147483648); :163 expect(() => SchedulerSnapshot(nextSequence:2147483649).nextNotificationId,throwsA(isA<SchedulerException>().having((e)=>e.code,'code','idExhausted'))); :173 expect(SchedulerSnapshot.decode(SchedulerSnapshot(nextSequence:7).encode()).nextNotificationId,-7) | Negative int32, explicit exhaustion, no recycling | Yes |
| SCHED-09 corrupt | :189 expect(() => SchedulerSnapshot.decode(raw), throwsA(isA<SchedulerException>())) | Reject JSON/version/noninteger sequence | Yes |
| Distinct IDs and no sequence reuse | :203 expect(() => SchedulerSnapshot(nextSequence:2,rules:[rule,rule]),throwsA(isA<SchedulerException>())); additional separate uniqueness assertions located below | Reject duplicate logical IDs separately from notification IDs | Yes |

| Assertions (C reverse map) | Requirement | Keep |
| --- | --- | --- |
| :21–24 trimming/default | SCHED-02 | Yes |
| :28/32/33 bounds | SCHED-02 | Yes |
| :41/54 weekday/time | SCHED-02 | Yes |
| :62/65/68/70/74/75 text | SCHED-02 | Yes |
| :103/139/140 payload | T1 immutable JSON | Yes |
| :158/159/163/173 identity | SCHED-07 | Yes |
| :189/203 and uniqueness/bad IDs below | SCHED-09/10/T1 | Yes |

A/B/C/D PASS: scoped sufficient checks, literal payload assertions, no shallow or speculative tests; coordinator durable preservation/deletion belongs to T3.

Additional T1 independent invariants (both A and C; SCHED-07/09/10, Keep Yes): scheduler_models_test.dart:207 expect(() => SchedulerSnapshot(nextSequence:3,rules:[rule,ScheduledRule.fromJson({...rule.toJson(),'id':'schedule-2'})]),throwsA(isA<SchedulerException>())); outcome duplicate notification ID rejected even with different logical IDs. :217 expect(() => SchedulerSnapshot(nextSequence:3,rules:[rule,ScheduledRule.fromJson({...rule.toJson(),'notificationId':-2})]),throwsA(isA<SchedulerException>())); outcome duplicate logical ID rejected even with different notification IDs. :228 expect(() => ScheduledRule.fromJson({...rule.toJson(),'notificationId':bad}),throwsA(isA<SchedulerException>())); bad=0,1,-2147483649 rejected. :234 expect(() => SchedulerSnapshot(nextSequence:1,rules:[rule]),throwsA(isA<SchedulerException>())); live ID may not reach/reuse the next sequence. Final analyzer: No issues found, exit 0.

## T2 — deterministic recurrence

Assumptions: caller supplies current IANA identifier; shell initializes timezone database. Files: recurrence_calculator.dart, barrel, package pubspec, recurrence_calculator_test.dart and this evidence. timezone 0.11.1 already locked; no semantic lockfile dependency change. Red focused exit 1 missing calculator; green 9 focused tests, full dart test 248 passed (239+9), analyze No issues found. No tests weakened/deleted/skipped; no SPEC_DEVIATION. Calendar iteration uses local dates; fold chooses earliest UTC copy before comparing now; gap chooses forward transition shift. API checked against official timezone documentation (https://pub.dev/documentation/timezone/latest/timezone/TZDateTime-class.html) and installed compiler types.

Evidence path: packages/popmundo_utils/test/recurrence_calculator_test.dart.

| Criterion A | Exact file:line + assertion | Spec outcome | Covered |
| --- | --- | --- | --- |
| SCHED-04/06 anchor/strict future | :22 expect(next(interval,anchor),DateTime.utc(2026,10,4,12,0,10)); :23 expect(next(interval,anchor.add(const Duration(seconds:10))),DateTime.utc(2026,10,4,12,0,20)); :27 expect(next(interval,anchor.add(const Duration(seconds:35))),DateTime.utc(2026,10,4,12,0,40)); :31 expect(next(interval,anchor.subtract(const Duration(seconds:1))),DateTime.utc(2026,10,4,12,0,10)) | :10/:20/restart :40; positive n only | Yes |
| Elapsed day | :43 expect(next(day,day.anchorUtc,'America/New_York'),DateTime.utc(2026,3,8,14)) | 24 hours through DST | Yes |
| Multiple weekdays/exact boundary | :50 expect(next(weekly,DateTime.utc(2026,10,5,8,59)),DateTime.utc(2026,10,5,9)); :54 expect(next(weekly,DateTime.utc(2026,10,5,9)),DateTime.utc(2026,10,8,9)); :58 expect(next(weekly,DateTime.utc(2026,10,8,9)),DateTime.utc(2026,10,12,9)) | Monday then Thursday then Monday strictly after | Yes |
| Gap | :66 expect(due,DateTime.utc(2026,3,8,7,30)); :67 expect(calculator.localSlot(weekly,due,zoneId:'America/New_York'),'2026-03-08T02:30'); :71 expect(next(weekly,due,'America/New_York'),DateTime.utc(2026,3,15,6,30)) | 02:30 shifts 03:30; intended slot remembered; next local week | Yes |
| Fold | :78 expect(next(weekly,DateTime.utc(2026,11,1,4),'America/New_York'),DateTime.utc(2026,11,1,5,30)); :82 expect(next(weekly,DateTime.utc(2026,11,1,5,30),'America/New_York'),DateTime.utc(2026,11,8,6,30)); :86 expect(next(weekly,DateTime.utc(2026,11,1,6),'America/New_York'),DateTime.utc(2026,11,8,6,30)) | First copy only; no repeated local slot even between fold copies | Yes |
| Zone/year | :94 expect(next(weekly,now,'America/Sao_Paulo'),DateTime.utc(2026,10,5,12)); :98 expect(next(weekly,now,'Asia/Tokyo'),DateTime.utc(2026,10,12)); :99 expect(next(WeeklyRecurrence(weekdays:{5},hour:0,minute:10),DateTime.utc(2026,12,31,23,59)),DateTime.utc(2027,1,1,0,10)) | Current zone changes future UTC; year date crossing | Yes |
| Interval tolerance | :109 expect(calculator.isEligible(interval,due,due.subtract(const Duration(microseconds:1))),false); :117 expect(calculator.isEligible(interval,due,due),true); :118 expect(calculator.isEligible(interval,due,due.add(const Duration(seconds:10))),true); :126 expect(calculator.isEligible(interval,due,due.add(const Duration(seconds:10,microseconds:1))),false); :135 minute 30s=true; :139 minute 30s+1us=false | Inclusive min(30s,D), never early | Yes |
| Weekly tolerance | :150 expect(calculator.isEligible(weekly,anchor,anchor.add(const Duration(seconds:30))),true); :158 expect(calculator.isEligible(weekly,anchor,anchor.add(const Duration(seconds:30,microseconds:1))),false) | Inclusive 30 seconds | Yes |
| Unknown zone | :168 expect(() => next(WeeklyRecurrence(weekdays:{1},hour:9,minute:0),anchor,'Unknown/Zone'),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','zoneUnavailable'))); :182 expect(next(interval,anchor,'Unknown/Zone'),DateTime.utc(2026,10,4,12,0,10)) | Weekly unavailable, interval independent | Yes |

| Assertion group C reverse map | Maps to | Keep |
| --- | --- | --- |
| :22/23/27/31 UTC anchor | SCHED-04/06 | Yes |
| :43 elapsed day | SCHED-04 | Yes |
| :50/54/58 weekdays | SCHED-05 | Yes |
| :66/67/71 gap and slot | SCHED-05 | Yes |
| :78/82/86 fold | SCHED-05/06 | Yes |
| :94/98/99 zone/year | SCHED-05 | Yes |
| :109/117/118/126/135/139 tolerance | SCHED-06 | Yes |
| :150/158 weekly tolerance | SCHED-06 | Yes |
| :168/182 unknown zone | Approved design Calendar handling, SCHED-05 | Yes |

A/B/C/D PASS: exact UTC and intended-slot values, every listed T2 case, no speculative tests; project pure-Dart conventions followed.

## T3 — serialized durable coordinator

Assumptions: one runtime engine owns SchedulerStore; fresh reads; writes throw if unconfirmed. Executor registry localNotification; completion denotes submission, never user visibility. now()/zoneId() are cached synchronous adapter values; invalid zone string preserves weekly failure with no due while intervals continue. No game/network/JS/Flutter. Files: coordinator, command part, store/action ports, barrel, rule cursor extension, coordinator tests and this evidence.

SCHED-10 refinement approved by root: optional lastAttemptUtc is a durable attempted-slot watermark, independent of pending claim. Retained on startup/text edit/pause, cleared on recurrence edit/re-enable; schema-1 lastClaim.plannedUtc migrates before interrupted claim removal. Backward-clock tests observed red (actual :10, required :20); watermark fixes replay. Null watermark omitted from JSON, so original T1 literal roundtrip stays exact. No product SPEC_DEVIATION.

Red: dart test test/scheduler_coordinator_test.dart exit 1 missing ports/coordinator. Green focused 25 cases; full dart test --reporter expanded 273 passed (248 prior+25), zero failed. dart analyze No issues found, exit 0. git diff --check exit 0. No assertions weakened, tests deleted or skipped. Error-category names are the public contract for spec failure states. Guidelines: CLAUDE.md/popmundo-utils; deterministic clock/no real network. Production files focused: coordinator ~225, commands~110, ports17.

Evidence base: packages/popmundo_utils/test/scheduler_coordinator_test.dart. Lines cite assertion starts, including multiline assertions. anchor=2026-10-04T12:00Z. Separate payload-value assertions accompany count/no-retry assertions.

| Criterion A | Exact file:line + assertion expression | Expected outcome | Covered |
| --- | --- | --- | --- |
| Authoritative create/list and identity | :84 expect(snapshot.toJson(),saved().toJson()); :86 expect([rule.id,rule.revision,rule.notificationId,rule.name,rule.enabled],['one',1,-1,'Reminder',true]); :90 expect(rule.action.toJson(),{'type':'localNotification','title':'Title','body':'Message'}); :95 expect(rule.nextDueUtc,anchor.add(const Duration(seconds:10))); :96 expect(rule.lastResult.status,ScheduleResultStatus.neverExecuted); :97 expect(snapshot.nextSequence,2); :98 expect((await coordinator.list()).toJson(),saved().toJson()) | Exact persisted fields before acknowledgement | Yes |
| Restart exact/past slots | :106 expect(executor.payloads,isEmpty); :107 expect(restored.rules.single.nextDueUtc,anchor.add(const Duration(seconds:40))); :111 expect(saved().rules.single.nextDueUtc,anchor.add(const Duration(seconds:40))); :116 expect((await fresh().load()).rules.single.nextDueUtc,anchor.add(const Duration(seconds:50))); :120 expect(executor.payloads,isEmpty) | Restart :35 arms :40; exact :40 restart arms :50; no notifications | Yes |
| Cadence/stable action payload | :131 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'},{'id':-1,'title':'Title','body':'Message'}]); :135 expect(snapshot.rules.single.nextDueUtc,anchor.add(const Duration(seconds:30))); :139 expect(snapshot.rules.single.lastClaim!.plannedUtc,anchor.add(const Duration(seconds:20))); :143 expect(snapshot.rules.single.lastResult.status,ScheduleResultStatus.submitted); :147 expect(snapshot.rules.single.lastResult.atUtc,now); :148 expect(snapshot.rules.single.lastResult.errorCode,isNull) | :10/:20 same saved card; next :30; result fields exact | Yes |
| Active skip/tolerance | :156 expect((await coordinator.reconcile()).rules.single.nextDueUtc,anchor.add(const Duration(seconds:30))); :160 expect(executor.payloads,isEmpty); :162 expect((await coordinator.reconcile()).rules.single.nextDueUtc,anchor.add(const Duration(seconds:50))); :166 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'}]) | Beyond bound skips; inclusive bound executes only one armed slot | Yes |
| Text vs cadence edit | :181 expect([edited.id,edited.notificationId,edited.revision,edited.name,edited.action.title],['one',-1,2,'Edited','New']); :191 expect((edited.recurrence as IntervalRecurrence).anchorUtc,anchor); :192 expect(edited.nextDueUtc,anchor.add(const Duration(seconds:10))); :204 expect((changed.recurrence as IntervalRecurrence).anchorUtc,now); :205 expect(changed.nextDueUtc,anchor.add(const Duration(seconds:25))); :206 expect(changed.notificationId,-1) | Text preserves; quantity20 edit at :05 resets due :25, stable ID | Yes |
| Pause/enable | :217 expect(paused.enabled,false); :218 expect(paused.nextDueUtc,isNull); :221 expect(executor.payloads,isEmpty); :227 expect(enabled.nextDueUtc,anchor.add(const Duration(seconds:20))); :228 expect((enabled.recurrence as IntervalRecurrence).anchorUtc,now); :229 expect(enabled.notificationId,-1) | No paused execution; new anchor on enable | Yes |
| Identity/revision guards | :241 expectLater(operation(),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','revisionConflict'))); :252 expectLater(coordinator.delete('absent',expectedRevision:1),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','ruleNotFound'))); :262 expectLater(coordinator.create(draft(),id:'one'),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','duplicateId'))); :272 expect(store.raw,before) | Stale update/toggle/delete rejected; absent/duplicate ID rejected; no mutation | Yes |
| Deletion/no recycling | :278 expect(saved().rules,isEmpty); :279 expect(saved().nextSequence,2); :281 expect(snapshot.rules.single.notificationId,-2); :282 expect(snapshot.nextSequence,3) | Delete then fresh writer allocates -2 | Yes |
| Failed command write | :289 expectLater(coordinator.create(draft(),id:'one'),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','writeFailed'))); :299 expect(store.raw,isNull); :300 expect(executor.payloads,isEmpty); :302 expect((await coordinator.list()).rules,isEmpty) | No acknowledgement/state/action | Yes |
| Failed claim write | :309 expectLater(coordinator.reconcile(),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','writeFailed'))); :315 expect(executor.payloads,isEmpty); :316 expect(saved().rules.single.lastClaim,isNull); :318 expect((await coordinator.reconcile()).rules.single.nextDueUtc,anchor.add(const Duration(seconds:20))); :322 expect(executor.payloads,isEmpty) | No submission; reload skips due | Yes |
| Durable pre-action claim | :329 expect(rule.lastClaim!.revision,1); :330 expect(rule.lastClaim!.plannedUtc,now); :331 expect(rule.nextDueUtc,anchor.add(const Duration(seconds:20))); :334 expect(saved().rules.single.lastResult.status,ScheduleResultStatus.submitted) | Claim/next due visible in store inside executor | Yes |
| Failed action continues catalog | :349 expect(snapshot.rules[0].lastResult.status,ScheduleResultStatus.failed); :350 expect(snapshot.rules[0].lastResult.errorCode,'permissionDenied'); :351 expect(snapshot.rules[1].lastResult.status,ScheduleResultStatus.submitted); :355 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'},{'id':-2,'title':'Second','body':'Message'}]); :360 expect(executor.payloads.length,2); :361 expect(snapshot.rules.map((r)=>r.nextDueUtc),[anchor.add(const Duration(seconds:20)),anchor.add(const Duration(seconds:20))]) | First fails; distinct second succeeds; no immediate retry | Yes |
| Bounded timeout | :375 expect(rule.lastResult.status,ScheduleResultStatus.failed); :376 expect(rule.lastResult.errorCode,'actionTimeout'); :377 expect(elapsed.elapsed,greaterThanOrEqualTo(const Duration(seconds:5))); :378 expect(elapsed.elapsed,lessThan(const Duration(seconds:7))); :380 expect(executor.payloads.length,1); :381 expect(rule.nextDueUtc,anchor.add(const Duration(seconds:20))) | Fixed five-second timeout, 7s testing margin, no retry | Yes |
| Result-write uncertainty | :390 expectLater(coordinator.reconcile(),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','resultUncertain'))); :400 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'}]); :404 expect(restored.lastResult.status,ScheduleResultStatus.skippedInterrupted); :408 expect(restored.lastClaim,isNull); :409 expect(restored.nextDueUtc,anchor.add(const Duration(seconds:20))); :411 expect(executor.payloads.length,1) | Uncertain report, pending claim dropped after load, no retry | Yes |
| Overlapping commands/ticks | :427 expect(executor.payloads.length,2); :429 expect(rules.map((r)=>[r.id,r.name,r.notificationId,r.revision]),[['one','Edited',-1,2],['two','Reminder',-2,1]]); :433 expect(rules.map((r)=>r.nextDueUtc),[anchor.add(const Duration(seconds:20)),anchor.add(const Duration(seconds:20))]) | No lost rules/edit/revision; each slot once | Yes |
| Stale queued candidates | :462 expect(executor.payloads,isEmpty); :463 expect(saved().rules.map((r)=>[r.id,r.enabled,r.nextDueUtc]),[['pause',false,null],['edit',true,anchor.add(const Duration(seconds:30))]]) | Completed disable/delete/edit prevents old claim | Yes |
| Current/unavailable zone | :479 expect(snapshot.rules[0].nextDueUtc,now.add(const Duration(seconds:10))); :480 expect(snapshot.rules[1].enabled,true); :481 expect(snapshot.rules[1].nextDueUtc,isNull); :482 expect(snapshot.rules[1].lastResult.errorCode,'zoneUnavailable'); :486 expect(changed.rules[1].nextDueUtc,DateTime.utc(2026,10,5,12)); :488 expect((await coordinator.reconcile()).rules[1].nextDueUtc,DateTime.utc(2026,10,12)); :494 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'}]) | Interval continues; weekly visible failure then future rearm on zone change | Yes |
| Corrupt preservation | :503 expectLater(coordinator.load(),throwsA(isA<SchedulerException>())); :504 expectLater(coordinator.create(draft(),id:'one'),throwsA(isA<SchedulerException>())); :508 expectLater(coordinator.reconcile(),throwsA(isA<SchedulerException>())); :512 expect(store.raw,raw); :513 expect(store.writes,0); :514 expect(executor.payloads,isEmpty) | Blob untouched/unavailable; zero actions | Yes |
| Uncertain command nonce | :520 expectLater(coordinator.create(draft(),id:'nonce'),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','writeFailed'))); :526 expect(saved().rules.single.id,'nonce'); :528 expect((await coordinator.list()).rules.single.notificationId,-1); :529 expectLater(coordinator.create(draft(),id:'nonce'),throwsA(isA<SchedulerException>().having((e)=>e.code,'code','duplicateId'))); :535 expect(saved().nextSequence,2); :536 expect(saved().rules.length,1) | Commit-before-throw refreshed; caller nonce prevents duplicate allocation | Yes |
| Already claimed action before pause | :559 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'}]); :562 expect(saved().rules.single.lastResult.status,ScheduleResultStatus.submitted); :566 expect(saved().rules.single.enabled,false); :567 expect(saved().rules.single.nextDueUtc,isNull); :570 expect(executor.payloads.length,1) | In-flight action allowed to finish; no later claim | Yes |
| Weekly fold cursor | :584 expect(rule.lastClaim!.localSlot,'2026-11-01T01:30'); :585 expect(rule.lastClaim!.plannedUtc,DateTime.utc(2026,11,1,5,30)); :586 expect(rule.nextDueUtc,DateTime.utc(2026,11,8,6,30)); :589 expect(restored.lastResult.status,ScheduleResultStatus.submitted); :590 expect(restored.lastClaim!.localSlot,'2026-11-01T01:30'); :591 expect(restored.nextDueUtc,DateTime.utc(2026,11,8,6,30)); :592 expect(executor.payloads,[{'id':-1,'title':'Title','body':'Message'}]) | First fold once; completed latest retained; next week after restart | Yes |
| Interrupted before action | :613 expect(restored.lastResult.status,ScheduleResultStatus.skippedInterrupted); :617 expect(restored.lastResult.atUtc,now); :618 expect(restored.lastResult.errorCode,isNull); :619 expect(restored.lastClaim,isNull); :620 expect(restored.nextDueUtc,anchor.add(const Duration(seconds:20))); :621 expect(executor.payloads,isEmpty) | Dropped pending claim, exact result/time/error and future due, no recovery | Yes |
| Backward clock completed claim | :632 expect((await coordinator.load()).rules.single.nextDueUtc,anchor.add(const Duration(seconds:20))); :638 expect(executor.payloads.length,1); :641 expect(executor.payloads.length,2); :642 expect(saved().rules.single.lastClaim!.plannedUtc,anchor.add(const Duration(seconds:20))) | :10 never repeated; next distinct :20 permitted | Yes |
| Backward clock interrupted claim | :669 expect(snapshot.rules.single.nextDueUtc,anchor.add(const Duration(seconds:20))); :673 expect(snapshot.rules.single.lastResult.status,ScheduleResultStatus.skippedInterrupted); :677 expect(executor.payloads,isEmpty) | Future interrupted claim still never retried | Yes |
| Durable watermark | :684 expect(saved().rules.single.lastAttemptUtc,DateTime.utc(2026,10,4,12,0,10)); :688 expect(saved().rules.single.toJson()['lastAttemptUtc'],'2026-10-04T12:00:10.000Z'); :693 expect(saved().rules.single.lastAttemptUtc,DateTime.utc(2026,10,4,12,0,10)); :708 expect(saved().rules.single.lastAttemptUtc,isNull); :709 expect(saved().rules.single.lastClaim,isNull); :713 expect(saved().rules.single.lastAttemptUtc,DateTime.utc(2026,10,4,12,0,30)); :718 expect(saved().rules.single.lastAttemptUtc,isNull); :719 expect(saved().rules.single.nextDueUtc,anchor.add(const Duration(seconds:50))); :739 expect(restored.lastClaim,isNull); :740 expect(restored.lastAttemptUtc,DateTime.utc(2026,10,4,12,0,50)); :741 expect(saved().rules.single.lastAttemptUtc,DateTime.utc(2026,10,4,12,0,50)); :745 expect((await fresh().load()).rules.single.nextDueUtc,DateTime.utc(2026,10,4,12,1,10)) | Serialized timestamp; text/pause retains; recurrence/re-enable resets; migrated legacy marker survives second restart | Yes |

| C reverse map (every test assertion group above) | Requirement | Keep |
| --- | --- | --- |
| :84/86/90/95/96/97/98 | SCHED-03/07 authoritative create/list | Yes |
| :106/107/111/116/120 | SCHED-06 restart | Yes |
| :131/135/139/143/147/148 | SCHED-04/07 cadence/payload | Yes |
| :156/160/162/166 | SCHED-06 tolerance | Yes |
| :181/191/192/204/205/206 | SCHED-03 edit | Yes |
| :217/218/221/227/228/229 | SCHED-03 toggle | Yes |
| :241/252/262/272 | SCHED-10 guards | Yes |
| :278/279/281/282 | SCHED-07 sequence deletion | Yes |
| :289/299/300/302 | SCHED-09 command write | Yes |
| :309/315/316/318/322 | SCHED-09 claim write | Yes |
| :329/330/331/334 | SCHED-10 persistent claim | Yes |
| :349/350/351/355/360/361 | SCHED-09 action failure | Yes |
| :375/376/377/378/380/381 | SCHED-09 timeout | Yes |
| :390/400/404/408/409/411 | SCHED-09 uncertain result | Yes |
| :427/429/433 | SCHED-10 overlap | Yes |
| :462/463 | SCHED-03/10 stale candidate | Yes |
| :479/480/481/482/486/488/494 | SCHED-05 approved Calendar handling | Yes |
| :503/504/508/512/513/514 | SCHED-09 corrupt | Yes |
| :520/526/528/529/535/536 | SCHED-03/09/10 uncertain save identity | Yes |
| :559/562/566/567/570 | SCHED-03 already claimed | Yes |
| :584/585/586/589/590/591/592 | SCHED-05/06 fold | Yes |
| :613/617/618/619/620/621 | SCHED-09 interrupted | Yes |
| :632/638/641/642 | SCHED-10 backward clock | Yes |
| :669/673/677 | SCHED-09/10 backward interrupted | Yes |
| :684/688/693/708/709/713/718/719/739/740/741/745 | SCHED-03/09/10 watermark durability | Yes |

A/B/C/D PASS: scoped ACs/edges exact; payload/result fields separately inspected, assertions inside executor prove claim order; persisted entire catalog discriminates lost updates. No assertion-free/shallow/unanchored tests. Independent final verifier belongs to root T7; T3 completion is only pure-core phase.
