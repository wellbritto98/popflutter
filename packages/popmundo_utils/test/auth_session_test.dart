import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

/// Replays a scripted server. Records what was actually sent.
class _FakeServer {
  _FakeServer(this.routes);

  /// Keyed by `METHOD url`.
  final Map<String, AuthHttpResponse> routes;
  final seen = <AuthHttpRequest>[];

  Future<AuthHttpResponse> call(AuthHttpRequest req) async {
    seen.add(req);
    final response = routes['${req.method} ${req.url}'];
    if (response == null) {
      throw AuthHttpException('no route for ${req.method} ${req.url}');
    }
    return response;
  }

  AuthHttpRequest requestTo(String url) =>
      seen.firstWhere((r) => r.url.toString() == url);
}

void main() {
  late _Clock clock;

  AuthSession sessionFor(_FakeServer server) {
    clock = _Clock();
    return AuthSession(
      send: server.call,
      userAgent: 'Mozilla/5.0 (Linux; Android 16) TestWebView',
      now: () => clock.now,
      sleep: clock.sleep,
    );
  }

  group('the redirect chain the game actually performs', () {
    /// www POST -> 302 to the numbered host token URL -> 302 to
    /// ChooseCharacter. Only the numbered host sets the auth cookie.
    _FakeServer buildServer() => _FakeServer({
          'POST https://www.popmundo.com/': const AuthHttpResponse(
            status: 302,
            body: '',
            setCookieHeaders: [
              'ASP.NET_SessionId=wwwsession; path=/; HttpOnly; SameSite=Lax',
            ],
            location: 'https://75.popmundo.com//Login.aspx?t=TOKEN',
          ),
          'GET https://75.popmundo.com//Login.aspx?t=TOKEN':
              const AuthHttpResponse(
            status: 302,
            body: '',
            setCookieHeaders: [
              'ASP.NET_SessionId=n75session; path=/; HttpOnly; SameSite=Lax',
              'popmundo.com=AUTHVALUE; path=/; HttpOnly; SameSite=Lax',
            ],
            location: '/World/Popmundo.aspx/ChooseCharacter',
          ),
          'GET https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter':
              const AuthHttpResponse(
            status: 200,
            body: '<html>choose</html>',
          ),
        });

    test('follows every hop and lands on ChooseCharacter', () async {
      final server = buildServer();
      final session = sessionFor(server);
      final result = await session.postForm(
          Uri.parse('https://www.popmundo.com/'), 'user=x');

      expect(result.status, 200);
      expect(result.body, '<html>choose</html>');
      expect(result.finalUrl.toString(),
          'https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter');
      expect(result.hops.map((u) => u.host).toList(),
          ['www.popmundo.com', '75.popmundo.com', '75.popmundo.com']);
    });

    test('captures the auth cookie, which only the last host sets', () async {
      final server = buildServer();
      final session = sessionFor(server);
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');

      final auth = session.cookies.firstWhere((c) => c.name == 'popmundo.com');
      expect(auth.value, 'AUTHVALUE');
      expect(auth.host, '75.popmundo.com');
      expect(auth.isHostOnly, isTrue);
      expect(auth.httpOnly, isTrue);
    });

    test('keeps the two hosts\' session cookies apart', () async {
      final server = buildServer();
      final session = sessionFor(server);
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');

      final sessions =
          session.cookies.where((c) => c.name == 'ASP.NET_SessionId').toList();
      expect(sessions.length, 2, reason: 'one per host, host-only');
      expect(
        sessions.map((c) => '${c.host}=${c.value}').toSet(),
        {'www.popmundo.com=wwwsession', '75.popmundo.com=n75session'},
      );
    });

    test('sends the numbered host cookie on the last hop only', () async {
      final server = buildServer();
      final session = sessionFor(server);
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');

      final tokenHop =
          server.requestTo('https://75.popmundo.com//Login.aspx?t=TOKEN');
      expect(tokenHop.headers['Cookie'], isNull,
          reason: 'the www cookie is host-only and must not leak to 75');

      final chooseHop = server.requestTo(
          'https://75.popmundo.com/World/Popmundo.aspx/ChooseCharacter');
      expect(chooseHop.headers['Cookie'], contains('popmundo.com=AUTHVALUE'));
      expect(chooseHop.headers['Cookie'], contains('n75session'));
      expect(chooseHop.headers['Cookie'], isNot(contains('wwwsession')));
    });

    test('a 302 after POST is re-issued as GET without the body', () async {
      final server = buildServer();
      final session = sessionFor(server);
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');

      expect(server.seen.first.method, 'POST');
      expect(server.seen.first.body, 'user=x');
      expect(server.seen.skip(1).every((r) => r.method == 'GET'), isTrue);
      expect(server.seen.skip(1).every((r) => r.body == null), isTrue);
    });

    test('every request carries the WebView user agent', () async {
      final server = buildServer();
      final session = sessionFor(server);
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');

      expect(
        server.seen.every(
            (r) => r.headers['User-Agent'] == 'Mozilla/5.0 (Linux; Android 16) TestWebView'),
        isTrue,
      );
    });

    test('holds the 750ms cooldown between hops (AD-006)', () async {
      final server = buildServer();
      final session = sessionFor(server);
      final started = clock.now;
      await session.postForm(Uri.parse('https://www.popmundo.com/'), 'user=x');
      expect(clock.now.difference(started).inMilliseconds,
          greaterThanOrEqualTo(750 * 2),
          reason: '3 requests means at least 2 gaps');
    });
  });

  group('edge cases', () {
    test('a relative Location resolves against the current hop', () async {
      final server = _FakeServer({
        'GET https://75.popmundo.com/a/b': const AuthHttpResponse(
            status: 302, body: '', location: '/World/Popmundo.aspx'),
        'GET https://75.popmundo.com/World/Popmundo.aspx':
            const AuthHttpResponse(status: 200, body: 'home'),
      });
      final result =
          await sessionFor(server).get(Uri.parse('https://75.popmundo.com/a/b'));
      expect(result.finalUrl.toString(),
          'https://75.popmundo.com/World/Popmundo.aspx');
    });

    test('a cleared cookie removes it from the jar', () async {
      final server = _FakeServer({
        'GET https://75.popmundo.com/': const AuthHttpResponse(
          status: 200,
          body: '',
          setCookieHeaders: [
            'popmundo.com=; expires=Mon, 11-Oct-1999 22:00:00 GMT; path=/',
          ],
        ),
      });
      final session = sessionFor(server);
      await session.get(Uri.parse('https://75.popmundo.com/'));
      expect(session.cookies.where((c) => c.name == 'popmundo.com'), isEmpty);
    });

    test('a redirect loop stops instead of hanging', () async {
      final server = _FakeServer({
        'GET https://75.popmundo.com/loop': const AuthHttpResponse(
            status: 302, body: '', location: 'https://75.popmundo.com/loop'),
      });
      await expectLater(
        sessionFor(server).get(Uri.parse('https://75.popmundo.com/loop')),
        throwsA(isA<AuthHttpException>()),
      );
    });

    test('a non-http Location is refused', () async {
      final server = _FakeServer({
        'GET https://75.popmundo.com/x': const AuthHttpResponse(
            status: 302, body: '', location: 'javascript:alert(1)'),
      });
      await expectLater(
        sessionFor(server).get(Uri.parse('https://75.popmundo.com/x')),
        throwsA(isA<AuthHttpException>()),
      );
    });

    test('a 3xx without Location is treated as the final response', () async {
      final server = _FakeServer({
        'GET https://75.popmundo.com/x':
            const AuthHttpResponse(status: 304, body: 'cached'),
      });
      final result =
          await sessionFor(server).get(Uri.parse('https://75.popmundo.com/x'));
      expect(result.status, 304);
      expect(result.body, 'cached');
    });
  });

  group('session probe (no redirect follow)', () {
    const character =
        'https://75.popmundo.com/World/Popmundo.aspx/Character';

    test('returns the 302 and does not fetch Default.aspx', () async {
      final server = _FakeServer({
        'GET $character': const AuthHttpResponse(
          status: 302,
          body: '',
          location: '/Default.aspx',
        ),
        'GET https://75.popmundo.com/Default.aspx': const AuthHttpResponse(
          status: 200,
          body: '<html>login</html>',
        ),
      });
      final response =
          await sessionFor(server).probe(Uri.parse(character));

      expect(response.status, 302);
      expect(response.location, '/Default.aspx');
      expect(server.seen.length, 1);
      expect(server.seen.single.method, 'GET');
      expect(server.seen.single.url.toString(), character);
    });

    test('sends seeded host-only cookies on the Character GET', () async {
      final server = _FakeServer({
        'GET $character': const AuthHttpResponse(status: 200, body: 'ok'),
      });
      final session = sessionFor(server);
      session.seed([
        const GameCookie(
          name: 'popmundo.com',
          value: 'AUTH',
          host: '75.popmundo.com',
          httpOnly: true,
          secure: true,
        ),
        const GameCookie(
          name: 'popmundo.com',
          value: 'WWW',
          host: 'www.popmundo.com',
          httpOnly: true,
          secure: true,
        ),
      ]);
      await session.probe(Uri.parse(character));

      expect(server.seen.single.headers['Cookie'], contains('popmundo.com=AUTH'));
      expect(server.seen.single.headers['Cookie'], isNot(contains('WWW')));
    });

    test('holds the 750ms cooldown between sequential probes', () async {
      final server = _FakeServer({
        'GET $character': const AuthHttpResponse(status: 200, body: 'ok'),
      });
      final session = sessionFor(server);
      await session.probe(Uri.parse(character));
      final afterFirst = clock.now;
      await session.probe(Uri.parse(character));
      expect(clock.now.difference(afterFirst).inMilliseconds,
          greaterThanOrEqualTo(750));
    });
  });
}
