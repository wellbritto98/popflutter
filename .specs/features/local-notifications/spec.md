# Local Notifications MVP Specification

## Problem Statement

Popflutter has no way yet to surface a system-level local notification from the app. Before any real trigger (e.g. a future game event) can use notifications, the plumbing — plugin init, permission handling, and a way to fire one — needs to exist and be provably wired end-to-end. This feature adds that plumbing behind a manual debug-panel button, so it can be exercised and QA'd without any gameplay automation attached to it.

## Goals

- [ ] A debug-only button in the existing debug panel fires exactly one real OS local notification via `flutter_local_notifications`.
- [ ] The trigger path (permission → show) is provably correct on a real device via an automated Patrol test, not just a fast-tier fake.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| --- | --- |
| Scheduled / recurring notifications | MVP is an immediate, manual, one-shot trigger only |
| Notification tap/action handling (deep links, payload routing) | No app navigation or state change on notification tap in this MVP |
| Business-logic-triggered notifications (game events, alerts, etc.) | This feature only proves the plumbing; gameplay-automation triggers are explicitly out of scope repo-wide (CLAUDE.md) and would be a separate future feature |
| Configurable/user-editable notification content | Fixed MVP content; no settings UI |
| Notification history/log UI | Not needed for a manual QA button |
| Release-mode (non-debug) entry point | This is debug tooling; it inherits the existing debug-only sidebar gate (AD-009) and adds no other entry point |

---

## Assumptions & Open Questions

All of the following were resolved during Plan-Mode research (Context7 docs for `flutter_local_notifications`, codebase exploration of the `background/` pattern and Patrol harness) and explicitly written into the plan the user approved before this spec was written.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Permission request timing | Lazy, on first button press | Debug-only manual trigger; no reason to prompt at app startup | y |
| Android notification icon | Reuse the existing launcher icon resource; verify it's drawable-referenceable during implementation | Avoids adding new drawable assets for an MVP | y |
| Notification channel id/name | Fixed constant (`popflutter_debug_channel` / "Debug") | Simplest single-channel MVP; `AndroidNotificationDetails.channelId` is mandatory on API 26+ | y |
| Repeated-tap behavior | Fixed notification id (new tap replaces prior notification, doesn't stack); overlapping taps while a request is in flight are ignored | Prevents tray spam and duplicate concurrent permission dialogs during manual/Patrol testing | y |
| `permission_handler` package | Not used — rely on `flutter_local_notifications`' own `requestNotificationsPermission()` (Android)/`requestPermissions()` (iOS) | Verified current API via Context7; avoids a redundant dependency | y |
| Notification content language | Fixed English text, NOT run through `easy_localization` | AD-014 (active, `.specs/STATE.md`) already carves out that `DebugOverlay` stays in English because it's debug-only and never shown in release; the notification is only reachable via that same debug-only button (NOTIF-02), so the same carve-out applies — avoids adding EN/PT catalog entries for a string release users never see | y |
| `STATE.md` AD entry | Not added unless Design surfaces a genuinely new cross-cutting decision | This reuses the existing `background/` platform-interface + fake pattern; not a new architecture | y |

**Open questions:** none — all resolved and logged above.

---

## User Stories

### P1: Manual test notification from the debug panel ⭐ MVP

**User Story**: As a developer using the debug panel, I want to tap a button and see a real system notification appear, so that I can confirm local notifications are wired correctly before anything real triggers them.

**Why P1**: This is the entire scope of the MVP — there is no smaller vertical slice.

**Acceptance Criteria**:

1. **NOTIF-01** — WHEN the app starts THEN the system SHALL initialize the local-notifications plugin (Android + iOS settings, including the fixed notification channel) exactly once, before the debug panel becomes interactive.
2. **NOTIF-02** — WHEN the app runs with `kDebugMode == false` (release) THEN the "Send test notification" control SHALL be unreachable — it inherits the existing debug-only sidebar gate (AD-009); no separate visibility logic is added.
3. **NOTIF-03** — WHEN the user taps "Send test notification" AND the OS notification permission has not yet been granted THEN the system SHALL request the platform permission before attempting to show anything.
4. **NOTIF-04** — WHEN the permission is granted (or was already granted) THEN the system SHALL show exactly one local notification with a fixed English title and body (consistent with AD-014's carve-out that the debug-only surface stays in English), using the fixed channel id and a fixed notification id.
5. **NOTIF-05** — WHEN the OS denies the permission THEN the system SHALL NOT show a notification, SHALL NOT throw/crash, and the debug panel SHALL remain interactive afterward.
6. **NOTIF-06** — WHEN the button is tapped again while a previous tap's permission-request-then-show flow is still in flight THEN the system SHALL ignore the repeat tap until the first flow completes.
7. **NOTIF-07** — WHEN the button is tapped multiple times sequentially (each tap completing before the next starts) THEN each tap SHALL show a notification reusing the same fixed notification id, so the system tray never shows more than one such notification at once.
8. **NOTIF-08** — WHEN plugin initialization throws/fails at startup THEN the system SHALL catch the error, SHALL NOT crash the app, and subsequent taps of the button SHALL no-op safely (no unhandled exception).

**Independent Test**: On a real Android device/emulator, open the debug panel, tap "Send test notification", pull down the notification shade, and see the notification with the expected title/body. Automated via the Patrol test for NOTIF-03/04/05; the fast widget-test tier covers NOTIF-02/05/06/08 using a fake service.

No P2/P3 stories — the feature is intentionally MVP-only; everything beyond this vertical slice is listed in Out of Scope above, not deferred as a lower-priority story.

---

## Edge Cases

- WHEN the device is Android < 13 (API < 33) THEN `requestNotificationsPermission()` SHALL be a no-op and the notification SHALL show directly (the manifest-declared `POST_NOTIFICATIONS` permission, already present per AD-012/FGS-04, is sufficient pre-13).
- WHEN the iOS permission was previously denied by the user outside the app (in system Settings) THEN `requestPermissions()` SHALL return `false` without prompting, and the system SHALL follow NOTIF-05 (no crash, no notification).
- WHEN the configured notification icon resource cannot be resolved at build/runtime THEN this SHALL surface as an `initialize()` failure, covered by NOTIF-08 — implementation must verify a valid icon resource exists before relying on this path.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| NOTIF-01 | P1: Manual test notification | Tasks | Verified — real device run (user's own terminal) + mutation-proof (`d57eba4` reverted trigger, confirmed red, restored) |
| NOTIF-02 | P1: Manual test notification | Tasks | Verified |
| NOTIF-03 | P1: Manual test notification | Tasks | Verified — real device run confirms deny path + grant path against the actual OS dialog |
| NOTIF-04 | P1: Manual test notification | Tasks | Verified — real device run + mutation-proof (mutating `showTestNotification()` to no-op failed the exact NOTIF-01/04 assertion) |
| NOTIF-05 | P1: Manual test notification | Tasks | Verified |
| NOTIF-06 | P1: Manual test notification | Tasks | Verified |
| NOTIF-07 | P1: Manual test notification | Tasks | Verified — real device run confirms the tray never shows more than one notification |
| NOTIF-08 | P1: Manual test notification | Tasks | Implementing — DebugOverlay catch-path Verified; `LocalNotificationsService.initialize()`'s own failure branch remains untested (Verifier-accepted low-risk gap, matches the `FlutterForegroundTaskPlatform` zero-unit-test precedent; see validation.md) |

**ID format:** `NOTIF-NN`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 8 total, 8 mapped to tasks (T1-T8), 0 unmapped

---

## Success Criteria

- [ ] Tapping the debug button reliably produces a real OS notification on a connected Android device/emulator, proven by an automated Patrol test that reads the system tray (not just "no exception thrown").
- [ ] The fast widget-test tier proves the button-to-service call happens (and is denial-safe / debounced) without needing a device.
- [ ] Zero crashes across both the granted-permission and denied-permission paths.
