import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  group('GmConnectPolicy', () {
    test('allows any Popmundo host without @connect', () {
      expect(
        GmConnectPolicy.allows(
          Uri.parse('https://73.popmundo.com/WebServices/x'),
          const [],
        ),
        isTrue,
      );
    });

    test('denies third-party host without matching @connect', () {
      expect(
        GmConnectPolicy.allows(
          Uri.parse('https://evil.example.com/api'),
          const ['other.com'],
        ),
        isFalse,
      );
    });

    test('allows wildcard and subdomain @connect patterns', () {
      expect(
        GmConnectPolicy.allows(
          Uri.parse('https://api.example.com/x'),
          const ['*.example.com'],
        ),
        isTrue,
      );
      expect(
        GmConnectPolicy.allows(
          Uri.parse('https://anywhere.com/x'),
          const ['*'],
        ),
        isTrue,
      );
    });

    test('rejects non-http schemes', () {
      expect(
        GmConnectPolicy.allows(Uri.parse('ftp://example.com/x'), const ['*']),
        isFalse,
      );
    });
  });

  group('UserScriptResourceParser', () {
    test('parses name url pairs', () {
      expect(
        UserScriptResourceParser.parseHeaders([
          'icon https://example.com/i.png',
          'css https://example.com/s.css',
        ]),
        {
          'icon': 'https://example.com/i.png',
          'css': 'https://example.com/s.css',
        },
      );
    });
  });
}
