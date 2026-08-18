import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  group('UserScriptParser', () {
    test('parses a minimal valid userscript with @name', () {
      const raw = '''
// ==UserScript==
// @name         Hello Popmundo
// @namespace    https://example.com
// @version      1.0.0
// @description  Says hello
// @match        https://*.popmundo.com/*
// @grant        none
// ==/UserScript==

console.log('hello');
''';
      final parsed = UserScriptParser.parse(raw);
      expect(parsed.name, 'Hello Popmundo');
      expect(parsed.version, '1.0.0');
      expect(parsed.description, 'Says hello');
      expect(parsed.namespace, 'https://example.com');
      expect(parsed.runAt, UserScriptRunAt.documentEnd);
      expect(parsed.forMainFrameOnly, isFalse);
      expect(parsed.matches, ['https://*.popmundo.com/*']);
      expect(parsed.grants, ['none']);
      expect(parsed.body.trim(), "console.log('hello');");
    });

    test('maps @run-at document-start and @noframes', () {
      const raw = '''
// ==UserScript==
// @name Early
// @run-at document-start
// @noframes
// ==/UserScript==
var x = 1;
''';
      final parsed = UserScriptParser.parse(raw);
      expect(parsed.runAt, UserScriptRunAt.documentStart);
      expect(parsed.forMainFrameOnly, isTrue);
    });

    test('maps document-idle to documentEnd', () {
      const raw = '''
// ==UserScript==
// @name Idle
// @run-at document-idle
// ==/UserScript==
1;
''';
      expect(UserScriptParser.parse(raw).runAt, UserScriptRunAt.documentEnd);
    });

    test('rejects missing metadata block', () {
      expect(
        () => UserScriptParser.parse('console.log(1);'),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.message,
            'message',
            contains('==UserScript=='),
          ),
        ),
      );
    });

    test('rejects missing @name', () {
      const raw = '''
// ==UserScript==
// @version 1
// ==/UserScript==
1;
''';
      expect(
        () => UserScriptParser.parse(raw),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.message,
            'message',
            contains('@name'),
          ),
        ),
      );
    });

    test('rejects unsupported @grant and lists it', () {
      const raw = '''
// ==UserScript==
// @name Bad Grant
// @grant GM_xmlhttpRequest
// ==/UserScript==
1;
''';
      expect(
        () => UserScriptParser.parse(raw),
        throwsA(
          isA<UserScriptParseException>()
              .having((e) => e.unsupportedHeaders, 'unsupported',
                  contains('@grant GM_xmlhttpRequest'))
              .having((e) => e.message, 'message', contains('Unsupported')),
        ),
      );
    });

    test('rejects @resource and @connect', () {
      const raw = '''
// ==UserScript==
// @name Res
// @resource foo https://example.com/a.png
// @connect example.com
// ==/UserScript==
1;
''';
      expect(
        () => UserScriptParser.parse(raw),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.unsupportedHeaders,
            'unsupported',
            allOf(contains('@resource'), contains('@connect')),
          ),
        ),
      );
    });

    test('rejects @run-at context-menu', () {
      const raw = '''
// ==UserScript==
// @name Menu
// @run-at context-menu
// ==/UserScript==
1;
''';
      expect(
        () => UserScriptParser.parse(raw),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.unsupportedHeaders,
            'unsupported',
            contains('@run-at context-menu'),
          ),
        ),
      );
    });

    test('rejects unsupported @sandbox', () {
      const raw = '''
// ==UserScript==
// @name Sand
// @sandbox raw
// ==/UserScript==
1;
''';
      expect(
        () => UserScriptParser.parse(raw),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.unsupportedHeaders,
            'unsupported',
            contains('@sandbox raw'),
          ),
        ),
      );
    });

    test('rejects unsupported @inject-into', () {
      const raw = '''
// ==UserScript==
// @name Inject
// @inject-into page
// ==/UserScript==
1;
''';
      // page/content/auto are allowed; use an unsupported value
      const bad = '''
// ==UserScript==
// @name Inject Bad
// @inject-into browser
// ==/UserScript==
1;
''';
      expect(UserScriptParser.parse(raw).name, 'Inject');
      expect(
        () => UserScriptParser.parse(bad),
        throwsA(
          isA<UserScriptParseException>().having(
            (e) => e.unsupportedHeaders,
            'unsupported',
            contains('@inject-into browser'),
          ),
        ),
      );
    });

    test('accepts @grant unsafeWindow and unwrap', () {
      const raw = '''
// ==UserScript==
// @name Ok
// @grant unsafeWindow
// @grant unwrap
// ==/UserScript==
1;
''';
      final parsed = UserScriptParser.parse(raw);
      expect(parsed.grants, ['unsafeWindow', 'unwrap']);
    });

    test('collects @require URLs in order', () {
      const raw = '''
// ==UserScript==
// @name Req
// @require https://cdn.example.com/a.js
// @require https://cdn.example.com/b.js
// ==/UserScript==
1;
''';
      final parsed = UserScriptParser.parse(raw);
      expect(parsed.requires, [
        'https://cdn.example.com/a.js',
        'https://cdn.example.com/b.js',
      ]);
    });

    test('buildInjectableSource wraps match/include/exclude guards', () {
      const raw = '''
// ==UserScript==
// @name Guarded
// @match https://www.popmundo.com/*
// @exclude https://www.popmundo.com/Login*
// ==/UserScript==
window.__usm = true;
''';
      final parsed = UserScriptParser.parse(raw);
      final injectable = parsed.buildInjectableSource(requiredSources: const []);
      expect(injectable, contains('window.__usm = true'));
      expect(injectable, contains('location.href'));
      expect(injectable, contains('https://www.popmundo.com/*'));
      expect(injectable, contains('https://www.popmundo.com/Login*'));
    });

    test('buildInjectableSource prepends @require sources', () {
      const raw = '''
// ==UserScript==
// @name WithReq
// ==/UserScript==
main();
''';
      final parsed = UserScriptParser.parse(raw);
      final injectable = parsed.buildInjectableSource(
        requiredSources: const ['var lib = 1;', 'var lib2 = 2;'],
      );
      expect(injectable.indexOf('var lib = 1;'), lessThan(injectable.indexOf('main();')));
      expect(injectable.indexOf('var lib2 = 2;'), lessThan(injectable.indexOf('main();')));
    });
  });
}
