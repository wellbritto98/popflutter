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
}
