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
