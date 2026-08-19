import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

/// Verbatim from the live responses captured on device / by curl.
const sessionCookie =
    'ASP.NET_SessionId=uhagcfnzlfsqw30dkg1t2yy4; path=/; HttpOnly; SameSite=Lax';
const authCookie =
    'popmundo.com=8691C656A11C9351F7C16CB6; path=/; HttpOnly; SameSite=Lax';
const themeCookie = 'PopNormTheme=1; domain=.popmundo.com; '
    'expires=Thu, 19-Aug-2027 15:45:05 GMT; path=/';
const clearedAuthCookie = 'popmundo.com=; '
    'expires=Mon, 11-Oct-1999 22:00:00 GMT; path=/; HttpOnly; SameSite=Lax';

final from = Uri.parse('https://75.popmundo.com/World/Popmundo.aspx');

void main() {
  group('parsing the game\'s real Set-Cookie headers', () {
    test('the session cookie is host-only', () {
      final c = GameCookie.parse(sessionCookie, from)!;
      expect(c.name, 'ASP.NET_SessionId');
      expect(c.value, 'uhagcfnzlfsqw30dkg1t2yy4');
      expect(c.host, '75.popmundo.com');
      expect(c.domainAttribute, isNull, reason: 'no domain= was sent');
      expect(c.isHostOnly, isTrue);
      expect(c.path, '/');
      expect(c.httpOnly, isTrue);
      expect(c.sameSite, 'Lax');
      expect(c.expires, isNull, reason: 'session cookie');
    });

    test('the auth cookie is host-only too', () {
      final c = GameCookie.parse(authCookie, from)!;
      expect(c.name, 'popmundo.com');
      expect(c.isHostOnly, isTrue);
      expect(c.host, '75.popmundo.com');
      expect(c.httpOnly, isTrue);
    });

    test('the theme cookie keeps its domain attribute', () {
      final c = GameCookie.parse(themeCookie, from)!;
      expect(c.domainAttribute, '.popmundo.com');
      expect(c.isHostOnly, isFalse);
      expect(c.httpOnly, isFalse);
      expect(c.expires, DateTime.utc(2027, 8, 19, 15, 45, 5));
    });

    test('dashed and spaced expiry spellings both parse', () {
      expect(GameCookie.parseCookieDate('Thu, 19-Aug-2027 15:45:05 GMT'),
          DateTime.utc(2027, 8, 19, 15, 45, 5));
      expect(GameCookie.parseCookieDate('Thu, 19 Aug 2027 15:45:05 GMT'),
          DateTime.utc(2027, 8, 19, 15, 45, 5));
      expect(GameCookie.parseCookieDate('not a date'), isNull);
    });

    test('Max-Age wins over Expires', () {
      final c = GameCookie.parse(
        'a=b; expires=Thu, 19-Aug-2027 15:45:05 GMT; Max-Age=60',
        from,
      )!;
      expect(c.expires!.isAfter(DateTime.now().toUtc()), isTrue);
      expect(c.expires!.year, isNot(2027));
    });

    test('a cleared cookie is recognised as expired', () {
      final c = GameCookie.parse(clearedAuthCookie, from)!;
      expect(c.value, isEmpty);
      expect(c.expiredAt(DateTime.now()), isTrue);
    });

    test('malformed lines are dropped, not thrown on', () {
      expect(GameCookie.parse('', from), isNull);
      expect(GameCookie.parse('novalue', from), isNull);
      expect(GameCookie.parse('=orphan', from), isNull);
      expect(
        GameCookie.parseAll([sessionCookie, 'garbage', authCookie], from).length,
        2,
      );
    });
  });

  group('matching', () {
    final session = GameCookie.parse(sessionCookie, from)!;
    final theme = GameCookie.parse(themeCookie, from)!;

    test('a host-only cookie goes to its host and nowhere else', () {
      expect(session.matches(Uri.parse('https://75.popmundo.com/World/')), isTrue);
      expect(session.matches(Uri.parse('https://74.popmundo.com/World/')), isFalse,
          reason: 'this is why the auth cookie does not survive a host hop');
      expect(session.matches(Uri.parse('https://www.popmundo.com/')), isFalse);
    });

    test('a domain cookie spans subdomains', () {
      expect(theme.matches(Uri.parse('https://74.popmundo.com/')), isTrue);
      expect(theme.matches(Uri.parse('https://popmundo.com/')), isTrue);
      expect(theme.matches(Uri.parse('https://evil.com/')), isFalse);
    });

    test('a secure cookie is withheld from http', () {
      const secure = GameCookie(
          name: 'a', value: 'b', host: '75.popmundo.com', secure: true);
      expect(secure.matches(Uri.parse('http://75.popmundo.com/')), isFalse);
      expect(secure.matches(Uri.parse('https://75.popmundo.com/')), isTrue);
    });

    test('path scoping only matches on a segment boundary', () {
      const scoped =
          GameCookie(name: 'a', value: 'b', host: 'h', path: '/World');
      expect(scoped.matches(Uri.parse('https://h/World')), isTrue);
      expect(scoped.matches(Uri.parse('https://h/World/Popmundo.aspx')), isTrue);
      expect(scoped.matches(Uri.parse('https://h/Worldly')), isFalse);
    });

    test('identity is name + owner + path', () {
      expect(GameCookie.parse(authCookie, from)!.key,
          GameCookie.parse(clearedAuthCookie, from)!.key);
      expect(session.key, isNot(theme.key));
    });
  });
}
