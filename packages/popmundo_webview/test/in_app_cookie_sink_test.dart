import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

void main() {
  group('sameSitePolicyFor', () {
    test('maps what the game actually sends', () {
      expect(sameSitePolicyFor('Lax'), HTTPCookieSameSitePolicy.LAX);
      expect(sameSitePolicyFor('lax'), HTTPCookieSameSitePolicy.LAX);
    });

    test('maps the other two policies', () {
      expect(sameSitePolicyFor('Strict'), HTTPCookieSameSitePolicy.STRICT);
      expect(sameSitePolicyFor('None'), HTTPCookieSameSitePolicy.NONE);
    });

    test('an absent or unknown attribute leaves the browser default', () {
      expect(sameSitePolicyFor(null), isNull);
      expect(sameSitePolicyFor(''), isNull);
      expect(sameSitePolicyFor('nonsense'), isNull);
    });
  });

  group('gameCookieFromInApp', () {
    final url = Uri.parse('https://75.popmundo.com/World/Popmundo.aspx');

    test('null domain is host-only on the request host', () {
      final cookie = gameCookieFromInApp(
        Cookie(name: 'popmundo.com', value: 'AUTH', isHttpOnly: true),
        url,
      );
      expect(cookie.host, '75.popmundo.com');
      expect(cookie.isHostOnly, isTrue);
      expect(cookie.value, 'AUTH');
      expect(cookie.httpOnly, isTrue);
      expect(cookie.path, '/');
    });

    test('domain equal to the host stays host-only', () {
      final cookie = gameCookieFromInApp(
        Cookie(
          name: 'ASP.NET_SessionId',
          value: 's75',
          domain: '75.popmundo.com',
        ),
        url,
      );
      expect(cookie.isHostOnly, isTrue);
      expect(cookie.matches(url), isTrue);
      expect(
        cookie.matches(Uri.parse('https://www.popmundo.com/')),
        isFalse,
      );
    });

    test('a broader domain cookie keeps domainAttribute', () {
      final cookie = gameCookieFromInApp(
        Cookie(
          name: 'theme',
          value: '1',
          domain: '.popmundo.com',
          path: '/',
        ),
        url,
      );
      expect(cookie.domainAttribute, '.popmundo.com');
      expect(cookie.isHostOnly, isFalse);
      expect(cookie.matches(Uri.parse('https://74.popmundo.com/')), isTrue);
    });
  });
}
