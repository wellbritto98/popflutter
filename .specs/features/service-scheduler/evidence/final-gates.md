# Final maintenance gate evidence

## Stable packages

Production core and WebView source remained unchanged while shell recovery and device fixtures were completed. The commands below ran in their package directories on Windows through cmd.exe from bash; every command exited 0. Default test globs exclude test_live and integration_test.

| Package | Command | Actual outcome | Raw evidence |
| --- | --- | --- | --- |
| popmundo_utils | dart.bat test --reporter expanded | 273 passed, no failures | final-core-tests.log |
| popmundo_utils | dart.bat analyze | No issues found | final-core-analysis.log |
| popmundo_webview | flutter.bat test --no-pub --reporter expanded | 31 passed, no failures | final-webview-tests.log |
| popmundo_webview | flutter.bat analyze --no-pub | No issues found | final-webview-analysis.log |

The recovery fix 3131a8f passed 136 app tests; c56844c fixed the native Activity-bound permission check and passed 137 app tests plus analyzer (shell-task-gates.md). Native GMT alias fix d83414f passed 138 app tests and clean app/integration analyzers. Home, screen-off, Recents, actual reboot/skip and native suppression sensor passed on the isolated Android fixture; native weekly GMT delivery passed on 2026-10-05 with exact planned/local slot, saved payload and next occurrence seven days later; restored production build configuration and release install are pending. This record does not claim final feature completion or overnight observation.

## Requirement mapping before independent validation

The table identifies the located assertion evidence reviewed by the orchestrator; it is not a substitute for the fresh Verifier's own coverage derivation. Evidence tables reproduce exact file:line expressions and expected saved values.

| Requirement | Coverage and outcome evidence |
| --- | --- |
| SCHED-01 | shell-task-gates.md T5: release registry EN/PT, empty/iOS page, visible next/result updates |
| SCHED-02 | core-task-gates.md T1 model bounds/roundtrip; shell-task-gates.md T5 full form, default minute, day/weekday/time and invalid input preserving state |
| SCHED-03 | core-task-gates.md T3 commands/authoritative writes; shell-task-gates.md T5 retained editor/lost reply adoption, cancel/toggle/confirmed deletion |
| SCHED-04 | core-task-gates.md T2 exact anchored UTC instants and 24-hour days; T3 cadence/no drift; shell T4 timer without heartbeat |
| SCHED-05 | core-task-gates.md T2 exact weekly calendar, New York gap/fold and zones; T3 recovery/current zone; shell T4 bounded zone cache; real composition GMT alias regression after complete IANA database fix d83414f |
| SCHED-06 | core-task-gates.md T2 inclusive lateness boundaries; T3 restart :35 -> :40 without notification, no replay and backward-clock watermark; actual system-start reboot skips first missed slot and submits exact next anchored slot (T6 evidence) |
| SCHED-07 | core-task-gates.md T1 signed-negative bounds; T3 exact native-action payload/stable IDs/no recycling; shell T4 strict native payload; actual OS records prove distinct IDs, exact saved/edited payload and same-card replacement (T6 evidence) |
| SCHED-08 | shell-task-gates.md T4 complete enabled/disabled boot/wake/Recents options; T5 permission/status/readiness; recovery fix late disposal; native Home/Asleep/Recents/reboot evidence proves supported lifecycle (T6 evidence) |
| SCHED-09 | core-task-gates.md T3 claim/result/command failures, corrupt retention, five-second action timeout; shell T4 strict initialization/permission/errors; T5 retained editor; recovery fix bounded startup/retry |
| SCHED-10 | core-task-gates.md T3 serialized full catalog, revisions, pre-action durable claim and stale candidates; shell T4 correlation/coalescing; T5 coalesced visible reads; recovery fix retains sole ownership after timeout |

Original game/session pathways remain outside the secondary scheduler engine. The full existing package suites include their regression checks. Actual OS lifecycle evidence and production installation will be added after T6; no overnight claim is made.

## Restored app and production release — 2026-10-05

T6 committed as fac723d. All temporary application-ID, build type, platform property, dependency and lock configuration is restored. The main app gate ran again after restoration: 138 tests passed, exit 0 (final-app-tests.log); app and integration analyzers each reported No issues found, exit 0 (final-app-analysis.log, final-integration-analysis.log). Together with unchanged core273/WebView31 gates, default suites contain 442 passing tests; baseline356, delta+86. No default test was skipped or deleted.

Normal flutter build apk --release --target-platform android-x64 ran with pub enabled and the process-only JDK workaround; exit0, 118.1s, APK23.5MB (production-release-build.log). Generated registration contains FGT, local notifications and timezone, with no Patrol runtime registration (production-plugin-registrant.txt). Flutter libapp.so/libflutter.so are x86_64 only; packaged plugin-native libraries also declare ARM ABIs, so package badging alone is not the Flutter target evidence. Exact APK hash and package/version/SDK metadata are retained separately.

adb install -r updated com.popmundo.popmundo_app on emulator-5554 successfully (production-install.log). Before/after metadata preserves firstInstallTime2026-08-20 01:55:00, ceDataInode368644 and deDataInode156114. Only lastUpdateTime advances to2026-10-05 23:00:26. No production clear, uninstall or force-stop occurred. A normal Activity launch restored the foreground service; no game UI assertions, login simulation or live-site fixture was executed. production-final-service.txt shows isForeground=true, foregroundId1000, specialUse type0x40000000 and startRequested=true. Scheduler callback startup is recorded independently.

Native evidence is in device-task-gates.md: exact real OS payload/card cardinality, Home/Asleep/Recents, actual system-start reboot across a missed slot, next anchored future delivery, and actual GMT weekly delivery with next occurrence seven days later. Native suppression mutant failed the OS-card assertion and restored green passed. This covers one Android16 emulator; no physical handset, PIN/keyguard authentication or overnight coverage is claimed. Seconds remain best effort; force-stop requires opening the app again.

All author implementation/build/install gates are complete. Fresh independent validation is the closing gate and is recorded separately in validation.md.
