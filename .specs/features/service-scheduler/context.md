# Service Scheduler — Context

Date: 2026-10-04
Status: Approved by user on 2026-10-04.

## Feature boundary

Native sidebar scheduling, inspired by MacroDroid. A rule repeats by interval or by selected weekdays and local time. The MVP executes only a local notification. Other services may be added later through the same action contract.

## Confirmed user decisions

- Entry point belongs in the sidebar menu.
- Intervals include seconds, minutes and days; weekly rules support one or multiple weekdays.
- The MVP action is a local notification.
- Rules must continue with the app closed and after rebooting Android.
- If the device or service was unavailable, skip missed occurrences and wait for the next one. Never replay a backlog.

## Approved defaults

- Android-only scheduler in this MVP. Existing iOS features continue normally; unsupported continuous scheduling is explained on iOS.
- Interval units: seconds, minutes, hours, days; integer quantity 1–9999. Days mean elapsed periods of 24 hours.
- Weekly rules use the current device time zone and a 24-hour time picker.
- Each rule has a name, notification title/message and enabled switch. A recurrence launches one notification action.
- One notification card per rule; recurring executions update that card instead of accumulating cards.
- Creation and re-enabling start intervals from the current time. Editing only text keeps the cadence.
- Minor runtime delays are tolerated, with the precise bound in SCHED-06. Startup never recovers an overdue slot.
- No separate design exploration is needed for the screen: follow the existing native theme and form patterns.

These defaults were approved with the written design on 2026-10-04.

## Reference and deferred scope

MacroDroid is a reference for recurrence selection, not a request for its complete automation engine. Game actions, action chains, conditions, scripts, imports and cloud synchronization are outside this MVP.
