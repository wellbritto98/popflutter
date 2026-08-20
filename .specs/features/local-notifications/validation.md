# Local Notifications MVP Validation

**Date**: 2026-08-19
**Spec**: `.specs/features/local-notifications/spec.md`
**Diff range**: `2f173e2..efd5e12` (9 commits, T1-T9)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | ✅ Done | `flutter_local_notifications: ^22.3.0` in `apps/popmundo_app/pubspec.yaml:44`; `flutter pub get`/`flutter analyze` both clean (re-run and confirmed). |
| T2 | ✅ Done | `apps/popmundo_app/lib/notifications/notification_service.dart` — abstract class, 3 methods, only `dart:async` import. |
| T3 | ✅ Done | `apps/popmundo_app/lib/notifications/fake_notification_service.dart` — call counters + `permissionGranted`/`initializeError`/`showDelay`. |
| T4 | ✅ Done | `apps/popmundo_app/lib/notifications/local_notifications_service.dart` — real plugin wiring; icon resource independently confirmed present (`android/app/src/main/res/mipmap-*/ic_launcher.png`, all 5 densities). Contains an honest, well-labeled `SPEC_DEVIATION` comment (lines 81-85) for the `show()` named-vs-positional-args drift against the design doc's Context7 snippet — verified against installed `flutter_local_notifications` 22.3.0 (`pubspec.lock`), and it's a real API-shape correction, not a behavior change. |
| T5 | ✅ Done | `apps/popmundo_app/lib/main.dart:23-24` — `LocalNotificationsService()` constructed and `initialize()` awaited before `runApp`. |
| T6 | ✅ Done | `apps/popmundo_app/lib/app.dart` — `notificationService` threaded through `PopmundoApp`→`PopmundoHome`→`DebugOverlay` unchanged, same shape as `keepalive`. |
| T7 | ✅ Done | `apps/popmundo_app/lib/debug_overlay.dart` — button, `_sendingNotification` guard, try/catch. Fast-tier test count in this file went 5 → 10 (+5, matches the 5 new scenarios: render, grant, deny, in-flight, throw). |
| T8 | ⚠️ Partial — environmental blocker | Code complete (`integration_test/notifications_test.dart`, 1 `patrolTest`, `reason:` on every `expect`); `flutter analyze integration_test` passes. **Device run could not execute** — reproduced independently (see Gate Check below): `patrol test` fails at Gradle with `java.io.IOException: Unable to establish loopback connection`, the same JDK/agent-sandbox restriction the implementer reported, on the same emulator (`emulator-5554`, detected and online). Task's own Done-when boxes for "test passes on device" and "mutation-proof shown red" are correctly left unchecked in `tasks.md` — this is accurate bookkeeping, not an oversight, since neither is achievable without a successful Gradle build. |
| T9 | ✅ Done in substance, ⚠️ bookkeeping gap | `docs/ARQUITETURA.md` (§6.6 + diagram + dependency table + pattern table + module table, all independently confirmed by diff read), `apps/popmundo_app/README.md` (module row + deps + flows), `spec.md` traceability table (status → `Implementing`) are all genuinely updated. However `tasks.md`'s own T9 "Done when" checkboxes are still `- [ ]`, not ticked, even though the underlying work is done — same for T8's non-device-blocked items. Left as-is (not silently fixed) since it's `tasks.md`'s own bookkeeping, not this report's file. |

**All tasks done in substance except the single device-dependent proof, which is blocked by a machine-level constraint (see Gate Check), not a code defect.**

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| **NOTIF-01** — init plugin (Android+iOS+channel) exactly once before debug panel interactive | Plugin initialized before `runApp`/panel can open | `apps/popmundo_app/lib/main.dart:23-24` — `await notificationService.initialize()` precedes `runApp(...)` (structural ordering, code-confirmed). Real-channel proof: `apps/popmundo_app/integration_test/notifications_test.dart:47-48,116-132` (`service.initialize()`, then asserts a real notification posts) | ⚠️ **Environmental blocker** — Patrol run could not execute (Gradle/loopback failure reproduced independently); structural ordering in `main.dart` is correct but the "plugin actually initializes on the real platform channel" claim is unproven this session |
| **NOTIF-02** — release (`kDebugMode==false`) makes control unreachable via existing sidebar gate, no new visibility logic | Button reachable only through the pre-existing debug-only sidebar entry | `apps/popmundo_app/lib/menu/app_menu_registry.dart:16` (`includeDebugItem = kDebugMode`, **unchanged by this diff** — confirmed via `git diff 2f173e2^..efd5e12` touching no menu files) + `apps/popmundo_app/lib/app.dart:312,340` (`onOpenDebugPanel`→`_debugPanelVisible`, only source of panel visibility) + `apps/popmundo_app/lib/debug_overlay.dart` (no `kDebugMode`/visibility logic added around the button — verified by grep, zero hits) + `apps/popmundo_app/test/debug_overlay_test.dart:178-197` (button renders when panel visible) | ✅ PASS |
| **NOTIF-03** — tap with permission not yet granted requests permission before showing anything | `requestPermission()` called, and `showTestNotification()` only after | `apps/popmundo_app/test/debug_overlay_test.dart:199-223` — `expect(service.requestPermissionCalls, 1); expect(service.showCalls, 1)` (order enforced by `await` in `debug_overlay.dart:87-90`, confirmed killed by mutation 1 below) proves the **DebugOverlay-side sequencing**. The real OS permission-dialog request is only exercised by `integration_test/notifications_test.dart:81-95` | ⚠️ **Environmental blocker** for the real-OS-dialog half; DebugOverlay-side call-then-branch logic is ✅ PASS and mutation-proof |
| **NOTIF-04** — permission granted (or already granted) shows exactly one fixed-content notification | Fixed English title/body, fixed channel/id | `apps/popmundo_app/test/debug_overlay_test.dart:199-223` proves the DebugOverlay→service call-through when granted (mutation-killed). Real tray-content proof: `integration_test/notifications_test.dart:121-139` (`expect(posted.first.content, kTestNotificationBody, ...)`) | ⚠️ **Environmental blocker** for the real tray-content half; DebugOverlay pass-through is ✅ PASS |
| **NOTIF-05** — OS denies permission ⇒ no notification, no crash, panel stays interactive | `showCalls == 0`, no exception, panel/button remain usable | `apps/popmundo_app/test/debug_overlay_test.dart:225-262` — `expect(service.showCalls, 0, reason: 'denied permission must not show a notification')`, `expect(button.onPressed, isNotNull, ...)`, plus a live re-tap of `debug-clear` to prove the panel is truly interactive | ✅ PASS |
| **NOTIF-06** — repeat tap while a prior flow is in flight is ignored until completion | Second tap during in-flight window triggers no second `requestPermission()`/`showTestNotification()` call | `apps/popmundo_app/test/debug_overlay_test.dart:264-312` — `expect(inFlightButton.onPressed, isNull, ...)`, then `expect(service.requestPermissionCalls, 1, reason: '...must not trigger a second request')`, `expect(service.showCalls, 1, ...)` | ✅ PASS |
| **NOTIF-07** — sequential taps reuse the same fixed notification id (never stacks) | Tray never shows more than one such notification at once | Code-level guarantee only: `apps/popmundo_app/lib/notifications/local_notifications_service.dart:10,73-91` — `kTestNotificationId` is a top-level `const`, used unconditionally in every `_plugin.show(id: kTestNotificationId, ...)` call, no branch could vary it. Runtime tray-replace proof: `integration_test/notifications_test.dart:140-146` (`expect(posted.length, 1, reason: '...must never show more than one at once')`) | ⚠️ **Environmental blocker** — only the unexecuted Patrol assertion proves actual OS replace-not-stack behavior; the Dart-level constant usage is correct by inspection but untested |
| **NOTIF-08** — init/show failure caught, no crash, subsequent taps no-op safely | No unhandled exception; button remains usable | DebugOverlay-side: `apps/popmundo_app/test/debug_overlay_test.dart:314-344` — `_ThrowingNotificationService` (throws from `showTestNotification()`), `expect(button.onPressed, isNotNull, reason: '...must not be stuck disabled...must not crash the panel')`; mutation-killed (mutation 3 below). `LocalNotificationsService.initialize()`'s own try/catch: `local_notifications_service.dart:27-46` wraps the entire body and sets `_initialized = false` on any throw — verified by code inspection only; **no test in either tier forces this specific branch to actually throw** (the Patrol test calls `initialize()` normally, doesn't inject a failure) | ⚠️ **Spec-precision/coverage gap** — DebugOverlay's catch-and-continue is ✅ PASS and mutation-proof; `LocalNotificationsService.initialize()`'s internal catch is unverified by any executed test (code-review-only) |

**Status**: ⚠️ Gaps present — 3 ACs (NOTIF-01/03/04 partially, NOTIF-07 fully) blocked purely by the documented environmental constraint; 1 AC (NOTIF-08) has a narrow, low-risk untested sub-path; 4 ACs (NOTIF-02/05/06, plus NOTIF-08's DebugOverlay half) are fully verified with mutation-proof.

---

## Discrimination Sensor

Ran in the real working tree via mutate → test → `git checkout --` (no worktree/stash used; tree confirmed clean before and after via `git status --short`).

| Mutation | File:line | Description | Killed? |
| --- | --- | --- | --- |
| 1 | `apps/popmundo_app/lib/debug_overlay.dart:88` | Flipped `if (granted)` → `if (!granted)` in `_sendTestNotification` | ✅ Killed — 3 of 10 fast tests failed (`+7 -3`): grant-path, deny-path, and in-flight tests all broke |
| 2 | `apps/popmundo_app/lib/debug_overlay.dart:154` | Removed the `_sendingNotification` debounce condition from the button's `onPressed` guard (kept only the `service == null` check) | ✅ Killed — 1 failure (`+9 -1`): the NOTIF-06 in-flight repeat-tap test |
| 3 | `apps/popmundo_app/lib/debug_overlay.dart:86-95` | Removed the `try`/`catch`/`finally` around `requestPermission()`/`showTestNotification()` (kept the calls, dropped error handling and the `finally` reset) | ✅ Killed — 1 failure (`+9 -1`): the NOTIF-08 throwing-service test |

**Sensor depth**: lightweight (3 targeted mutations, default tier)
**Result**: 3/3 killed — ✅ PASS

All mutations were reverted with `git checkout -- apps/popmundo_app/lib/debug_overlay.dart` immediately after each run; `git status --short`/`git diff --stat` confirmed a clean tree before writing this report.

---

## Interactive UAT Results

Skipped — no user available in this dispatch (per task instructions). No UAT performed.

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ — interface/real/fake split matches the `background/` precedent exactly; no extra abstraction |
| Surgical changes | ✅ — every changed file (`main.dart`, `app.dart`, `debug_overlay.dart`, `pubspec.yaml`, docs) has a direct line to NOTIF-01..08; no unrelated edits |
| No scope creep | ✅ — no new `STATE.md` AD added (confirmed via `git diff --stat` on `.specs/STATE.md`: empty, matching design's explicit "no new AD" decision); no `permission_handler` dependency added; no scheduled/recurring notification code |
| Matches patterns | ✅ — mirrors `BackgroundPlatform`/`FlutterForegroundTaskPlatform`/fake shape 1:1; button follows the existing `debug-clear`/`debug-close` row convention; kebab-case key `debug-send-notification` |
| Spec-anchored outcome check (asserted values match spec) | ✅ — fast-tier assertions target exact call counts/`onPressed` state, not vague "no error" checks; Patrol assertions target the exact fixed title/body strings |
| Per-layer Coverage Expectation met (domain 1:1 ACs; routes happy+edge+error) | ⚠️ — met for the DebugOverlay layer (happy/deny/in-flight/error all covered); the `LocalNotificationsService.initialize()` failure branch has no executed test in either tier (see NOTIF-08 gap above) |
| Every test maps to a spec requirement — no unclaimed tests | ✅ — all 5 new `debug_overlay_test.dart` cases cite their NOTIF-NN in the test name/reason; the Patrol test cites NOTIF-01/03/04/05/07 per assertion |
| Documented guidelines followed | ✅ — `CLAUDE.md` two-tier test policy, AD-015 (one `patrolTest`/file, no `PopmundoApp` construction in `integration_test/`, `flutter analyze integration_test` before device run), AD-014 (English-only debug strings) all followed and independently verified |

The `SPEC_DEVIATION` comment in `local_notifications_service.dart:81-85` (named vs. positional args on `plugin.show()`) is exactly the kind of honest, grounded deviation-flag the process expects — it's a version-drift correction against the design doc's cached Context7 snippet, confirmed against the resolved `pubspec.lock` version (22.3.0), and does not change behavior.

---

## Edge Cases

- [x] Android < 13: `requestNotificationsPermission()` documented as a no-op per Context7-verified API in design; code path is unconditional (`local_notifications_service.dart:50-57`) so behaves correctly by construction — not independently tested on an API<33 device this session, but not a new risk (same plugin call for all Android versions)
- [x] iOS previously denied outside the app: `requestPermissions()` returning `false` is handled identically to any other denial by `_sendTestNotification`'s `if (granted)` branch — same code path as NOTIF-05, already PASS
- [ ] Configured notification icon resource unresolvable → surfaces as `initialize()` failure (NOTIF-08): icon resource **existence** independently confirmed (`android/app/src/main/res/mipmap-{h,m,xh,xxh,xxxh}dpi/ic_launcher.png` all present), but the failure-handling branch itself (`initialize()`'s try/catch) is not exercised by any executed test — same gap noted under NOTIF-08 above

---

## Gate Check

- **Gate command**: `cd apps/popmundo_app && flutter analyze . && flutter test` (Quick/Build gate; Full gate's Patrol step attempted separately, see below)
- **Result**: `flutter analyze .` — No issues found. `flutter analyze integration_test` — No issues found (both re-run independently). `flutter test` — **84 passed, 0 failed, 0 skipped**
- **Test count before feature** (`git show 2f173e2:apps/popmundo_app/test/debug_overlay_test.dart` vs. current): `debug_overlay_test.dart` went from 5 → 10 `testWidgets` (+5); confirmed no other test file in `apps/popmundo_app/test/` changed in this diff (`git diff --stat` scoped to `test/` shows only this one file). Full-suite before-count of 79 is consistent with the implementer's claimed 84-after figure (79 + 5 = 84, independently re-derived, not just trusted)
- **Test count after feature**: 84 (independently run and counted, matches implementer's report)
- **Delta**: +5 new tests, 0 deletions, 0 weakened assertions
- **Skipped tests**: none
- **Failures**: none in the fast tier

**Patrol device run — attempted independently, reproduced the documented environmental blocker:**

```
cd apps/popmundo_app && patrol test --target integration_test/notifications_test.dart -d emulator-5554
...
FAILURE: Build failed with an exception.
* What went wrong:
java.io.IOException: Unable to establish loopback connection
✗ Failed to build apk with entrypoint test_bundle.dart (Gradle build failed with code 1)
```

`emulator-5554` (Android 16/API 36) was detected and online (`flutter devices`); `flutter analyze integration_test` passed cleanly beforehand. The failure is at the Gradle build step, before any test code runs, and is the same JDK/agent-sandbox loopback restriction the implementing agent reported — **not caused by this feature's code, and not something a second agent dispatch can fix**. This confirms rather than merely repeats the implementer's claim.

---

## Fix Plans

No code-level fix tasks — the one open coverage gap (`LocalNotificationsService.initialize()`'s failure branch, part of NOTIF-08) is low-risk (a straightforward try/catch, already reviewed by inspection) and the device-blocked ACs (NOTIF-01/03/04/07) require no code change, only a device run from a non-sandboxed terminal. No fix task is warranted; see Next Steps below instead.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| NOTIF-01 | Implementing | Implementing *(device-run pending — environmental blocker, not a defect)* |
| NOTIF-02 | Implementing | ✅ Verified |
| NOTIF-03 | Implementing | Implementing *(DebugOverlay-side sequencing Verified; real-OS-dialog half device-run pending)* |
| NOTIF-04 | Implementing | Implementing *(DebugOverlay pass-through Verified; real-tray-content half device-run pending)* |
| NOTIF-05 | Implementing | ✅ Verified |
| NOTIF-06 | Implementing | ✅ Verified |
| NOTIF-07 | Implementing | Implementing *(device-run pending — environmental blocker)* |
| NOTIF-08 | Implementing | Implementing *(DebugOverlay catch-path Verified; `LocalNotificationsService.initialize()` failure branch untested by any executed test)* |

Applied to `spec.md`'s Requirement Traceability table with matching notes.

---

## Summary

**Overall**: ⚠️ Issues — not code defects, but 4 of 8 ACs are not yet independently proven against the real OS/plugin because the device-real Patrol test cannot execute in this (or any current agent) sandbox on this machine.

**Spec-anchored check**: 4/8 ACs fully Verified with `file:line` evidence + mutation-proof (NOTIF-02, 05, 06, and the DebugOverlay half of NOTIF-08); 4/8 blocked on the device run (NOTIF-01, 03, 04, 07), each with partial fast-tier evidence for the DebugOverlay-side logic where applicable
**Sensor**: 3/3 mutations killed
**Gate**: 84 passed, 0 failed (fast tier); `flutter analyze .` and `flutter analyze integration_test` both clean; Patrol device run attempted and independently confirmed blocked by `java.io.IOException: Unable to establish loopback connection` at the Gradle step (JDK 17+ agent-sandbox restriction, reproduced, not a code issue)

**What works**: The full DebugOverlay-side state machine (debounce, denial-safety, error-safety, fixed English label, release-gate inheritance) is proven correct and regression-proof via 10 fast, device-free widget tests and 3/3 killed mutations. Composition-root wiring (`main.dart`→`app.dart`→`DebugOverlay`) is minimal and matches the existing `keepalive` pattern exactly. Documentation (`ARQUITETURA.md`, `README.md`, `spec.md`) is genuinely in lockstep with the code, not just claimed to be.

**Issues found**:
1. NOTIF-01/03/04/07 cannot be proven against the real OS/plugin from any agent session on this machine — root cause is a JDK 17+ Gradle loopback restriction inside the agent sandbox (confirmed independently, matches the implementer's report exactly). **Not fixable by another agent dispatch.**
2. NOTIF-08's `LocalNotificationsService.initialize()` failure branch (as opposed to the DebugOverlay-side catch, which IS verified) has zero executed test coverage in either tier — low risk (simple try/catch, reviewed by inspection), but genuinely unproven.
3. Minor bookkeeping: `tasks.md`'s T9 Done-when boxes remain unchecked despite the underlying doc-sync work being complete; T8's device-dependent boxes are correctly left unchecked (accurate, not a gap).

**Next steps**:
1. From a human's own terminal on this machine (not an agent sandbox), run: `cd apps/popmundo_app && patrol test --target integration_test/notifications_test.dart -d <device-id>`. If it passes, update `spec.md`'s NOTIF-01/03/04/07 rows to `Verified` and tick T8's remaining `tasks.md` boxes (including the mutation-proof step: temporarily revert the trigger in `debug_overlay.dart`, confirm `notifications_test.dart` goes red, restore).
2. Optional, low-priority: if stronger proof of `LocalNotificationsService.initialize()`'s catch branch is wanted, either accept the existing `FlutterForegroundTaskPlatform` zero-unit-test precedent as sufficient (current project convention), or add a narrow unit test that forces `_plugin.initialize()` to throw (would require making the plugin injectable, a larger change than this MVP's scope — likely not worth it).
