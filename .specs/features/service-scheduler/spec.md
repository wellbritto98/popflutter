# Service Scheduler — Specification

Status: Approved by user on 2026-10-04
Scope: Large, multi-component Android feature
Context: context.md

## Problem and goals

The native sidebar currently has no way to execute recurring services. The user needs persistent rules that execute without the game screen and resume after Android reboots. The first supported service is a local notification.

Success means creating, editing, pausing and deleting rules through the sidebar; executing intervals and weekly rules in background; restoring the next future occurrence after reboot; and observing truthful execution status.

## P1 stories and acceptance criteria

### Manage recurring services

SCHED-01 — WHEN the user opens the sidebar on Android, THEN an Agendamentos / Schedules entry SHALL open a native list in debug and release. The list SHALL show an empty state or each rule's name, recurrence, enabled state, next occurrence and latest execution result. All release UI strings SHALL have EN/PT translations. On iOS the entry SHALL explain that this MVP requires Android and SHALL not offer unsupported scheduling.

SCHED-02 — WHEN creating or editing a rule, THEN the form SHALL accept a trimmed name of 1–80 characters, title of 1–120 characters, message of 1–1000 characters, and exactly one recurrence. Interval quantity SHALL be an integer 1–9999 in seconds/minutes/hours/days. Weekly recurrence SHALL require at least one ISO weekday and a valid local HH:mm. Invalid input SHALL show a field error and SHALL not mutate saved state. Default interval SHALL be one minute.

SCHED-03 — WHEN a save, toggle or delete succeeds, THEN the authoritative persisted state SHALL reflect it before the UI reports success. Canceling an editor SHALL leave saved state unchanged. Deletion SHALL require confirmation. Pausing or deletion SHALL prevent any subsequently claimed occurrence; an action already claimed before that command may complete. Editing text alone SHALL preserve cadence and identity. Editing recurrence or re-enabling SHALL establish a new future occurrence. A failed or timed-out save SHALL retain the form, report the uncertainty/error and refresh authoritative state before another submission.

Independent test: use the native page with a fake transport; save a rule, edit text, toggle it, cancel deletion, confirm deletion and reload the catalog.

### Execute intervals and weekly rules

SCHED-04 — WHEN an interval rule is enabled at UTC instant A, THEN its planned occurrences SHALL be A + nD for positive integers n, where D is the selected elapsed duration. The first occurrence SHALL be A + D. One day SHALL mean 24 elapsed hours. Cadence SHALL not drift by using action completion time as its anchor.

SCHED-05 — WHEN a weekly rule is enabled, THEN its next occurrence SHALL be the first selected weekday/time strictly after now in the current device IANA time zone. Multiple selected weekdays SHALL each recur. A change in device time zone SHALL recompute future weekly occurrences on the next runtime reconciliation, within the existing five-second heartbeat while the engine runs. A daylight-saving gap SHALL shift the selected time forward by the gap; an ambiguous repeated time SHALL choose the first occurrence and SHALL not execute the repeated local slot twice. Calendar iteration SHALL use local dates, not elapsed 24-hour additions.

SCHED-06 — WHEN the runner starts or restarts, including after reboot, THEN all occurrences at or before now SHALL be skipped and the next strictly future occurrence SHALL be armed, without notifications for the skipped slots. During uninterrupted operation only the currently armed slot may execute, and only when late by at most min(30 seconds, interval duration) for intervals or 30 seconds for weekly rules. A callback older than that bound SHALL skip the overdue slots and arm the next strictly future slot. Each evaluation SHALL execute at most one occurrence per rule; it SHALL never loop through missed slots. Exact real-time delivery is not guaranteed by Android.

SCHED-07 — WHEN an eligible occurrence is claimed, THEN the action SHALL request a local notification with the saved title/message and a stable negative signed 32-bit ID unique to that rule. Later occurrences SHALL update the same card. Separate rules SHALL have distinct IDs, and SHALL not collide with existing positive notification IDs. IDs SHALL survive editing/restart and SHALL never be recycled after deletion. Notification settings controlled by the user may suppress sound or presentation; successful platform submission SHALL not be labeled as proof the user saw it.

Independent test: deterministic clock cases include a 10-second rule enabled at 12:00:00, firing at :10 and :20; a restart at :35 producing no notification and next occurrence :40; and Monday/Thursday 09:00 selecting Thursday after Monday 09:00 has passed.

### Remain available in Android background

SCHED-08 — WHEN Android goes Home, the screen locks or the task is removed from Recents, THEN the scheduler SHALL execute through the foreground service without constructing or calling a WebView. WHEN Android reboots with at least one enabled saved rule, THEN the service SHALL restore scheduling from durable storage with SCHED-06's skip policy. Boot/package-replacement auto-start SHALL be enabled only while enabled rules exist. Pausing/deleting the last rule SHALL disable scheduler auto-start and SHALL preserve the existing session keepalive behavior. Android force-stop is an OS exception: execution resumes only after user interaction permits the app to run again. The screen SHALL explain the required notification/background permissions and their current status.

SCHED-09 — WHEN permission to post notifications is denied during enable/save, THEN activation SHALL fail with an actionable message and the editor SHALL retain its inputs. WHEN permission is revoked or a platform action fails at runtime, THEN that occurrence SHALL record failure, the runner SHALL continue with other rules, and SHALL schedule the next future occurrence without an immediate retry. Platform action waits SHALL be bounded to five seconds; any uncertain/timed-out action SHALL not be retried for the same occurrence. Startup SHALL drop interrupted claims, consistent with skipping missed work. A failed claim write SHALL prevent submission of that action. A failed command write SHALL prevent a success acknowledgement. A failed result write after submission SHALL be reported as uncertain and SHALL not cause resubmission. Corrupt/unknown-version storage SHALL be preserved, reported as unavailable and SHALL not be silently erased or executed.

SCHED-10 — WHEN commands, ticks, edits or deletion overlap, THEN one serialized writer SHALL preserve the entire catalog and SHALL claim each occurrence at most once before calling its action. Commands SHALL validate identity/revision and reject stale updates. A stale queued candidate SHALL not execute after a completed disable/delete or recurrence edit. The UI SHALL not independently write the runner's snapshot. No credential, game HTTP, JS evaluation or login operation SHALL be part of this MVP. Adding a later action type SHALL use a registered executor contract; no additional service is implemented now.

Independent test: real Android isolated test app verifies local notification delivery after Home/task removal and persistence plus next-future delivery after an actual ADB reboot. Unit tests exercise overlapping mutation/tick requests, failed writes and interrupted claims.

## Out of scope

| Capability | Reason |
| --- | --- |
| Other services, game automation, login scheduling, action chains or conditions | MVP has one local notification action per rule |
| iOS continuous execution and reboot restoration | Current platform cannot provide the same seconds-based continuous lifecycle |
| Force-stop bypass or guaranteed delivery to the second | Android owns process and notification policy |
| Missed-occurrence recovery, retry bursts or historical analytics | User explicitly selected skip policy; latest result is sufficient |
| Exact-alarm permission, imports, cloud sync and time-zone picker | Not needed for the selected foreground-service approach |

## Assumptions and closure

Confirmed decisions and proposed defaults are separated in context.md. All defaults above were approved by the user on 2026-10-04, including Android-only scope, units/bounds, notification-card replacement, timing tolerance and daylight-saving behavior. No unresolved question is silently assigned a behavior.

| Implicit requirement dimension | Resolution |
| --- | --- |
| Input validation/bounds | SCHED-02 |
| Failure/partial failure | SCHED-03, SCHED-09 |
| Idempotency/retry/duplicates | SCHED-06, SCHED-07, SCHED-09, SCHED-10 |
| Auth boundaries/rate limits | No game auth/network; local permission in SCHED-09, one action per current slot in SCHED-06 |
| Concurrency/ordering | SCHED-03, SCHED-10 |
| Data lifecycle | Durable until deletion; no ID recycling, SCHED-03/07/08 |
| Observability | Latest result, next execution and permission status, SCHED-01/08/09 |
| External dependency failure | Android notification/storage failure, SCHED-09 |
| State-transition integrity | Save/enable/edit/disable/delete, SCHED-03/09/10 |

## Traceability and verification

All ten requirements are In Design; none is implemented yet. Tasks will map every requirement after design approval. Domain tests SHALL assert exact clocks, calendar dates, IDs and persisted outcomes. Widget tests SHALL cover forms/list and EN/PT. Device tests SHALL use the isolated non-game harness and actual Android notifications/service/storage. An independent verifier SHALL map evidence to each criterion and demonstrate that behavior mutations are detected. Existing session tests SHALL remain green.
