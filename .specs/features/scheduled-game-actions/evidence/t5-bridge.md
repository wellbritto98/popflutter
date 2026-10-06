# T5 app compatibility bridge

Red: t5-bridge-red.log, exit1, ScheduledAction local getters and non-exhaustive new result statuses. Tests written before bridge production. Green: t5-bridge-green.log, full app165 passed, exit0 (baseline164 + one offline game preservation case). Existing assertions retained, only type casts added to known local fixtures. No skipped/deleted tests.

| AC / done-when | Exact assertion evidence | Spec-defined outcome |
| --- | --- | --- |
| SGA-01.3, SGA-02.5/7 saved character/effect survives offline editing | apps/popmundo_app/test/scheduler_game_bridge_test.dart:46 expect(saved.action.toJson(), action.toJson()) | Entire account/char ID42/name/item payload preserved |
| SGA-02.5 no automatic live discovery | same:52 expect(api.lists, 0) | Editor saving does not discover through API |
| SGA-02.7 identity and cadence preserved | same:48 expect(saved.id, original.id);49 expect(saved.notificationId, original.notificationId);50 expect(saved.recurrence.toJson(), original.recurrence.toJson());51 expect(saved.nextDueUtc, original.nextDueUtc) | Stable IDs, recurrence and next occurrence |
| SGA-02.1 fields appropriate to action | same:39 expect(find.text('Saved Character'), findsOneWidget);40/41 expect(find.byKey(...schedule-title/body...), findsNothing) | Saved game rule shows target, no local text fields |
| SGA-01.1 local exact data preserved | scheduler_background_permission_test.dart:74/75 expect((saved.action as LocalNotificationAction).title/body, 'Exact title'/'Exact body') | Existing local payload unchanged |
| SGA-01.1 local UTF-16 limits/payload preserved | scheduler_editor_test.dart:56/58/61/63/69/70 title/body exact and120/1000 lengths | Existing fixture assertion values unchanged |

Reverse mapping: all assertions in scheduler_game_bridge_test.dart:39-53 map to SGA-01 compatibility and SGA-02 offline editing/authoritative save; line47 edited name and53 one update prove actual accepted mutation. Existing local assertions map to previous scheduler requirements retained by SGA-01. No requirement-free tests introduced. Style follows existing localized widget helpers, fakes and app tests. Adequacy: bridge scoped coverage passed; full service selection/status UI tests belong to T7 and native gateway tests to T6.

Analyzer: t5-bridge-analyze.log, no issues, exit0. Initial analyzer exposed four ScheduledAction getters in integration_test/scheduler_test.dart; device specialist added LocalNotificationAction casts only, retaining exact expected values/reasons. No production change after app165 gate. SDK returned to core for final T5 race/regression gates. Stage this bridge with core T5; no separate bridge commit was made.
