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
