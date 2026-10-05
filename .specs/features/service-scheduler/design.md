# Service Scheduler — Design

Spec: spec.md
Context: context.md
Status: Approved by user on 2026-10-04.

## Approaches considered

| Approach | Benefits | Trade-offs |
| --- | --- | --- |
| Recommended: reuse the existing Android foreground service, with a pure-Dart coordinator in its isolate | Supports seconds, shares the existing persistent service, keeps recurrence testable and avoids game/UI dependencies | Continuous service notification and battery cost; Android delivery is best effort |
| Native Kotlin scheduler inside a foreground service | Same scope; direct Android lifecycle and notification APIs | More platform code, duplicated calendar/domain logic and more complex Flutter command bridge |
| Hybrid native alarms for calendar rules plus foreground service for short intervals | Calendar rules can wake without a continuously running scheduler | Two execution paths, duplicate-claim coordination and additional alarm/permission handling; seconds still need a service |

The recommendation minimizes the new platform surface while satisfying the same requested scope. WorkManager/native periodic notification APIs alone do not meet seconds-based continuous execution and are not proposed as equivalent alternatives.

## Constraints and reuse

- AD-002: models, recurrence calculation, serialization and orchestration stay in popmundo_utils, without Flutter.
- AD-009/014: add the sidebar item through buildAppMenuItems; use existing native theme and EN/PT assets.
- AD-013/020: preserve stopWithTask false, specialUse, wake lock, existing keepalive and result notifications.
- AD-015: device fixtures never construct PopmundoApp or reach the live game.
- Approved AD-021 amends AD-012/019/020's heartbeat-only FGS restriction to permit generic local-service scheduling, while keeping game HTTP, WebView, login and JS outside that isolate. Enable boot restoration for enabled rules; session auto-login restoration after reboot is not part of this feature.

Reuse KeepaliveTaskHandler, FlutterForegroundTaskPlatform and LocalNotificationsService through narrow adapters. SharedPreferencesStore's cached instance cannot be used independently by both isolates as writers.

## Components and contracts

| Component | Location | Responsibility and interface |
| --- | --- | --- |
| ScheduledRule / ScheduleRecurrence / SchedulerSnapshot | packages/popmundo_utils/lib/src/scheduler/ | Immutable validated data, versioned JSON; no plugins |
| RecurrenceCalculator | Same pure-Dart module | nextAfter(now), current armed-slot eligibility, interval anchor and local calendar arithmetic |
| SchedulerCoordinator | Same pure-Dart module | Serialized load/list/create/update/toggle/delete/reconcile; sole snapshot writer; claims before action execution |
| ScheduledActionExecutor port | Same pure-Dart module | Execute a typed action with stable notification ID; first registered action is localNotification |
| PreferencesSchedulerStore adapter | apps/popmundo_app/lib/scheduler/ | Persist one JSON string through a reload-aware SharedPreferences/plugin adapter in the FGS engine |
| SchedulerRunner | apps/popmundo_app/lib/scheduler/ | Initialize the complete IANA database and plugins, load coordinator, arm one nearest-occurrence Timer, reconcile at existing heartbeat, cancel timer on destroy |
| Scheduler client | apps/popmundo_app/lib/scheduler/ | Request/response IPC with request ID, revision and bounded UI waits after a task-heartbeat readiness check; list refreshed from FGS authority |
| Scheduler page/editor | apps/popmundo_app/lib/scheduler/ | Existing-themed list, FAB, form, enable switch, deletion dialog, permission/status presentation |

TaskHandler remains the platform entrypoint and delegates scheduler work. No scheduler module imports the WebView adapter. The five-second native heartbeat remains intact. A single Dart Timer arms the nearest future due time, permitting seconds without adding permanent one-second native polling. Heartbeats reconcile clock/timezone changes and recover overdue timers. The real Android gate must prove this timer continues in the FGS engine with Home/task removal.

## Persisted model

Storage key: service_scheduler.v1. Snapshot contains schemaVersion, nextSequence and the rule list with execution cursors. A rule contains stable id, revision, name, enabled, typed recurrence, localNotification title/body, notificationId, nextDueUtc, lastClaim, lastAttemptUtc and lastResult.

- Notification ID is the negative of a monotonically increasing sequence in 1..2147483648. Never recycle it; fail allocation explicitly if exhausted. Existing debug/login/GM/FGS IDs remain positive.
- Interval recurrence stores quantity, unit and anchorUtc. Weekly recurrence stores ISO weekday set and local hour/minute; the active zone is read from the device.
- Claim identifies rule/revision/planned UTC instant. Weekly execution also remembers the local date/time slot to distinguish the two copies of a DST repeated hour.
- lastAttemptUtc is a durable planned-UTC watermark set before submission; startup retains it even when dropping an interrupted claim. Text edits keep it; recurrence edits and re-enabling clear it. Calendar search uses max(now, watermark), preventing duplicate slots after a clock rollback. Schema version 1 omits this optional field when absent and migrates older claims on load.
- Latest result is never-executed, submitted, failed or skipped-interrupted, with timestamp and non-secret error category. submitted means the platform accepted the request, not that a person saw the notification.
- Disabled rules persist without an armed due time. Deletion removes the rule/cursor, preserving the sequence counter.
- An unknown/corrupt snapshot is preserved and fails closed. No silent reset or accidental execution of partially decoded rules.

## Scheduling and data flow

1. Main UI bootstraps the existing service and asks for an authoritative catalog. Permission requests run in the Activity, never in the background engine.
2. The UI sends validated commands through sendDataToTask. The handler replies through sendDataToMain; heartbeat listeners distinguish message types. Saving is acknowledged only after durable state and required runtime/boot configuration updates complete.
3. A serialized coordinator validates expected revisions, computes next occurrence, persists the whole snapshot, then publishes the refreshed view. The main isolate never saves scheduler data directly.
4. Timer callbacks enter the same queue. After verifying enabled/revision and the bounded lateness rule, the coordinator persists a claim and the next strictly future due time before submitting a notification.
5. Notification submission has a five-second bound. Its result is stored; failure cannot block other rules or trigger same-occurrence retries. The next future timer is armed regardless of success.
6. Every restart skips overdue slots and drops interrupted claims. Boot flags are reconciled from the enabled catalog, with autoRunOnBoot and autoRunOnMyPackageReplaced set accordingly. The existing session keepalive is not stopped when the last rule is paused/deleted.

A persistence write and an Android notification cannot form one transaction. The chosen guarantee is at-most-once attempt, allowing a lost notification if the process dies after claiming it. This matches the user's skip policy and avoids duplicate/recovered work. A timeout may mean Android already accepted the action; it is recorded as uncertain failure and never immediately retried.

## Calendar handling

Declare timezone as a direct pure-Dart dependency and initialize its complete IANA database (timezone/data/latest_all.dart) in the shell, including native aliases such as GMT and UTC. Detect the current device IANA identifier with flutter_timezone; do not silently assume UTC. The native lookup has a one-second bound and caches the last validated identifier. A transient lookup failure retains that known zone; if none has been resolved, weekly scheduling is visibly unavailable while interval rules can continue.

Calendar search considers selected local dates, resolves each wall-clock time, then selects the earliest UTC candidate strictly after now. DST gap resolution shifts by the transition gap. Repeated-hour resolution selects the first UTC instant before future filtering, so an already-past first copy does not select the second copy. The durable planned-instant cursor also prevents replay after clock rollback. Unit tests specify New York spring 02:30 -> 03:30 and autumn 01:30 -> first 01:30, plus a non-DST zone and year boundaries. Device time-zone changes trigger future-slot recalculation at runtime reconciliation.

## UI and errors

The list shows name, recurrence summary, next execution and latest result, plus enabled switch, edit and delete. The editor uses interval/day-of-week selection; weekday chips and a time picker; title/message fields; a visible Local notification action. Save is disabled while a command is pending. The visible list refreshes authoritative state every five seconds with coalesced reads, suspending those reads while inactive or editing and canceling the timer on disposal. A timeout retains the editor and triggers a catalog refresh before a further submission; it never blindly creates a duplicate rule.

Notification/background status is actionable through the existing permission flow. Permission denial during enable/save retains the form and does not activate the rule. Runtime failures remain visible in latest-result status. A failed boot-configuration update is not reported as successful restoration; show failure, refresh persisted state and reconcile on subsequent requests/startup. No destructive rollback is attempted after an uncertain write.

## Risks & Concerns

| Concern | Current location | Impact | Mitigation |
| --- | --- | --- | --- |
| Cached prefs across engines | apps/popmundo_app/lib/prefs_store.dart | Lost catalog updates/stale reads | Reload-aware adapter and one FGS writer |
| Silent notification init failure/no-op | apps/popmundo_app/lib/notifications/local_notifications_service.dart | False success status | Scheduler action adapter returns truthful initialization/permission/submission failure |
| Heartbeat-only architectural contract | .specs/STATE.md AD-012/019/020 | Undocumented responsibility expansion | Approved AD-021; local services only |
| Secondary-engine plugin registration | apps/popmundo_app/lib/background/keepalive_task_handler.dart | MissingPluginException, service runs but no notification | Initialize plugins in entrypoint and prove actual background tray behavior |
| Process death between persistence and OS action | New coordinator/executor boundary | Lost or duplicate notifications | Persist claim first; at-most-once attempt; skip interrupted slot |
| Clock/DST changes and date arithmetic | New recurrence calculator | Wrong weekday, double firing | IANA local-date calculations and exact outcome tests |
| Android force-stop/platform limits | Foreground-service lifecycle | No execution after explicit force-stop; delivery jitter | Truthful status/UI and tests for supported Home/Recents/reboot lifecycle |
| Boot flag/catalog update not one transaction | ForegroundTaskOptions + scheduler prefs | Saved rule without restoration configuration | Reconcile flags before success acknowledgement and on startup; surface failure |
| Device test process dies during reboot | Patrol instrumentation | False reboot claim from mocked state | Stage fixture, perform ADB reboot, inspect restored engine/tray after boot |

## Verification and documentation

Implementation uses approved atomic tasks for pure models/calendar; serialized coordinator; shell/background integration; UI/i18n; device evidence; documentation/independent verification. Each task derives tests from SCHED IDs and commits separately. Domain and shell specialists own their module changes; the e2e specialist runs the Android tier.

The device gate uses a separate application ID and preserves the user's installed app/data. Validate background seconds, selected-weekday behavior through deterministic clocks, disable/delete, same-ID replacement, actual reboot restoration and no missed notifications. Include behavior mutations for replay-on-start and disabled-rule execution, and a real-platform mutation for suppressed notification delivery. Record supported-device evidence without claiming overnight coverage unless observed.

Synchronize docs/ARQUITETURA.md, docs/OBJETIVO.md, root and affected module READMEs, STATE and feature documents with the final implementation. A fresh independent verifier is the closing gate.

## Research basis

Installed FlutterForegroundTask and local-notification source was inspected before external research. Context7 was unavailable. Official references:

- https://developer.android.com/develop/background-work/services/fgs/service-types#special-use
- https://developer.android.com/about/versions/15/changes/foreground-service-types
- https://developer.android.com/about/versions/15/behavior-changes-all#enhanced-stop-states
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://pub.dev/packages/timezone
- https://pub.dev/packages/flutter_timezone

T6 observed Home, screen-off, Recents, actual system-start reboot with missed-slot skipping, and exact next-future delivery on Android 16/API 36. A fresh d83414f build also proved native GMT weekly delivery. Full source attribution, exact oracles and bounded limitations are in evidence/device-task-gates.md; no physical handset or overnight observation is inferred.
