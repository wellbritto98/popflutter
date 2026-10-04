# Background session reliability

## Problem / evidence

2026-10-04: user reports background Auto Login appears stopped or never notifies.
Connected online Android device is emulator-5554, Android 16 / API 36.
Existing installed foreground service was alive for ~3 hours, notification permission granted, battery allowlisted.
Code routes AutoLoginStatus only to Snackbar; native session probes still await navigator.userAgent through potentially suspended WebView JS without a timeout.
Service uses dataSync, limited to six background hours on Android 15+; user explicitly requires continuous operation, including overnight.

## Acceptance criteria

- BSR-01: Native session checks continue when page JavaScript is suspended. User agent is resolved from the native WebView API in the app; library fallback captures the page UA once with a bounded wait (2 seconds by default). The result is cached and reused. A stalled first lookup uses existing fallback; native checks and future ticks remain possible.
- BSR-02: Native relog completes cookie synchronization and emits done without waiting for a suspended WebView navigation callback. Navigation remains requested with a bounded wait (2 seconds by default); timeout and failures are contained in diagnostics.
- BSR-03: A completed or failed Auto Login while lifecycle is not resumed posts one OS notification (stable id 2), with localized title and the existing localized result message. Progress phases and foreground results do not post OS notifications. Plugin failure does not interrupt authentication or crash the app.
- BSR-04: Android foreground service declares and starts specialUse with matching permission and a manifest subtype explaining continuous user-visible session maintenance. stopWithTask=false and wake lock remain. This session maintenance service is not finite bulk data synchronization.
- BSR-05: Device tests prove native probes, relog cookies, result notification, and distinct keepalive ticks while still backgrounded, before reopening. Tests use a local fixture, never the live game.
- BSR-06: When native relog assigns a new host while final navigation is pending, subsequent probes and cookie reads use that authenticated origin without mutating HostTracker; a real native navigation restores HostTracker authority. Preserve sticky host resolution, native HTTP transport, cookie scopes, credential storage, existing throttle, and foreground feedback.

## Atomic work

1. Remove unbounded renderer dependencies from native Auto Login; regression tests and utils docs.
2. Add localized background result notification and session-appropriate foreground service declaration; shell tests and docs.
3. Add/run real Android background regression and mutation checks; independent verification, build and install production APK without clearing user data.

## Limits

Continuous operation means while the Android process/service is retained. Force-stop, reboot, OEM kills, lost networking, and server refusal remain external limits; no auto-boot is added. iOS background execution policy is unchanged. specialUse distribution through Google Play requires review of the declared use case. An overnight-duration run is distinct from accelerated/device functional checks and must not be claimed without evidence.

## Source

- https://developer.android.com/develop/background-work/services/fgs/timeout
- https://developer.android.com/develop/background-work/services/fgs/service-types#special-use
