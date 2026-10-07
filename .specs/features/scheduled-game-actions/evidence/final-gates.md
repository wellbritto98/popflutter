# Final maintenance gate — scheduled game actions

Date: 2026-10-07 America/Sao_Paulo. Commands ran on Windows after the device proof in t8-device-gates.md. Default test globs exclude test_live and integration_test. Every listed command exited 0.

## Package gates

| Package | Command | Actual outcome | Raw evidence |
| --- | --- | --- | --- |
| popmundo_utils | dart test --reporter expanded | 419 passed | final-core-tests.log |
| popmundo_utils | dart analyze | No issues found | final-core-analysis.log |
| popmundo_webview | flutter test --reporter expanded | 31 passed | final-webview-tests.log |
| popmundo_webview | flutter analyze | No issues found | final-webview-analysis.log |
| popmundo_app | flutter test --reporter expanded | 186 passed | final-app-tests.log |
| popmundo_app | flutter analyze | No issues found (4.9s) | final-app-analysis.log |
| popmundo_app | flutter analyze integration_test | No issues found (4.9s) | final-integration-analysis.log |

Total default suites: 636 passed, zero failures. No default test was skipped or deleted. The Android fixture is outside flutter test; its Patrol XML, oracles and reboot observations stay in t8-device-gates.md.

Temporary fixture configuration (application ID, profile test build, debug signing, minification, x64 property, promoted Patrol dependency) was already restored. git diff of apps/popmundo_app/android/app/build.gradle.kts, android/gradle.properties, apps/popmundo_app/pubspec.yaml and pubspec.lock is empty. Patrol remains a dev_dependency.

## Release APK

Command: flutter build apk --release --target-platform android-x64, with process-only JAVA_TOOL_OPTIONS for the existing Unix-domain-socket workaround. Gradle assembleRelease finished in 86.7s. Output: apps/popmundo_app/build/app/outputs/flutter-apk/app-release.apk, 24709446 bytes, SHA256 03C4FAEE42D5387B4A9BBFF03697E51D64E17B3342D76251F0A05BBA324EB8CD (production-apk-fingerprint.txt, production-release-build.log).

aapt badging: package com.popmundo.popmundo_app, versionCode 1, versionName 1.0.0, minSdk 24, targetSdk 36. Flutter libapp.so and libflutter.so exist only under lib/x86_64. Plugin natives also declare arm64-v8a and armeabi-v7a, so native-code badging alone is not the Flutter ABI evidence. GeneratedPluginRegistrant registers foreground task, inappwebview, local notifications, secure storage, timezone, jni, shared preferences and url launcher. It does not register Patrol (production-plugin-registrant.txt). The release log still warns that the Patrol Gradle plugin applies the Kotlin Gradle Plugin; that warning is the dev-dependency Gradle classpath, not a Patrol runtime class in the registrant.

## Install on emulator-5554

Before install, pm list packages showed only com.popmundo.popmundo_app.backgrounddebug and its test package. dumpsys package com.popmundo.popmundo_app returned Unable to find package (production-before-install.txt, production-before-install-packages.txt). The historical production-before-previous-session.txt values (firstInstallTime 2026-08-20 01:55:00, ceDataInode 368644, deDataInode 156114) are not present on this AVD. This gate did not uninstall, clear or force-stop a production package, because none was installed.

adb install -r of the release APK returned Success (production-install.log). After install, dumpsys reports a new data directory, not an update of the August install:

- firstInstallTime=2026-10-07 01:43:25
- lastUpdateTime=2026-10-07 01:43:25
- ceDataInode=353749
- deDataInode=41024

That is a fresh install. It does not preserve the 2026-08-20 production data, which was already absent.

The first launch stopped on the system notification permission dialog. Allow was tapped. The app then showed the system battery-optimization dialog (Let app always run in background?). Allow was tapped. No game login, item use or crew payment was performed. production-final-service.txt then shows ForegroundService for com.popmundo.popmundo_app with isForeground=true, foregroundId=1000, types=0x40000000 and startRequested=true. Focus returned to MainActivity. The synthetic backgrounddebug packages were left installed; this gate did not clear them.

## Limits

One Android 16 / API 36 / x86_64 emulator. No physical handset, OEM policy, PIN/keyguard, force-stop bypass or overnight run. Seconds-level delivery remains best effort. Device behavior for Home, Recents removal and reboot-while-POST is in t8-device-gates.md: the interrupted attempt stayed skippedInterrupted and only the next future slot confirmed, with the saved character. Independent validation is a separate report in validation.md.
