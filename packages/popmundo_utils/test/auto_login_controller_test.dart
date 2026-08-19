import 'dart:async';
import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

const userAgent = 'Mozilla/5.0 (Linux; Android 16) TestWebView/1.0';

/// Login page as the game serves it: three tokens, the login controls, a status
/// select and a language field a token-only body would drop.
const loginHtml = r'''
<html><body><form id="aspnetForm">
<input type="hidden" name="__VIEWSTATE" value="VS" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN" />
<input type="hidden" name="__EVENTVALIDATION" value="EV" />
<input name="ctl00$cphRightColumn$ddlLanguage" type="hidden" value="50" />
<input id="ctl00_cphRightColumn_ucLogin_txtUsername" name="ctl00$cphRightColumn$ucLogin$txtUsername" />
<input name="ctl00$cphRightColumn$ucLogin$txtPassword" type="password" />
<select name="ctl00$cphRightColumn$ucLogin$ddlStatus">
  <option selected="selected" value="0">Normal</option>
  <option value="2">Mobile</option>
</select>
<input type="submit" name="ctl00$cphRightColumn$ucLogin$btnLogin" value="OK!" />
</form></body></html>
''';

/// Seven characters sharing a surname, as on the real account.
const chooseHtml = r'''
<html><body><form id="aspnetForm">
<input type="hidden" name="__EVENTTARGET" value="" />
<input type="hidden" name="__EVENTARGUMENT" value="" />
<input type="hidden" name="__VIEWSTATE" value="VS2" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN2" />
<input type="hidden" name="__EVENTVALIDATION" value="EV2" />
<div class="box">
  <h2>Peter Drinkwater</h2>
  <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2" value="Escolher Peter" />
</div>
<div class="box">
  <h2>Deon Drinkwater</h2>
  <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl02$btnChooseCharacter2" value="Escolher Deon" />
</div>
</form></body></html>
''';

const worldHomeHtml = '<html><body><div id="world">home</div></body></html>';

const targetButton =
    r'ctl00$cphLeftColumn$repCharacters$ctl02$btnChooseCharacter2';

/// Replays a scripted game server over the native transport.
class _FakeServer {
  final routes = <String, AuthHttpResponse>{};
  final seen = <AuthHttpRequest>[];

  Future<AuthHttpResponse> call(AuthHttpRequest req) async {
    seen.add(req);
    final route = routes['${req.method} ${req.url}'];
    if (route == null) {
      throw AuthHttpException('no route for ${req.method} ${req.url}');
    }
    return route;
  }

  AuthHttpRequest? postTo(String needle) {
    for (final r in seen) {
      if (r.method == 'POST' && r.url.toString().contains(needle)) return r;
    }
    return null;
  }
}

void main() {
  late FakePopmundoRuntime runtime;
  late MemoryKeyValueStore kv;
  late MemorySecretStore secrets;
  late AutoLoginSettingsStore settingsStore;
  late MemoryCookieSink cookies;
  late AutoLoginController controller;
  late List<AutoLoginStatus> statuses;
  late List<String> trace;
  late _FakeServer server;

  String traceText() => trace.join('\n');

  /// Whole happy chain: login on www, handover to 75, choose, land on home.
  void wireHappyPath({
    String chooseCharacterPage = chooseHtml,
    String loginPage = loginHtml,
  }) {
    server.routes.addAll({
      'GET https://www.popmundo.com/':
          AuthHttpResponse(status: 200, body: loginPage),
      'POST https://www.popmundo.com/': const AuthHttpResponse(
        status: 302,
        body: '',
        setCookieHeaders: [
          'ASP.NET_SessionId=wwwsession; path=/; HttpOnly; SameSite=Lax',
        ],
        location: 'https://75.popmundo.com//Login.aspx?t=TOKEN',
      ),
      'GET https://75.popmundo.com//Login.aspx?t=TOKEN': const AuthHttpResponse(
        status: 302,
        body: '',
        setCookieHeaders: [
          'ASP.NET_SessionId=n75session; path=/; HttpOnly; SameSite=Lax',
          'popmundo.com=AUTHVALUE; path=/; HttpOnly; SameSite=Lax',
        ],
        location: '/World/Popmundo.aspx/ChooseCharacter',
      ),
      'GET https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter':
          AuthHttpResponse(status: 200, body: chooseCharacterPage),
      'POST https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter':
          const AuthHttpResponse(
        status: 302,
        body: '',
        location: '/World/Popmundo.aspx',
      ),
      'GET https://75.popmundo.com/World/Popmundo.aspx':
          const AuthHttpResponse(status: 200, body: worldHomeHtml),
    });
  }

  Future<void> navigateToLogin() async {
    runtime.host.onNavigation(Uri.parse('https://www.popmundo.com/'));
    runtime.events
        .emitNavigation(NavigationEvent(url: 'https://www.popmundo.com/'));
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    server = _FakeServer();
    runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (source) =>
        source.contains('navigator.userAgent') ? userAgent : 'ok';
    kv = MemoryKeyValueStore();
    secrets = MemorySecretStore();
    settingsStore = AutoLoginSettingsStore(kv);
    cookies = MemoryCookieSink();
    trace = [];
    controller = AutoLoginController(
      runtime: runtime,
      settingsStore: settingsStore,
      secretStore: secrets,
      cookieSink: cookies,
      cookieSource: cookies,
      trace: trace.add,
      sleep: (_) async {},
      authSend: server.call,
      heartbeatInterval: const Duration(days: 1),
    );
    statuses = [];
    controller.status.listen(statuses.add);
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: true,
        username: 'troyfournier',
        characterName: 'Deon Drinkwater',
        status: 2,
      ),
    );
    await secrets.write(AutoLoginSettingsStore.passwordSecretKey, 'test-password-not-real');
    controller.start();
    // Drain the initial heartbeat tick (www skip) so tests that then move
    // the sticky host do not race the first checkSession.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  });

  tearDown(() async {
    await controller.dispose();
  });

  group('native handshake', () {
    test('signs in and lands on the world home of the assigned host', () async {
      wireHappyPath();
      await navigateToLogin();

      expect(runtime.loadUrlCalls.map((u) => u.toString()), [
        'https://75.popmundo.com/World/Popmundo.aspx',
      ], reason: 'the host comes from where the chain ended, not from www');
      expect(controller.inFlight, isFalse);
    });

    test('never navigates the WebView through the login pages', () async {
      wireHappyPath();
      await navigateToLogin();

      expect(
        runtime.evaluateCalls.where((s) => s.contains('form.submit()')),
        isEmpty,
        reason: 'a visible form submit would defeat the whole point',
      );
      expect(runtime.fetchCalls, isEmpty,
          reason: 'no in-page fetch: CORS is exactly what we are avoiding');
      expect(runtime.loadUrlCalls.length, 1);
    });

    test('the login POST carries the whole form, not just the tokens',
        () async {
      wireHappyPath();
      await navigateToLogin();

      final post = server.postTo('www.popmundo.com/');
      final fields = Uri.splitQueryString(post!.body!);
      expect(fields['__VIEWSTATE'], 'VS');
      expect(fields['__EVENTVALIDATION'], 'EV');
      expect(fields[r'ctl00$cphRightColumn$ddlLanguage'], '50',
          reason: 'a token-only body would drop this');
      expect(fields[r'ctl00$cphRightColumn$ucLogin$txtUsername'],
          'troyfournier');
      expect(fields[r'ctl00$cphRightColumn$ucLogin$txtPassword'], 'test-password-not-real');
      expect(fields[r'ctl00$cphRightColumn$ucLogin$ddlStatus'], '2',
          reason: 'the configured status overrides the selected option');
      expect(fields[r'ctl00$cphRightColumn$ucLogin$btnLogin'], 'OK!');
    });

    test('the choice POST picks the matched button on the assigned host',
        () async {
      wireHappyPath();
      await navigateToLogin();

      final post = server.postTo('ChooseCharacter');
      expect(post!.url.toString(),
          'https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter');
      final fields = Uri.splitQueryString(post.body!);
      expect(fields[targetButton], 'Escolher Deon');
      expect(
        fields.containsKey(
            r'ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2'),
        isFalse,
        reason: 'Peter must not be chosen',
      );
      expect(fields['__VIEWSTATE'], 'VS2',
          reason: 'tokens come from the ChooseCharacter document');
    });

    test('copies the session cookies into the WebView jar', () async {
      wireHappyPath();
      await navigateToLogin();

      final auth =
          cookies.written.firstWhere((c) => c.name == 'popmundo.com');
      expect(auth.value, 'AUTHVALUE');
      expect(auth.host, '75.popmundo.com',
          reason: 'the auth cookie belongs to the assigned host');
      expect(auth.isHostOnly, isTrue,
          reason: 'writing a domain would create a different cookie');
      expect(auth.httpOnly, isTrue);
      expect(cookies.written.map((c) => c.name), contains('ASP.NET_SessionId'));
    });

    test('syncs cookies before navigating, or the load is unauthenticated',
        () async {
      wireHappyPath();
      await navigateToLogin();

      final syncedAt = trace.indexWhere((l) => l.startsWith('syncing '));
      final navigatedAt = trace.indexWhere((l) => l.startsWith('DONE'));
      expect(syncedAt, isNonNegative);
      expect(navigatedAt, greaterThan(syncedAt));
    });

    test('sends the WebView user agent, not the Dart default', () async {
      wireHappyPath();
      await navigateToLogin();
      expect(server.seen.every((r) => r.headers['User-Agent'] == userAgent),
          isTrue);
    });

    test('emits detected, authenticating, choosing, done', () async {
      wireHappyPath();
      await navigateToLogin();

      expect(statuses.map((s) => s.phase), [
        AutoLoginPhase.detected,
        AutoLoginPhase.authenticating,
        AutoLoginPhase.choosingCharacter,
        AutoLoginPhase.done,
      ]);
      expect(statuses.last.characterName, 'Deon Drinkwater');
    });
  });

  group('aborts', () {
    Future<void> expectAbort(AutoLoginFailure failure) async {
      await navigateToLogin();
      expect(runtime.loadUrlCalls, isEmpty);
      expect(controller.inFlight, isFalse);
      expect(statuses.last.phase, AutoLoginPhase.failed);
      expect(statuses.last.failure, failure);
    }

    test('landing back on the login page means bad credentials', () async {
      wireHappyPath();
      server.routes['POST https://www.popmundo.com/'] =
          const AuthHttpResponse(status: 200, body: loginHtml);
      await expectAbort(AutoLoginFailure.invalidCredentials);
      expect(cookies.written, isEmpty);
    });

    test('a login page without a form aborts', () async {
      server.routes['GET https://www.popmundo.com/'] =
          const AuthHttpResponse(status: 200, body: '<html>nope</html>');
      await expectAbort(AutoLoginFailure.missingForm);
    });

    test('zero character boxes aborts', () async {
      wireHappyPath(
          chooseCharacterPage:
              '<html><body><form id="aspnetForm"></form></body></html>');
      await expectAbort(AutoLoginFailure.noCharacters);
    });

    test('a first name alone no longer matches anything', () async {
      await settingsStore.save(const AutoLoginSettings(
          enabled: true,
          username: 'troyfournier',
          characterName: 'Deon',
          status: 0));
      wireHappyPath();
      await expectAbort(AutoLoginFailure.characterNotFound);
    });

    test('duplicate full names abort instead of guessing', () async {
      wireHappyPath(
        chooseCharacterPage: chooseHtml.replaceFirst(
            '<h2>Peter Drinkwater</h2>', '<h2>Deon Drinkwater</h2>'),
      );
      await expectAbort(AutoLoginFailure.characterAmbiguous);
    });

    test('staying on ChooseCharacter after the POST is a rejection', () async {
      wireHappyPath();
      server.routes[
              'POST https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter'] =
          AuthHttpResponse(status: 200, body: chooseHtml);
      await expectAbort(AutoLoginFailure.serverRejected);
      expect(cookies.written, isEmpty,
          reason: 'a failed choice must not sign the WebView in');
    });
  });

  group('guards', () {
    Future<void> expectNoCycle() async {
      wireHappyPath();
      await navigateToLogin();
      expect(server.seen, isEmpty);
      expect(statuses, isEmpty);
    }

    test('disabled setting does nothing', () async {
      await settingsStore.save(const AutoLoginSettings(
          enabled: false,
          username: 'troyfournier',
          characterName: 'Deon Drinkwater',
          status: 0));
      await expectNoCycle();
    });

    test('missing character name does nothing', () async {
      await settingsStore.save(const AutoLoginSettings(
          enabled: true,
          username: 'troyfournier',
          characterName: '',
          status: 0));
      await expectNoCycle();
    });

    test('missing password does nothing', () async {
      await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
      await expectNoCycle();
    });

    test('a second trigger while in flight is ignored', () async {
      wireHappyPath();
      runtime.host.onNavigation(Uri.parse('https://www.popmundo.com/'));
      runtime.events
          .emitNavigation(NavigationEvent(url: 'https://www.popmundo.com/'));
      runtime.events.emitNavigation(
          NavigationEvent(url: 'https://www.popmundo.com/Default.aspx'));
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final logins =
          server.seen.where((r) => r.method == 'POST' && r.url.host == 'www.popmundo.com');
      expect(logins.length, 1);
    });
  });

  group('diagnostics', () {
    test('traces the chain without ever logging the password', () async {
      wireHappyPath();
      await navigateToLogin();

      expect(traceText(), contains('native handshake from'));
      expect(traceText(), contains('login chain:'));
      expect(traceText(), contains('logged in on 75.popmundo.com'));
      expect(traceText(), contains('choose: matched "Deon Drinkwater"'));
      expect(traceText(), contains('syncing 3 cookie(s)'));

      expect(trace.any((l) => l.contains('txtPassword')), isTrue);
      expect(traceText(), isNot(contains('test-password-not-real')));
      expect(traceText(), contains('masked'));
    });

    test('a failed match logs the candidates and dumps the page', () async {
      await settingsStore.save(const AutoLoginSettings(
          enabled: true,
          username: 'troyfournier',
          characterName: 'Nobody Here',
          status: 0));
      wireHappyPath();
      await navigateToLogin();

      expect(traceText(), contains('choose: NO MATCH'));
      expect(traceText(), contains('"deon drinkwater"'));
      expect(traceText(), contains('div.box: 2'));
      expect(traceText(), contains('page-html'));
      expect(traceText(), contains('ABORT characterNotFound'));
    });

    test('a page dump never contains the password', () async {
      // A response that echoes the submitted credentials back into the markup.
      wireHappyPath();
      server.routes['POST https://www.popmundo.com/'] = const AuthHttpResponse(
        status: 200,
        body: '<html><body>'
            r'<input id="ctl00_cphRightColumn_ucLogin_txtUsername" value="troyfournier">'
            r'<input name="ctl00$cphRightColumn$ucLogin$txtPassword" value="test-password-not-real">'
            '</body></html>',
      );
      await navigateToLogin();

      expect(traceText(), contains('login-response-html'),
          reason: 'the page was dumped');
      expect(traceText(), contains('troyfournier'),
          reason: 'the dump is otherwise intact');
      expect(traceText(), contains('<redacted>'));
      expect(traceText(), isNot(contains('test-password-not-real')));
    });
  });

  test('settings serialization never leaks the password', () {
    const settings = AutoLoginSettings(
        enabled: true,
        username: 'troyfournier',
        characterName: 'Deon Drinkwater',
        status: 0);
    final json = jsonDecode(encodeSettingsWithoutSecrets(settings)) as Map;
    expect(json.containsKey('password'), isFalse);
  });

  group('session heartbeat', () {
    const characterUrl =
        'https://75.popmundo.com/World/Popmundo.aspx/Character';

    test('interval defaults to 60 seconds', () async {
      final fresh = AutoLoginController(
        runtime: runtime,
        settingsStore: settingsStore,
        secretStore: secrets,
      );
      expect(fresh.heartbeatInterval, const Duration(seconds: 60));
      await fresh.dispose();
    });

    void onGameHost() {
      runtime.host.onNavigation(
          Uri.parse('https://75.popmundo.com/World/Popmundo.aspx'));
      cookies.seed([
        const GameCookie(
          name: 'popmundo.com',
          value: 'OLDSESSION',
          host: '75.popmundo.com',
          httpOnly: true,
          secure: true,
        ),
      ]);
    }

    void wireLogoutOn75() {
      server.routes.addAll({
        'GET $characterUrl': const AuthHttpResponse(
          status: 302,
          body: '',
          location: '/Default.aspx',
        ),
        'GET https://75.popmundo.com/Default.aspx':
            AuthHttpResponse(status: 200, body: loginHtml),
        'POST https://75.popmundo.com/Default.aspx': const AuthHttpResponse(
          status: 302,
          body: '',
          setCookieHeaders: [
            'ASP.NET_SessionId=n75session; path=/; HttpOnly; SameSite=Lax',
            'popmundo.com=AUTHVALUE; path=/; HttpOnly; SameSite=Lax',
          ],
          location: '/World/Popmundo.aspx/ChooseCharacter',
        ),
        'GET https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter':
            AuthHttpResponse(status: 200, body: chooseHtml),
        'POST https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter':
            const AuthHttpResponse(
          status: 302,
          body: '',
          location: '/World/Popmundo.aspx',
        ),
        'GET https://75.popmundo.com/World/Popmundo.aspx':
            const AuthHttpResponse(status: 200, body: worldHomeHtml),
      });
    }

    test('302 to Default.aspx renews the session on the sticky host', () async {
      onGameHost();
      wireLogoutOn75();
      await controller.checkSession();

      expect(
        server.seen.first.url.toString(),
        characterUrl,
        reason: 'HB-06: path from currentOrigin.replace, no trailing slash',
      );
      expect(server.seen.first.headers['Cookie'], contains('OLDSESSION'));
      expect(
        server.seen.any((r) => r.url.host == 'www.popmundo.com'),
        isFalse,
        reason: 'login stays on 75, the sticky game host',
      );
      expect(server.postTo('75.popmundo.com/Default.aspx'), isNotNull);
      expect(runtime.loadUrlCalls.map((u) => u.toString()), [
        'https://75.popmundo.com/World/Popmundo.aspx',
      ]);
    });

    test('probe then handshake waits at least 750ms', () async {
      final clock = _HbClock();
      final seenAt = <String, DateTime>{};
      await controller.dispose();
      controller = AutoLoginController(
        runtime: runtime,
        settingsStore: settingsStore,
        secretStore: secrets,
        cookieSink: cookies,
        cookieSource: cookies,
        trace: trace.add,
        now: () => clock.now,
        sleep: clock.sleep,
        heartbeatInterval: const Duration(days: 1),
        authSend: (req) async {
          seenAt[req.url.toString()] = clock.now;
          return server.call(req);
        },
      );
      statuses = [];
      controller.status.listen(statuses.add);
      controller.start();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      onGameHost();
      wireLogoutOn75();
      await controller.checkSession();

      final characterAt = seenAt[characterUrl];
      final loginAt = seenAt['https://75.popmundo.com/Default.aspx'];
      expect(characterAt, isNotNull);
      expect(loginAt, isNotNull);
      expect(loginAt!.difference(characterAt!).inMilliseconds,
          greaterThanOrEqualTo(750));
    });

    test('200 means the session is healthy', () async {
      onGameHost();
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 200, body: '<html>character</html>');
      await controller.checkSession();

      expect(server.seen.length, 1);
      expect(server.seen.single.url.toString(), characterUrl);
      expect(runtime.loadUrlCalls, isEmpty);
      expect(statuses, isEmpty);
    });

    test('does not follow the 302 to Default.aspx as part of the probe',
        () async {
      onGameHost();
      server.routes['GET $characterUrl'] = const AuthHttpResponse(
        status: 302,
        body: '',
        location: '/World/Popmundo.aspx/Other',
      );
      server.routes['GET https://75.popmundo.com/Default.aspx'] =
          const AuthHttpResponse(status: 200, body: loginHtml);
      await controller.checkSession();

      expect(server.seen.length, 1, reason: 'non-login 302 is not logout');
      expect(runtime.loadUrlCalls, isEmpty);
    });

    test('www host is not probed', () async {
      cookies.seed([
        const GameCookie(
          name: 'popmundo.com',
          value: 'WWW',
          host: 'www.popmundo.com',
        ),
      ]);
      await controller.checkSession();
      expect(server.seen, isEmpty);
    });

    test('disabled auto-login does not GET Character', () async {
      onGameHost();
      await settingsStore.save(const AutoLoginSettings(
          enabled: false,
          username: 'troyfournier',
          characterName: 'Deon Drinkwater',
          status: 0));
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 302, body: '', location: '/Default.aspx');
      await controller.checkSession();
      expect(server.seen, isEmpty);
    });

    test('missing username does not GET Character', () async {
      onGameHost();
      await settingsStore.save(const AutoLoginSettings(
          enabled: true,
          username: '',
          characterName: 'Deon Drinkwater',
          status: 0));
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 302, body: '', location: '/Default.aspx');
      await controller.checkSession();
      expect(server.seen, isEmpty);
    });

    test('missing character name does not GET Character', () async {
      onGameHost();
      await settingsStore.save(const AutoLoginSettings(
          enabled: true,
          username: 'troyfournier',
          characterName: '',
          status: 0));
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 302, body: '', location: '/Default.aspx');
      await controller.checkSession();
      expect(server.seen, isEmpty);
    });

    test('missing password does not GET Character', () async {
      onGameHost();
      await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 302, body: '', location: '/Default.aspx');
      await controller.checkSession();
      expect(server.seen, isEmpty);
    });

    test('network error is not logout', () async {
      onGameHost();
      await controller.checkSession();
      expect(runtime.loadUrlCalls, isEmpty);
      expect(statuses, isEmpty);
    });

    test('5xx is not logout', () async {
      onGameHost();
      server.routes['GET $characterUrl'] =
          const AuthHttpResponse(status: 503, body: 'down');
      await controller.checkSession();
      expect(runtime.loadUrlCalls, isEmpty);
      expect(statuses, isEmpty);
    });

    test('CookieSource throw skips the tick', () async {
      await controller.dispose();
      controller = AutoLoginController(
        runtime: runtime,
        settingsStore: settingsStore,
        secretStore: secrets,
        cookieSink: cookies,
        cookieSource: _ThrowingCookies(),
        trace: trace.add,
        sleep: (_) async {},
        authSend: server.call,
        heartbeatInterval: const Duration(days: 1),
      );
      statuses = [];
      controller.status.listen(statuses.add);
      controller.start();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      onGameHost();
      await controller.checkSession();
      expect(server.seen, isEmpty);
      expect(runtime.loadUrlCalls, isEmpty);
    });

    test('inFlight probe ignores a second tick', () async {
      final held = Completer<AuthHttpResponse>();
      var characterGets = 0;
      await controller.dispose();
      controller = AutoLoginController(
        runtime: runtime,
        settingsStore: settingsStore,
        secretStore: secrets,
        cookieSink: cookies,
        cookieSource: cookies,
        trace: trace.add,
        sleep: (_) async {},
        heartbeatInterval: const Duration(days: 1),
        authSend: (req) async {
          if (req.url.toString() == characterUrl) {
            characterGets++;
            return held.future;
          }
          return server.call(req);
        },
      );
      statuses = [];
      controller.status.listen(statuses.add);
      controller.start();
      await Future<void>.delayed(Duration.zero);
      onGameHost();
      final first = controller.checkSession();
      await Future<void>.delayed(Duration.zero);
      await controller.checkSession();
      expect(characterGets, 1);
      held.complete(const AuthHttpResponse(status: 200, body: 'ok'));
      await first;
    });
  });
}

class _ThrowingCookies implements CookieSource {
  @override
  Future<List<GameCookie>> read(Uri url) async {
    throw StateError('CookieManager unavailable');
  }
}

class _HbClock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}
