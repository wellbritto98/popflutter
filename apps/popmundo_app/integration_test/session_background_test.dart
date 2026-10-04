// Exactly one Patrol test. No game page, app entrypoint, or real credentials.
// BSR-05: real FGS/isolate, Android cookies, loopback HTTP, and system tray.
// JS is deliberately suspended after Home to reproduce a paused renderer.
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/autologin/auto_login_notifications.dart';
import 'package:popmundo_app/background/background_keepalive.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/l10n.dart';
import 'package:popmundo_app/notifications/local_notifications_service.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'support/harness.dart';

const _origin = 'https://e2e-background.popmundo.com';
const _renewedOrigin = 'https://e2e-renewed-background.popmundo.com';
const _cookieName = 'popflutter_e2e_background';
const _userAgent = 'Mozilla/5.0 Android PopflutterBackgroundE2E/1.0';
const _character = 'Background Fixture';

void main() {
  patrolTest(
    'session: native login and notification finish while JS is paused',
    ($) async {
      initForegroundComms();
      await EasyLocalization.ensureInitialized();
      await $.pumpWidgetAndSettle(
        EasyLocalization(
          supportedLocales: supportedAppLocales,
          path: kTranslationsPath,
          fallbackLocale: fallbackAppLocale,
          startLocale: const Locale('en'),
          saveLocale: false,
          useOnlyLangCode: true,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const Scaffold(body: Text('background session harness')),
            ),
          ),
        ),
      );

      final platform = FlutterForegroundTaskPlatform();
      final keepalive = BackgroundKeepalive(platform: platform);
      addTearDown(keepalive.dispose);
      addTearDown(stopKeepaliveService);
      final bootstrap = keepalive.bootstrap();
      await grantNotificationsIfAsked($);
      await grantBackgroundExemptionIfAsked($);
      await waitForKeepaliveBootstrap(bootstrap, keepalive.status);
      expect(
        await platform.isRunningService(),
        isTrue,
        reason: 'BSR-05: real foreground service must start before Home',
      );

      final notifications = LocalNotificationsService();
      await notifications.initialize();
      expect(
        await notifications.requestPermission(),
        isTrue,
        reason: 'BSR-05: tray assertions need actual notification permission',
      );
      addTearDown(
        () => FlutterLocalNotificationsPlugin().cancel(
          id: kAutoLoginNotificationId,
        ),
      );

      final cookieManager = CookieManager.instance();
      addTearDown(() async {
        for (final origin in [_origin, _renewedOrigin]) {
          await cookieManager.deleteCookie(
            url: WebUri(origin),
            name: _cookieName,
          );
        }
      });
      final cookieJar = InAppCookieSink();
      await cookieJar.write([
        GameCookie(
          name: _cookieName,
          value: 'expired-fixture',
          host: Uri.parse(_origin).host,
          secure: true,
          httpOnly: true,
        ),
      ]);
      expect(
        (await cookieJar.read(Uri.parse(_origin)))
            .where((cookie) => cookie.name == _cookieName)
            .single
            .value,
        'expired-fixture',
        reason: 'BSR-05: baseline cookie must exist in real Android jar',
      );

      final runtime = _PausedRuntime();
      addTearDown(runtime.dispose);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sender = IoAuthHttpSender();
      addTearDown(sender.close);
      var expired = false;
      var probes = 0;
      final backgroundProbes = <DateTime>[];
      final userAgents = <String?>[];
      final backgroundCookieHeaders = <String?>[];
      final backgroundProbeUrls = <Uri>[];

      // Rewrite EVERY destination before opening a socket. Logical URLs retain
      // HostTracker/AuthSession semantics; no game hostname ever reaches DNS.
      Future<AuthHttpResponse> send(AuthHttpRequest request) {
        if (runtime.paused &&
            request.url.path == AutoLoginController.characterPath) {
          backgroundProbeUrls.add(request.url);
        }
        final loopback = Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: server.port,
          path: request.url.path,
          query: request.url.hasQuery ? request.url.query : null,
        );
        return sender.call(
          AuthHttpRequest(
            url: loopback,
            method: request.method,
            headers: request.headers,
            body: request.body,
          ),
        );
      }

      server.listen((request) async {
        userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
        final response = request.response;
        final path = request.uri.path;
        if (path == AutoLoginController.characterPath) {
          probes++;
          if (runtime.paused) {
            backgroundProbes.add(DateTime.now());
            backgroundCookieHeaders.add(
              request.headers.value(HttpHeaders.cookieHeader),
            );
          }
          if (expired) {
            response.statusCode = HttpStatus.found;
            response.headers.set(HttpHeaders.locationHeader, '/Default.aspx');
          } else {
            response.write('<html>session alive</html>');
          }
        } else if (path == '/Default.aspx' && request.method == 'GET') {
          response.write(_loginHtml);
        } else if (path == "/Default.aspx" && request.method == "POST") {
          await request.drain<void>();
          response.statusCode = HttpStatus.found;
          response.headers.set(
            HttpHeaders.locationHeader,
            "https://e2e-renewed-background.popmundo.com/Login.aspx",
          );
        } else if (path == "/Login.aspx" && request.method == "GET") {
          response.statusCode = HttpStatus.found;
          response.headers.set(
            HttpHeaders.locationHeader,
            AutoLoginController.chooseCharacterPath,
          );
          response.headers.add(
            HttpHeaders.setCookieHeader,
            "popflutter_e2e_background=renewed-fixture; Path=/; Secure; HttpOnly",
          );
        } else if (path == AutoLoginController.chooseCharacterPath &&
            request.method == 'GET') {
          response.write(_chooseHtml);
        } else if (path == AutoLoginController.chooseCharacterPath &&
            request.method == 'POST') {
          await request.drain<void>();
          expired = false;
          response.statusCode = HttpStatus.found;
          response.headers.set(
            HttpHeaders.locationHeader,
            AutoLoginController.worldHomePath,
          );
        } else if (path == AutoLoginController.worldHomePath) {
          response.write('<html>signed in</html>');
        } else {
          response.statusCode = HttpStatus.notFound;
        }
        await response.close();
      });

      final settings = AutoLoginSettingsStore(MemoryKeyValueStore());
      await settings.save(
        const AutoLoginSettings(
          enabled: true,
          username: 'fixture-user',
          characterName: _character,
        ),
      );
      final secrets = MemorySecretStore();
      await secrets.write(
        AutoLoginSettingsStore.passwordSecretKey,
        'fixture-password-not-a-real-secret',
      );
      final controller = AutoLoginController(
        runtime: runtime,
        settingsStore: settings,
        secretStore: secrets,
        cookieSink: cookieJar,
        cookieSource: cookieJar,
        authSend: send,
        heartbeatInterval: const Duration(seconds: 3),
      );
      addTearDown(controller.dispose);
      final statuses = <AutoLoginStatus>[];
      var notificationPosted = false;
      final statusSubscription = controller.status.listen((status) async {
        statuses.add(status);
        await notifyAutoLoginResult(
          status: status,
          lifecycle: runtime.paused
              ? AppLifecycleState.paused
              : AppLifecycleState.resumed,
          notificationService: notifications,
        );
        if (status.phase == AutoLoginPhase.done) notificationPosted = true;
      });
      addTearDown(statusSubscription.cancel);
      controller.start();
      await waitUntil(
        () async => probes >= 1,
        description: 'foreground session probe and user-agent priming',
      );
      expect(
        runtime.userAgentReads,
        1,
        reason: 'BSR-01: UA captured once while renderer is available',
      );
      final ticksBeforeHome = await waitForTicks(keepalive.status);

      await $.platform.mobile.pressHome();
      await waitUntil(
        () async =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused,
        description: "Android paused lifecycle after Home",
      );
      runtime.paused = true;
      expired = true;
      await waitUntil(
        () async => notificationPosted && backgroundProbes.length >= 2,
        description: 'two background probes, native relogin and notification',
        timeout: const Duration(seconds: 45),
      );
      expect(
        backgroundProbeUrls.first.origin,
        _origin,
        reason: "BSR-05: expired probe must use original host",
      );
      expect(
        backgroundProbeUrls.last.origin,
        _renewedOrigin,
        reason: "BSR-05: later native probe must use newly authenticated host",
      );
      expect(
        runtime.host.currentOrigin.toString(),
        _origin,
        reason: "BSR-06: frozen navigation must not mutate page HostTracker",
      );
      final ticksAtHome = await waitForTicks(keepalive.status);
      expect(
        ticksAtHome.first.isAfter(ticksBeforeHome.last),
        isTrue,
        reason: 'BSR-05: FGS ticks advance before app is reopened',
      );
      expect(
        backgroundProbes[1].isAfter(backgroundProbes[0]),
        isTrue,
        reason: 'BSR-01/05: native session checks recur while app remains Home',
      );
      expect(
        runtime.userAgentReads,
        1,
        reason: 'BSR-01: paused renderer must never be queried again for UA',
      );
      expect(
        backgroundCookieHeaders.first,
        contains('popflutter_e2e_background=expired-fixture'),
        reason: 'BSR-05: first background probe reads actual expired cookie',
      );
      expect(
        backgroundCookieHeaders.last,
        contains('popflutter_e2e_background=renewed-fixture'),
        reason: 'BSR-05: later background probe reads actual renewed cookie',
      );
      expect(
        userAgents,
        everyElement(_userAgent),
        reason: 'BSR-01: all native requests reuse original renderer UA',
      );
      expect(
        statuses.where((status) => status.phase == AutoLoginPhase.done),
        hasLength(1),
        reason: 'BSR-02: expired session finishes exactly one login',
      );
      expect(
        (await cookieJar.read(Uri.parse(_renewedOrigin)))
            .where((cookie) => cookie.name == _cookieName)
            .single
            .value,
        'renewed-fixture',
        reason: 'BSR-02/05: relogin syncs renewed cookie into real Android jar',
      );

      expect(
        (await cookieJar.read(Uri.parse(_origin)))
            .where((cookie) => cookie.name == _cookieName)
            .single
            .value,
        "expired-fixture",
        reason: "BSR-06: host-only renewed cookie must not replace original host cookie",
      );
      await $.platform.mobile.openNotifications();
      final tray = await $.platform.mobile.getNotifications();
      final posted = tray.where(
        (notification) => notification.title == 'Auto Login',
      );
      expect(
        posted,
        hasLength(1),
        reason: 'BSR-03/05: background result appears in actual system tray',
      );
      expect(
        posted.single.content,
        'Signed in as Background Fixture',
        reason: 'BSR-03/05: system notification names completed character',
      );
      expect(
        tray.map((notification) => notification.title),
        contains(keepaliveNotificationTitle),
        reason: 'BSR-05: session work preserves persistent FGS notification',
      );
      await $.platform.mobile.pressHome();
      await $.platform.mobile.openApp();
    },
  );
}

class _PausedRuntime implements PopmundoRuntime {
  _PausedRuntime() {
    host.onNavigation(Uri.parse(_origin));
  }
  bool paused = false;
  int userAgentReads = 0;
  final _blockedJs = Completer<String?>();
  @override
  final host = HostTracker();
  @override
  final events = PopmundoEventBus();
  @override
  Future<String?> evaluate(String source) async {
    userAgentReads++;
    if (paused) return _blockedJs.future;
    return _userAgent;
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (paused) await _blockedJs.future;
  }

  @override
  Future<void> loadUrl(Uri url) async {
    if (paused) await _blockedJs.future;
  }

  @override
  Future<InPageFetchResult> fetchInPage({
    required String url,
    Map<String, dynamic>? options,
  }) => throw StateError('Session device test must never use in-page HTTP');
  Future<void> dispose() async {
    if (!_blockedJs.isCompleted) _blockedJs.complete(_userAgent);
    await events.dispose();
  }
}

const _loginHtml = r'''
<form id="aspnetForm">
<input type="hidden" name="__VIEWSTATE" value="fixture" />
<input name="ctl00&#36;cphRightColumn&#36;ucLogin&#36;txtUsername" />
<input name="ctl00&#36;cphRightColumn&#36;ucLogin&#36;txtPassword" type="password" />
<input type="submit" name="ctl00&#36;cphRightColumn&#36;ucLogin&#36;btnLogin" value="Login" />
</form>
''';
const _chooseHtml = r'''
<form id="aspnetForm">
<input type="hidden" name="__VIEWSTATE" value="fixture" />
<div class="box"><h2>Background Fixture</h2>
<input type="submit" name="ctl00&#36;cphLeftColumn&#36;repCharacters&#36;ctl00&#36;btnChooseCharacter2" value="Choose" />
</div></form>
''';
