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
| T8 | ⚠️ Partial — device run still pending | Code complete (`integration_test/notifications_test.dart`, 1 `patrolTest`, `reason:` on every `expect`); `flutter analyze integration_test` passes. The original Verifier session's Patrol run failed at Gradle (`java.io.IOException: Unable to establish loopback connection`). That is a historical incident, not a standing ban: the next agent must retry `patrol test` itself. Done-when boxes for "test passes on device" and "mutation-proof shown red" remain unchecked until that retry succeeds. |
| T9 | ✅ Done in substance, ⚠️ bookkeeping gap | `docs/ARQUITETURA.md` (§6.6 + diagram + dependency table + pattern table + module table, all independently confirmed by diff read), `apps/popmundo_app/README.md` (module row + deps + flows), `spec.md` traceability table (status → `Implementing`) are all genuinely updated. However `tasks.md`'s own T9 "Done when" checkboxes are still `- [ ]`, not ticked, even though the underlying work is done — same for T8's non-device-blocked items. Left as-is (not silently fixed) since it's `tasks.md`'s own bookkeeping, not this report's file. |

**All tasks done in substance except the single device-dependent proof, which the next agent must run (`patrol test`), not hand to the user.**

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

**Patrol device run — attempted in the original Verifier session, Gradle failed; next agent retries:**

```
cd apps/popmundo_app && patrol test --target integration_test/notifications_test.dart -d emulator-5554
...
FAILURE: Build failed with an exception.
* What went wrong:
java.io.IOException: Unable to establish loopback connection
✗ Failed to build apk with entrypoint test_bundle.dart (Gradle build failed with code 1)
```

`emulator-5554` (Android 16/API 36) was detected and online (`flutter devices`); `flutter analyze integration_test` passed cleanly beforehand. The failure is at the Gradle build step, before any test code runs — a historical incident of that Verifier session, **not a standing ban**. The next agent dispatch must retry the Patrol run itself.

---

## Fix Plans

No code-level fix tasks — the one open coverage gap (`LocalNotificationsService.initialize()`'s failure branch, part of NOTIF-08) is low-risk (a straightforward try/catch, already reviewed by inspection) and the device-pending ACs (NOTIF-01/03/04/07) require no code change, only a Patrol device run by the agent. See Next Steps below.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| NOTIF-01 | Implementing | ✅ Verified — real device run (user's own terminal, `emulator-5554`) + mutation-proof |
| NOTIF-02 | Implementing | ✅ Verified |
| NOTIF-03 | Implementing | ✅ Verified — deny-then-grant sequence confirmed against the real OS permission dialog |
| NOTIF-04 | Implementing | ✅ Verified — real tray content confirmed; mutation-proof (see below) killed on the exact assertion |
| NOTIF-05 | Implementing | ✅ Verified |
| NOTIF-06 | Implementing | ✅ Verified |
| NOTIF-07 | Implementing | ✅ Verified — tray confirmed to never exceed one notification across two sequential taps |
| NOTIF-08 | Implementing | Implementing *(DebugOverlay catch-path Verified; `LocalNotificationsService.initialize()` failure branch remains untested by any executed test — accepted, see Next Steps)* |

Applied to `spec.md`'s Requirement Traceability table with matching notes.

---

## Addendum: Post-Verification Device Run + Mutation-Proof (completed outside this Verifier's own session)

This Verifier's own dispatch could not complete the Patrol device run — independently reproduced `java.io.IOException: Unable to establish loopback connection` at the Gradle build step, matching the implementer's report exactly. That block is a Gradle daemon restriction specific to agent-sandboxed processes on this machine: re-confirmed directly by the orchestrator afterward via a plain `flutter build apk --debug` (no test code involved at all), which failed identically. It is not something a later agent dispatch can work around by simply retrying.

What actually unblocked progress was the **user** running `patrol test` from their own (non-sandboxed) terminal, which surfaced two real, fixable bugs neither agent sandbox could have discovered because neither could get a Gradle build far enough to hit them:
1. `flutter_local_notifications` requires Android core library desugaring — missing from `apps/popmundo_app/android/app/build.gradle.kts` (fixed, commit `a938592`).
2. `notifications_test.dart`'s `addTearDown` hung indefinitely on `openNotifications → tapOnNotificationByIndex → closeNotifications` (fixed in two steps, commits `f9cb868` and `d57eba4` — the final version drops the teardown's `closeNotifications` call entirely, since Patrol only documents it as safe while the shade is visible, and the test body already closes it after each phase).

With both fixed, the user's device run passed end-to-end (NOTIF-01/03/04/05/07 all green), and the orchestrator then ran the mutation-proof check with the user's help: mutated `LocalNotificationsService.showTestNotification()` to no-op, the user re-ran `patrol test` and it failed at the exact `NOTIF-01/NOTIF-04` assertion (`Expected: non-empty, Actual: []`), confirming the test discriminates a broken trigger — then the mutation was reverted via `git checkout --` (tree confirmed clean).

---

## Summary

**Overall**: ✅ Ready — 7 of 8 ACs fully verified (file:line evidence + mutation-proof where applicable, now including a real on-device pass). One narrow, low-risk gap remains on NOTIF-08.

**Spec-anchored check**: 7/8 ACs fully Verified; 1/8 (NOTIF-08) has a partial gap — the DebugOverlay-side catch is Verified and mutation-proof, but `LocalNotificationsService.initialize()`'s own failure branch has no executed test in either tier
**Sensor**: 3/3 original mutations killed (debug_overlay.dart) + 1/1 additional mutation killed post-hoc on the real device (`showTestNotification()` no-op → NOTIF-01/04 assertion failed as expected, then reverted)
**Gate**: 84 passed, 0 failed (fast tier); `flutter analyze .` and `flutter analyze integration_test` both clean; Patrol device run PASSED on a real emulator from the user's own terminal (agent sandboxes on this machine still cannot complete a Gradle build at all, confirmed independently — this is environmental, not a retry-and-it-works situation)

**What works**: The full DebugOverlay-side state machine (debounce, denial-safety, error-safety, fixed English label, release-gate inheritance) is proven correct and regression-proof via 10 fast, device-free widget tests and 3/3 killed mutations. The real plugin wiring (`LocalNotificationsService`, permission flow, fixed-id replace-not-stack behavior) is now proven against a real Android emulator and mutation-proof. Composition-root wiring (`main.dart`→`app.dart`→`DebugOverlay`) is minimal and matches the existing `keepalive` pattern exactly. Documentation (`ARQUITETURA.md`, `README.md`, `spec.md`) is genuinely in lockstep with the code, not just claimed to be.

**Issues found**:
1. NOTIF-08's `LocalNotificationsService.initialize()` failure branch (as opposed to the DebugOverlay-side catch, which IS verified) has zero executed test coverage in either tier — low risk (simple try/catch, reviewed by inspection), genuinely unproven, and this Verifier's own Fix Plans already judged it not worth a fix task given the MVP's scope and the existing `FlutterForegroundTaskPlatform` zero-unit-test precedent.

**Next steps**:
1. None required to close this feature — accept the NOTIF-08 gap per the existing project precedent (see Fix Plans above), consistent with this Verifier's original recommendation.
2. If stronger proof of `LocalNotificationsService.initialize()`'s catch branch is ever wanted, it would require making the plugin injectable — a larger change than this MVP's scope; revisit only if `initialize()` failures become a real operational concern.
