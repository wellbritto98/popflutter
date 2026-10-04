# Background session reliability validation

Date: 2026-10-04
Spec: .specs/features/background-session-reliability/spec.md
Diff: df248e2^..0a234c1 plus pending documentation finalization
Verifier: independent sub-agent, author differs from verifier
Status: PASS — BSR01-BSR06 verified; production APK upgraded and screen-off retention observed for 74 seconds

## Acceptance outcomes

| Requirement | Spec-defined outcome | Independent evidence | Result |
| --- | --- | --- | --- |
| BSR-01 | Native checks survive paused JavaScript, cache UA; first lookup bounded to 2 seconds | packages/popmundo_utils/test/auto_login_controller_test.dart:559-564 asserts two native requests, exact userAgent, providerCalls=1, evaluateCalls empty; :643-656 asserts exact sticky Character URL/cookies, one UA read, empty progress, unlocked controller; :833-839 asserts a stalled first lookup still probes and unlocks | PASS |
| BSR-02 | Cookies synchronized and done emitted despite paused navigation; request bounded, errors diagnosed | packages/popmundo_utils/test/auto_login_controller_test.dart:675-705 asserts done, exact character, AUTHVALUE cookie, assigned home URL, one UA read, released lock, subsequent native probe; :604-608 asserts navigation-error trace and retained done/cookies | PASS, including independently reverified cross-host correction |
| BSR-03 | One localized result notification, id 2, only non-resumed terminal phases; failures contained | apps/popmundo_app/test/auto_login_notifications_test.dart:54-67 asserts length=1, id=2, exact EN/PT title/body; :82-87 exact failed body/id; :117 empty notifications for foreground and progress; :137 listener works after plugin exception | PASS |
| BSR-04 | Declare/start specialUse, matching permission/subtype, retain stopWithTask=false/wake lock | apps/popmundo_app/test/platform_config_test.dart:19-53 asserts permission, service type/subtype, stopWithTask=false, WAKE_LOCK; :61-64 asserts runtime specialUse and no dataSync; actual initService keeps allowWakeLock=true | PASS static configuration and actual device service (types=0x40000000) |
| BSR-05 | Before reopening, actual background fixture proves native probes, relog/new-host cookies, result tray and FGS ticks | session_background_test.dart:253 waits actual paused lifecycle; :266 and :271 assert old then renewed origin; :282 and :287 advancing ticks/probes; :297 and :302 expired then renewed Cookie headers; :312 done hasLength(1); :317 renewed Android cookie; :326 old-host cookie preserved; :339 tray hasLength(1), :344 exact signed-in character; :350 persistent FGS title. XML session-background-pass.xml records tests=1/failures=0/errors=0/skipped=0 | PASS fresh release session and separate keepalive device runs |
| BSR-06 | Preserve sticky resolution, native HTTP, scopes, secret storage, throttle, foreground feedback | packages/popmundo_utils/test/auto_login_controller_test.dart:199 no in-page fetch; :247-255 exact host-only/HttpOnly cookies; :456 no serialized password; :852-861 old-session header/no www; :897-898 >=750ms; existing snackbar retained app.dart:316-329 | PASS after ea072ea; detailed corrected assertions below |

The original spec's outcomes are sufficiently precise; no spec-precision gaps found. Existing public HostTracker must remain navigation-driven (AD-007); corrective state should be private to native authentication.

## Production wiring inspection

- app.dart:128 supplies InAppWebViewController.getDefaultUserAgent. Installed Android plugin InAppWebViewManager.java:54 calls WebSettings.getDefaultUserAgent(applicationContext); no renderer JavaScript required. WebView settings do not override UA.
- main.dart constructs and initializes LocalNotificationsService and passes it to PopmundoApp. app.dart:163 registers Auto Login status listener before start.
- app.dart:309-315 uses WidgetsBinding.instance.lifecycleState for notification filtering and retains existing Snackbar feedback. Notification helper handles plugin errors.
- Timer is armed before the initial check; shared in-flight lock begins before native settings/cookie reads. FGS remains a separate heartbeat isolate, per existing architecture.
- Device fixture uses fake suspended runtime plus asserted actual Android paused lifecycle, real Android FGS/cookies/tray, and real loopback sockets. Every URL is rewritten before socket open; live game is not reached. This does not prove an actual live page renderer or a full overnight run.

## Independent gates

No tasks.md exists (medium-scope spec lists atomic work). Selected complete package test gates and scoped analyzer gates:

| Gate | Evidence | Outcome |
| --- | --- | --- |
| dart.bat test --reporter expanded, packages/popmundo_utils | Direct verifier run on real implementation | 224 passed, zero failed/skipped after ea072ea |
| flutter.bat test --reporter expanded, apps/popmundo_app | Isolated worktree at e172652, baseline before fault injection | 101 passed, zero failed/skipped |
| dart.bat analyze lib test, packages/popmundo_utils | Direct verifier run | No issues |
| dart.bat analyze lib test integration_test, apps/popmundo_app | Direct verifier run includes new uncommitted device tests | No issues |
| dart.bat test test/auto_login_controller_test.dart | Scratch untouched feature baseline | 44 passed after ea072ea |
| Android builds/instrumentation/APK install | Root execution; persisted XML and production evidence inspected independently | Two fresh release device tests passed; eight mutants killed; production release build/install passed |

Test counts: full utils baseline at 4ec5f50 ran independently in scratch: 216 passed, zero failed; feature: 224 passed, delta +8. App baseline count inferred from six new notification cases: 95 to 101; actual pre-feature full app suite not rerun.

Test integrity: no deleted tests or weakened terminal/cookie/localization assertions in feature diff. Eight controller regressions and six notification tests added. Menu notification fixture changes mirror previously changed Character lookup, retain behavior assertions and avoid undefined fake return maps; no production behavior changed by that fixture commit.

## Discrimination sensor

All mutations ran exclusively in C:/Users/Wellington/Documents/projetos/popflutter-bsr-verifier. Real implementation files were never mutated. Every mutant was restored afterward. Each command invoked actual Dart/Flutter tests; failures were behavioral assertions/timeouts, not syntax/compile errors.

| Mutation | Production seam | Test/result |
| --- | --- | --- |
| M1 Remove UA future cache | auto_login_controller.dart:421 | background probe uses cached UA — killed by exact UA assertion :648 |
| M2 Remove navigation timeout | auto_login_controller.dart:409 | background relog completes — killed by 3s timeout :672 |
| M3 Remove cookie sink write | auto_login_controller.dart:399 | background relog completes — killed by missing AUTHVALUE cookie :678 |
| M4 Remove first UA timeout | auto_login_controller.dart:434 | startup UA timeout — killed by 3s timeout :718 |
| M5 Flip resumed lifecycle exclusion | auto_login_notifications.dart:20 | All six helper tests; five failed for missing background/extraneous foreground notification |

Sensor depth: auth-critical manual run. Initial 5/5 killed; corrective host-routing and navigation-authority mutations add 2/2 killed. Final code sensor 7/7 killed; actual Android notification mutation adds 1/1 killed; combined 8/8, zero survived.

## Initial confirmed gap and completed fix

Priority: Major. BSR-06/continuous background session maintenance.

Before ea072ea, native handshake assigned gameOrigin from landed.finalUrl (auto_login_controller.dart:362), but only requests WebView navigation after completing authentication. If suspended WebView does not report a navigation, runtime.host remains old origin. checkSession chooses runtime.host.currentOrigin (:197), so next tick reads old-host cookies, probes old server and can unnecessarily repeat authentication.

Independent scratch regression: expire session at 75, login assigns 76, keep navigation permanently pending, perform another native tick. Test assertion expects request host 76; actual host is 75. Failure at scratch auto_login_controller_test.dart:686, log verifier-handover-gap.log. Existing paused fixture only uses one host and cannot detect this.

Fix task: retain successful native authenticated origin privately while navigation remains unacknowledged; use it for subsequent cookie reads, probes and renewed login requests. Preserve public HostTracker's real-navigation rule. Cover next-host request and cookie origin, no duplicate relog, plus real subsequent navigation superseding native pending origin. Run full utils tests/analyzer and kill a mutant that bypasses native pending origin.

Task completion: all three atomic work items passed; final documentation/report commit remains orchestrator-owned.

## Limits and follow-up

No full overnight-duration observation performed. Emulator/device functional evidence must not be presented as guaranteed execution after force-stop, reboot or OEM process termination. iOS execution policy unchanged.

Grounded lesson proposed: When authentication changes server while UI navigation can stall, test subsequent native requests and cookie reads against the new authenticated origin. Lesson persistence delegated to root: verifier owns only this report; user forbids Python/scripts that normally maintain lessons.

Root environment note: Java NIO Unix-domain selector initialization failed before compilation. A process-scoped jdk.net.unixdomain.tmpdir pointing to a nonexistent path selects OpenJDK PipeImpl TCP fallback; Gradle build then succeeds. No Gradle/JVM project setting changed. Connected emulator originally had 2 GB RAM and fully exhausted swap; restarted same AVD with 4 GB, no data wipe. Isolated test applicationId preserves production app data. A temporary x86_64 ndk filter did not reduce the debug APK (still 167 MB); no size-reduction success is claimed. Temporary applicationId/ndk settings restored before final delivery.

## Host-handover correction re-verification (iteration 1)

Commit ea072ea retains authenticated origin privately after successful cookie synchronization; native cookie reads/probes and retry login use this origin until actual native navigation supersedes it. Installed WebView adapter in_app_runtime.dart:108 updates HostTracker before emitting navigation, matching corrective clearing logic. Public tracker remains unchanged while final navigation is pending.

Exact regression assertions in packages/popmundo_utils/test/auto_login_controller_test.dart:

- :754 — expect(runtime.host.currentOrigin.host, '75.popmundo.com') after native login on 76.
- :758-759 — expect(auth76.host, '76.popmundo.com'); expect(auth76.isHostOnly, isTrue).
- :764 — expect(nextProbes.map((r) => r.url.host), ['76.popmundo.com', '76.popmundo.com']).
- :766 — expect(nextProbes.every((r) => r.headers['Cookie'] == 'popmundo.com=AUTH76'), isTrue).
- :768 — expect(recordingCookies.readOrigins.skip(1).map((u) => u.host), ['76.popmundo.com', '76.popmundo.com']).
- :779-780 — delayed obsolete 75 login callback leaves last native request on 76; total POST count remains two.
- :795 — expect(server.postTo('76.popmundo.com/Default.aspx'), isNotNull) on renewed expiry.
- :797 — old-server POST count remains one.
- :816-818 — later real navigation restores host 77 for request, AUTH77 Cookie header and cookie source origin.

Independent commands: full utils suite 224 passed; focused controller suite 44 passed; dart analyze lib test clean. Baseline utils216, resulting delta +8.

Additional scratch sensor results:

| Mutation | Change | Result |
| --- | --- | --- |
| M6 | Effective native session origin always returns runtime.host.currentOrigin | Killed at new test:764; next probes incorrectly target 75 |
| M7 | Remove pending-origin clearing after real navigation | Killed at new test:816; next probe incorrectly retains 76 instead of 77 |

Combined sensor: 7 mutations, 7 killed, zero survived. Production source never mutated by verifier. Host gap resolved with independent outcome evidence; session device evidence received below. Separate keepalive and final Android build/install evidence are verified below.

## Android session device evidence (root-owned execution)

Inspected evidence/session-background-pass.xml: one test, zero failures/errors/skips, elapsed 329.207s for session test (suite total330.12s); device Medium_Phone_API_36.1(AVD) Android16. Root ran instrumentation on emulator-5554 under isolated com.popmundo.popmundo_app.backgrounddebug. Verifier inspected XML and test assertions; verifier did not execute Android commands.

Before setting simulated JavaScript to paused, the fixture now waits for WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused at session_background_test.dart:253. All native/cookie/tray assertions occur before openApp at :354. HTTP login hands authentication to a second logical host; every destination is rewritten to loopback before socket opening. Fixture verifies host-only cookie on new host and preservation of old-host expired cookie. It remains a fake renderer and synthetic credentials; actual platform cookies, FGS, native sockets and OS notification are exercised.

Environment: SystemUI ANR initially blocked the notification permission dialog. Root granted POST_NOTIFICATIONS and battery exemption to the isolated test package (matching user-already-granted scenario), dismissed SystemUI ANR, and test then passed. This run does not establish permission-dialog UX reliability on a clean emulator. Bootstrap helper now bounds waiting to30s with notification/battery/service/lifecycle diagnostics instead of allowing an indefinite test hang.

Device mutation M8 confirmed killed below. Separate keepalive and production APK upgrade passed; evidence below. No full overnight claim justified.

## Android discrimination sensor and service type

M8: root suppressed notifyAutoLoginResult notification side effect in scratch only, replacing actual showNotification call with return. Android APK build succeeded; actual device instrumentation failed specifically at the tray assertion. Inspected evidence/notification-mutant-killed.xml: tests=1, failures=1, errors=0, skipped=0; case elapsed41.467s. Failure states Expected length1, Actual WhereIterable<Notification>:[], length0, reason BSR-03/05 background result appears in actual system tray, scratch session_background_test.dart:338. Native probes, reassigned host routing, scoped cookies and tick assertions all precede this assertion and completed. Failure therefore discriminates the real OS notification side effect. Root restored helper afterward; fresh green release device run received below.

Inspected evidence/special-use-service.txt: service for isolated backgrounddebug package reports isForeground=true, foregroundId=1000, types=0x40000000, persistent popmundo_keepalive notification with ONGOING_EVENT and FOREGROUND_SERVICE flags. Actual Android service type matches specialUse, beyond source-string configuration checks. Original SystemUI ANR is visible in this captured dumpsys; it is distinct from app service.

Combined sensors: M1-M7 verifier-owned code mutations plus M8 root-owned actual device mutation =8 injected,8 killed,0 survived. Fresh green, separate keepalive and production APK preservation evidence all passed below.

## Code quality and edge review

| Check | Result |
| --- | --- |
| Scope and minimum implementation | PASS: UA cache/provider, bounded navigation, terminal notification, FGS type and private native origin directly address user request |
| Existing boundaries/style | PASS: pure Dart auth stays Flutter-free; cookies remain adapter-owned; HostTracker remains real-navigation driven |
| No unnecessary abstraction/flexibility | PASS: one injected native UA provider and one private pending-origin field; existing ports reused |
| Spec outcome/test mapping | PASS: new UA/paused-navigation tests map BSR01/02; notification tests BSR03; config tests BSR04; device fixture BSR05; handover/cookie assertions BSR06 |
| Test integrity | PASS: eight added controller cases/six added notification cases; exact UA, cookie, host and localized messages asserted; mutants killed |
| Documentation guidelines | Reviewed CLAUDE.md, TLC validate.md and coding-principles.md; architecture/module docs synchronized by implementers/root |
| Surgical final tree | PASS final Gradle/pubspec/lock diff empty with core.autocrlf=true; temporary test settings removed |

Edge evidence includes first UA failure/timeout with cached fallback, paused final navigation and platform failure, subsequent native probe while JS remains paused, unchanged-host and reassigned-host login, obsolete old login callback, native retry on assigned host, actual later navigation restoring HostTracker, foreground/progress notification exclusion and plugin failure containment. Native probe network error/5xx and disabled/incomplete credentials remain covered by existing suite. CookieSink/plugin storage errors retain preexisting semantics and were not broadened by this feature.

Interactive human UAT and full overnight observation were not conducted; Android functional checks cover native platform behavior with local fixture.

## Fresh green release session after device mutation

Inspected evidence/session-background-release-pass.xml: tests=1, failures=0, errors=0, skipped=0; session case33.874s, suite34.386s, Android16/API36.1 emulator. Root reports this run used the latest bounded helpers and completed permission/battery dialogs automatically, with no manual OS intervention. It follows restoration of the notification side effect after M8 and independently re-establishes the green device functional result.

Release instrumentation used temporary isolated applicationId, testBuildType=release, explicit native Patrol main dependency and disabled minification/resource shrinking for tests. These settings were restored before production APK delivery (verified empty normalized git diff). The earlier debug APK remained167MB despite ndk filtering; release was selected to fit emulator storage. No production Gradle change is intended.

Separate keepalive XML and production upgrade/screen-off evidence were subsequently verified below. All source and device acceptance criteria passed.

## Separate keepalive gate and restoration

Inspected evidence/keepalive-release-pass.xml: tests=1, failures=0, errors=0, skipped=0; case30.649s, suite31.146s on Android16/API36.1. Test asserts two new advancing heartbeats while app remains Home at keepalive_test.dart:112 and :117, persistent FGS notification at :128, and continuing service after reopen at :144. Source is committed in0a234c1. BSR05 now has both native-session and independent keepalive device gates.

Verified git -c core.autocrlf=true diff --exit-code for Android app build.gradle.kts, app pubspec.yaml and root pubspec.lock: exit0, no diff. Original production applicationId restored; testBuildType/ndk filter/minification/Patrol temporary dependencies removed. Ordinary git with WSL autocrlf=false shows only line-ending noise; no semantic build configuration residue remains.

Production Android build/install and screen-off observation subsequently passed below. Earlier normal production attempt failed from stale generated plugin-registration artifact; root restarted build with normal pub resolution/regeneration. No source behavior change resulted.

## Final production delivery evidence and verdict

Inspected evidence/production-build-install.txt: original lib/main.dart entrypoint, normal flutter build apk --release --target-platform android-x64, exit0, assembleRelease26.0s, APK22.4MB. SHA256=9f9da4f0f409e1242a82460b97d5de1eb583fd2d56abaf12a0938424ee249161. Root upgraded original com.popmundo.popmundo_app with adb install -r (Success), launched MainActivity successfully, and did not uninstall/clear original data or wipe emulator. Data preservation is established by the in-place install procedure; raw secret/prefs contents were not exposed or compared by verifier.

Inspected evidence/production-before.txt and production-screen-off.txt: before17:53:58UTC, after17:55:12UTC, same app PID9337 and foreground service record, foregroundId1000, types0x40000000. After74seconds Home/screen-off, PowerManager reports mWakefulness=Asleep while original app service remains foreground with persistent notification. Existing POST_NOTIFICATIONS remains granted. This proves short screen-off retention of delivered app; device fixture proves native relog/cookies/tray behavior before reopening. It does not prove production live-game authentication during that74s or overnight retention.

Final normalized Gradle/pubspec/lock diff independently verified empty again. Isolated instrumentation packages removed by root. The process-scoped Java NIO workaround remains outside project configuration. Delivered APK targets connected x64 Android emulator; other ABIs were not built as part of this device debug.

Final verdict: PASS. Acceptance outcomes6/6 matched spec; full utils224 passed, app101 passed, focused controller44 passed, scoped analyzers clean, two fresh release device cases passed with zero failures/errors/skips, eight mutations killed and zero survived, final production build/in-place upgrade successful. One Major host-handover defect discovered independently was fixed in ea072ea and reverified; no unresolved code gaps remain.

Limits: functional Android16 emulator evidence and74second production screen-off observation; no full overnight run, no live-site credential fixture, no force-stop/reboot/OEM-kill guarantee, iOS policy unchanged, Google Play specialUse review remains distribution-dependent. Interactive human UAT not performed. Final documentation/decision-log commit handled by root; verifier preserved .specs/STATE.md and edited only this report.
