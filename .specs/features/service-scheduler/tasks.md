# Service Scheduler Implementation Plan

Goal: Persistent Android sidebar rules for local notifications, with intervals/weekly recurrence and skip-on-restart behavior.
Architecture: Pure-Dart recurrence and a serialized coordinator own the snapshot. Existing FGS runs that coordinator; native shell communicates by request/reply and displays the authoritative result.
Tech stack: Dart/Flutter, timezone, flutter_timezone, flutter_foreground_task, SharedPreferences, flutter_local_notifications, Patrol.
Status: Implementation and author gates complete; final independent validation pending. User approved the written design on 2026-10-04.

## Execution Protocol

Use tlc-spec-driven Execute, coding-principles and test-first workflow. Each task writes spec-derived failing tests, runs them, implements minimum behavior, runs its gate, records exact assertion evidence and commits atomically. No tests are weakened/deleted/skipped. Specialists are mandatory under CLAUDE.md; no optional phase-batch delegation is needed for seven tasks. The user already authorized implementation and connected-Android testing; use project-prescribed tools without another approval request.

## Test Coverage Matrix

Generated from CLAUDE.md, .agents/agents/popmundo-utils.md, popmundo-app-shell.md and popmundo-e2e.md. Samples inspected: storage_test.dart, menu_notification_state_store_test.dart, app_menu_registry_test.dart, background_keepalive_test.dart, auto_login_screen_test.dart, notifications/notification_service_test.dart, integration_test/keepalive_test.dart. Existing package manifests provide Dart test, Flutter test and Patrol commands. No coverage percentage is configured; cover every scoped AC and listed edge.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Model/serialization | unit | Bounds, roundtrip fields, unknown/corrupt schema and unique stable negative IDs | packages/popmundo_utils/test/scheduler_models_test.dart | dart test test/scheduler_models_test.dart |
| Recurrence | unit | Exact intervals, weekly dates, timezone/DST gap/fold, restart/missed boundaries | packages/popmundo_utils/test/recurrence_calculator_test.dart | dart test test/recurrence_calculator_test.dart |
| Coordinator | unit | Every command, revision conflict, serialized races, claims/failure/timeout, no replay | packages/popmundo_utils/test/scheduler_coordinator_test.dart | dart test test/scheduler_coordinator_test.dart |
| Shell/IPC/platform adapter | unit with channel/fake seams | JSON persisted fresh reload, request/reply/errors, boot flags, notification payload and truthful failure | apps/popmundo_app/test/scheduler_*_test.dart | flutter test |
| Native screens/menu | widget | Empty/list/create/edit/cancel/validation/pause/delete/errors/iOS/EN/PT | apps/popmundo_app/test/scheduler_*_test.dart, app_menu_registry_test.dart | flutter test |
| Android fixture | device-real integration | Seconds delivery, Home/Recents, stable card/disable, persisted fresh engine and actual reboot; mutation proof | apps/popmundo_app/integration_test/scheduler_test.dart plus reboot harness | flutter analyze integration_test; patrol test --target integration_test/scheduler_test.dart -d emulator-5554 |
| Documentation | none | Public behavior and dependencies agree with actual implementation | docs/, READMEs, .specs/ | git diff --check plus final gates |

## Gate Check Commands

Commands below are run through cmd.exe /d /c from bash on this Windows workspace. Every shell invocation sets workdir. Use flutter.bat/dart.bat/patrol.bat on the host; do not use Python/Perl or file-manipulation scripts.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick core | T1/T2 | dart test in packages/popmundo_utils; dart analyze |
| Core phase | T3 | dart test and dart analyze in packages/popmundo_utils |
| Quick shell | T4/T5 | flutter test and flutter analyze apps/popmundo_app |
| Device | T6 | flutter analyze integration_test; Patrol fixture on connected Android; separate actual ADB reboot verification; confirm result XML/logcat |
| Final build | T7 + verifier | Core/webview/app analyze and tests; flutter build apk --release --target-platform android-x64; git diff --check |

Device safety: use isolated package com.popmundo.popmundo_app.backgrounddebug, preserve the installed production package/data. One native build at a time. Existing environment requires process-scoped JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\popflutter-java-afunix-disabled\not-created for Gradle. This emulator requires temporary profile AOT with debuggable access for fixture preference inspection, x64 target-platform, minification off and patrol native dependency enabled. Fresh APK packaging avoids stale archive gaps that exhausted device storage; restore all temporary Gradle, gradle.properties, dependency and application-ID configuration before the normal production release build. Never commit the workaround or test package change.

## Execution Plan

Phase 1 (pure core): T1 -> T2 -> T3.
Phase 2 (shell integration): T3 -> T4 -> T5.
Phase 3 (delivery): T5 -> T6 -> T7 -> fresh independent Verifier.

## Task Breakdown

### T1: Validated scheduler snapshot model

Depends on: none. Owner: popmundo-utils specialist.
Files: packages/popmundo_utils/lib/src/scheduler/scheduler_models.dart, lib/popmundo_utils.dart, test/scheduler_models_test.dart.
Requirements: SCHED-02/07/09/10.
Deliverable: immutable rule/recurrence/action/cursor/snapshot JSON model with validation, revisions and monotonic signed-negative notification identity. Preserve unknown/corrupt input by throwing a typed error instead of resetting it.
- [x] Test invalid counts 0/10000, weekdays empty/outside 1..7, HH:mm out of bounds, blank/overlong text; assert exact accepted fields after roundtrip and ID bounds.
- [x] Run the focused test red before implementation.
- [x] Implement the validated public model and exports; no Flutter dependency.
- [x] Run Quick core; provide file:line assertion evidence and commit feat(scheduler): add validated rule snapshot model.
Tests: unit. Gate: Quick core. Done when all listed input/schema/payload outcomes pass and no IDs are silently recycled.

### T2: Deterministic recurrence calculator

Depends on: T1. Owner: popmundo-utils specialist.
Files: packages/popmundo_utils/lib/src/scheduler/recurrence_calculator.dart, pubspec.yaml, lib/popmundo_utils.dart, test/recurrence_calculator_test.dart; resolved pubspec.lock dependency if needed.
Requirements: SCHED-04/05/06.
Deliverable: next strictly future occurrence and armed-slot lateness eligibility; elapsed UTC intervals and IANA local-date weekly search.
- [x] Test interval A=12:00:00,D=10s -> :10/:20 and restart :35 -> :40; 24-hour days; multiple weekdays and exact weekly boundary.
- [x] Test New York 2026-03-08 02:30 -> 03:30; 2026-11-01 01:30 -> first copy once; local-zone changes and year crossing.
- [x] Test min(30s,D) interval tolerance and 30s weekly tolerance at inclusive bound and just beyond.
- [x] Run red; add timezone direct dependency and minimum calculator; run Quick core and commit feat(scheduler): calculate interval and weekly occurrences.
Tests: unit. Gate: Quick core. Done when exact spec-defined instants and skip boundaries pass without drift.

### T3: Serialized durable coordinator

Depends on: T2. Owner: popmundo-utils specialist.
Files: packages/popmundo_utils/lib/src/scheduler/scheduler_coordinator.dart, lib/popmundo_utils.dart, test/scheduler_coordinator_test.dart; small action/store ports if clarity requires.
Requirements: SCHED-03/06/07/09/10.
Deliverable: single writer with load/list/create/update/toggle/delete/reconcile, revision guards, persisted pre-action claim, five-second action bound and latest result.
- [x] Test restart skips all past slots and next future survives a newly constructed coordinator.
- [x] Test text edit preserves anchor/ID; recurrence edit/re-enable resets due; pause/delete prevents queued candidates; stale revision rejects.
- [x] Test failed command/claim write gives no success/action; failed action continues other rules; timeout/interrupted claim is not retried; ID sequence survives deletion.
- [x] Test overlapping command/tick serialization and no lost updates; preserve corrupt snapshot.
- [x] Run red, implement minimum queue, run Core phase and commit feat(scheduler): persist and serialize scheduled execution.
Tests: unit. Gate: Core phase. Done when claims/actions/state satisfy exact ACs and full prior utils suite remains green.

### T4: Background runtime and shell transport

Depends on: T3. Owner: popmundo-app-shell specialist.
Files: apps/popmundo_app/lib/scheduler/scheduler_client.dart, scheduler_store.dart, scheduler_runner.dart, lib/background/keepalive_task_handler.dart, flutter_foreground_task_platform.dart, lib/notifications/local_notifications_service.dart (narrow strict action path only), app pubspec.yaml, pubspec.lock, test/scheduler_runtime_test.dart, test/scheduler_client_test.dart, platform_config_test.dart if needed.
Requirements: SCHED-03/07/08/09/10.
Deliverable: FGS-owned coordinator, reload-aware persistence, nearest Timer, heartbeat reconciliation, registered local action and typed request/reply; current notification/session consumers retain their contract.
- [x] Test boot flags derived from enabled catalog with complete wake/stopWithTask options; preserve heartbeat messages.
- [x] Test request correlation, revision/payload/error/timeout, fresh-store reload, permission denial and strict initialization/submission failure.
- [x] Run red, integrate real installed plugin APIs and current device-zone identifier, arm Timer after start/commands/tick, cancel on destroy.
- [x] Run Quick shell and commit feat(scheduler): run persisted rules in Android service.
Tests: unit/channel-seam. Gate: Quick shell. Done when storage/IPC/platform-adapter cases pass and existing keepalive/notification tests remain green. Native lifecycle is additionally measured by T6's fixture.

### T5: Native sidebar scheduling page

Depends on: T4. Owner: popmundo-app-shell specialist.
Files: apps/popmundo_app/lib/scheduler/scheduler_screen.dart, scheduler_editor.dart, lib/menu/app_menu_registry.dart, lib/app.dart, assets/translations/en.json, pt.json, test/scheduler_screen_test.dart, scheduler_editor_test.dart, app_menu_registry_test.dart and affected menu fixtures.
Requirements: SCHED-01/02/03/08/09.
Deliverable: existing-theme list/form with interval/weekday inputs, latest/next status, permission status/actions, pause and confirmed delete; iOS explanation.
- [x] Write widget assertions for authoritative saved payload, invalid fields, cancel unchanged, failure/timeout retained form, list state, edit cadence, toggle and deletion confirmation.
- [x] Test translated EN/PT labels, release menu callback and unavailable iOS state. Update prior menu expectations only to reflect the newly approved item; do not weaken old callback/debug gating tests.
- [x] Run red; wire page through existing menu/composition root; run Quick shell and commit feat(scheduler): add sidebar schedule management.
Tests: widget. Gate: Quick shell. Done when all visible release text is localized and screens exercise exact persisted outcomes.

### T6: Android scheduler fixture and reboot proof

Depends on: T5. Owner: popmundo-e2e specialist.
Files: apps/popmundo_app/integration_test/scheduler_test.dart, support/scheduler_reboot_harness.dart and support/harness.dart if needed; feature evidence logs. Temporary Gradle/pubspec/package edits are restored, never committed.
Requirements: SCHED-06/07/08/09/10.
Deliverable: one-Patrol-test-per-file minimal non-game fixture plus reboot entrypoint with durable rules and real OS tray/service evidence.
- [x] Write bounded native tray assertions for rule title/body and separate IDs, updated same card, post-Home/Recents delivery and no delivery after disable.
- [x] Analyze integration_test, run real fixture on connected Android; capture XML/logcat as source of truth.
- [x] Stage durable future rule, reboot emulator with ADB, wait boundedly for boot/service, inspect notification + persisted new result. Reboot must not open the game or erase production data. Prove missed slots skipped before next notification.
- [x] Inject suppression of scheduled notification in scratch state, demonstrate native test red, discard mutation and reconfirm green.
- [x] Restore temp build configuration, run Device gate and commit test(scheduler): prove background notifications and reboot restoration.
Tests: device-real integration. Gate: Device. Done when the real lifecycle/card/skip evidence is retained and mutation is killed.

### T7: Maintenance docs and verified release

Depends on: T6. Owner: orchestrator; fresh verifier authors validation separately.
Files: docs/ARQUITETURA.md, docs/OBJETIVO.md, root README.md, touched module READMEs, .specs/STATE.md and service-scheduler docs/evidence.
Requirements: SCHED-01..10 traceability and all architecture constraints.
Deliverable: consistent maintenance docs, exact coverage mapping, approved AD-021, release build installed preserving production data, final independent validation.
- [x] Map task/test assertion file:line to every SCHED requirement; record actual gate output/counts and bounded limitations.
- [x] Update maintenance docs from final source; no hypothetical claims.
- [x] Run Final build, install production APK with adb install -r, inspect service/menu without loading live-site test fixtures; commit docs(scheduler): document verified scheduling lifecycle.
- [ ] Dispatch fresh independent verifier after final task commit; provide spec, commit range, tests, validate.md and scratch mutation rules. Route gaps to atomic fixes and reverify (maximum three iterations).
Tests: none for docs; full implementation gates. Gate: Final build. Done when verifier PASS, production install succeeds and working tree contains no temporary device-test configuration.

## Granularity, diagram and test co-location checks

| Task | One cohesive deliverable | Depends on | Diagram incoming | Tests required/provided | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | Snapshot model | none | none | unit/unit | PASS |
| T2 | Recurrence calculator | T1 | T1 | unit/unit | PASS |
| T3 | Coordinator | T2 | T2 | unit/unit | PASS |
| T4 | Background runtime adapter | T3 | T3 | unit/unit | PASS |
| T5 | Schedule management screen | T4 | T4 | widget/widget | PASS |
| T6 | Native lifecycle fixture | T5 | T5 | device-real/device-real | PASS |
| T7 | Maintenance/release handoff | T6 | T6 | none/full gates | PASS |

## API coordination note

The domain specialist publishes actual immutable public signatures immediately after T1 and T2. The shell specialist consumes those, never inventing a parallel schema. Canonical JSON uses service_scheduler.v1. No speculative pipeline/action-chain APIs are introduced. Expected-value test sketches below illustrate spec oracles; actual signatures follow the smallest verified core contract.

    expect(nextDue, DateTime.utc(2026, 10, 4, 12, 0, 40));
    expect(shownNotifications, isEmpty); // restart at 12:00:35
    expect(saved.notificationId, -1);
    expect(nextCreated.notificationId, -2); // first deleted
    expect(snapshot.rules.single.action.title, 'Lembrete');

## Execution evidence

Per-task adequacy tables, commands, counts and commit IDs are recorded in evidence/core-task-gates.md and evidence/shell-task-gates.md (device and final gate reports added by their owners) by task owners/orchestrator. Independent final coverage and discrimination results belong to validation.md.
