# F3 instrument tuning — final gates

Date: 2026-10-07, America/Sao_Paulo. Code/spec tip: 78e2b61, production core 0d24224 and shell fdea551. Previous release validation remains historical in validation.md; this amendment is independently checked in validation-instruments.md.

## Current verification

Independent current gates: 438 core, 196 app, 31 WebView tests passed (665 total); all three analyzers clean. Evidence: f3-verifier-core-*, f3-verifier-app-*, f3-verifier-webview-*. Nineteen new core and ten new app tests cover SGA-11; previous default-use, local and crew tests remain. Six behavioral mutations were killed in a scratch worktree; restored focused suites passed before that worktree was removed. Mutation patches/logs and the verifier report retain exact failures and assertions.

Browser inspection confirmed Deon's Mesa de DJ and Violino offer Item_Tune.png/Afinar, distinct from Item_Use.png/Usar. Only sanitized item names, control names and icon paths were retained. No real item use, tuning or crew payment was submitted. Default tests are synthetic; no new live-game or Patrol execution was performed for this pure mapping/configuration/UI amendment. Existing Android loopback lifecycle proof stays in t8-device-gates.md.

## Release build

Normal production entrypoint and restored project configuration: flutter build apk --release, with the existing process-only JAVA_TOOL_OPTIONS Unix-domain-socket workaround. Command exited 0; assembleRelease took 87.5 seconds. Log: f3-release-build.log. No dependency/configuration change or permanent workaround was added.

APK: apps/popmundo_app/build/app/outputs/flutter-apk/app-release.apk, 62556850 bytes, SHA256 bbb316e2d730360265dc23e924ee6733b72895fd0e19320720f4b2a1c2e5b640. aapt metadata identifies com.popmundo.popmundo_app, versionCode1/versionName1.0.0, minSdk24/targetSdk36. aapt list confirms libapp.so and libflutter.so for arm64-v8a, armeabi-v7a and x86_64. This is a universal APK, unlike the prior x64-only build. Fingerprint: f3-apk-fingerprint.txt; source hashes: f3-release-source.txt. Every listed production source hash was checked unchanged before completion.

## Update on the re-opened emulator

AVD Medium_Phone_API_36.1, device emulator-5554, boot complete. adb install -r returned Success (f3-production-install.log). No uninstall, clear or production force-stop was used.

Before and after this update retain firstInstallTime=2026-10-07 01:43:25 and data directory inodes ceDataInode=353749/deDataInode=41024. Only lastUpdateTime advances to 2026-10-07 11:15:08 (device timestamps). Evidence: f3-production-before.txt and f3-production-after.txt. This preserves the current October installation; it makes no claim about the already absent August data.

Normal launch returned Status: ok, LaunchState: WARM and MainActivity (f3-production-launch.log); the resumed activity matches that component (f3-production-activity.txt). ForegroundService reports isForeground=true, foregroundId1000, types0x40000000, startRequested=true (f3-production-service.txt).

Limits: this update was installed on one emulator. No physical handset, overnight run or real gameplay effect was tested. User scheduling retains the existing Android best-effort/no-replay limits.
