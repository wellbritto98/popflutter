import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late UserScriptCatalog catalog;
  late Map<String, String> responses;
  late List<Uri> fetched;

  setUp(() {
    store = MemoryKeyValueStore();
    catalog = UserScriptCatalog(store);
    responses = {};
    fetched = [];
  });

  Future<String> fakeGet(Uri url, {Duration? timeout}) async {
    fetched.add(url);
    final body = responses[url.toString()];
    if (body == null) {
      throw UserScriptImportException('Download failed: ${url.toString()}');
    }
    return body;
  }

  const validScript = '''
// ==UserScript==
// @name Imported One
// @version 2.0
// @description Test script
// @match https://*.popmundo.com/*
// @grant none
// ==/UserScript==
console.log('ok');
''';

  test('imports a valid .user.js URL into the catalog', () async {
    final url = 'https://cdn.example.com/scripts/hello.user.js';
    responses[url] = validScript;
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);

    final installed = await importer.importFromUrl(url);

    expect(installed.name, 'Imported One');
    expect(installed.sourceUrl, url);
    expect(installed.enabled, isTrue);
    expect(installed.version, '2.0');
    expect(installed.source, contains("console.log('ok')"));
    expect(await catalog.list(), hasLength(1));
    expect(fetched, [Uri.parse(url)]);
  });

  test('rejects URL that does not end with .user.js', () async {
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);
    expect(
      () => importer.importFromUrl('https://cdn.example.com/hello.js'),
      throwsA(
        isA<UserScriptImportException>().having(
          (e) => e.message,
          'message',
          contains('.user.js'),
        ),
      ),
    );
    expect(fetched, isEmpty);
    expect(await catalog.list(), isEmpty);
  });

  test('rejects non-http(s) scheme', () async {
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);
    expect(
      () => importer.importFromUrl('file:///tmp/hello.user.js'),
      throwsA(isA<UserScriptImportException>()),
    );
    expect(await catalog.list(), isEmpty);
  });

  test('network failure leaves catalog empty', () async {
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);
    expect(
      () => importer.importFromUrl('https://cdn.example.com/missing.user.js'),
      throwsA(isA<UserScriptImportException>()),
    );
    expect(await catalog.list(), isEmpty);
  });

  test('parse failure leaves catalog empty', () async {
    final url = 'https://cdn.example.com/bad.user.js';
    responses[url] = 'not a userscript';
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);
    expect(
      () => importer.importFromUrl(url),
      throwsA(isA<UserScriptImportException>()),
    );
    expect(await catalog.list(), isEmpty);
  });

  test('fetches @require in order and aborts on require failure', () async {
    final url = 'https://cdn.example.com/with-req.user.js';
    responses[url] = '''
// ==UserScript==
// @name With Require
// @require https://cdn.example.com/lib-a.js
// @require https://cdn.example.com/lib-b.js
// ==/UserScript==
main();
''';
    responses['https://cdn.example.com/lib-a.js'] = 'var a = 1;';
    // lib-b missing → fail
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);

    await expectLater(
      importer.importFromUrl(url),
      throwsA(isA<UserScriptImportException>()),
    );
    expect(await catalog.list(), isEmpty);
    expect(
      fetched.map((u) => u.toString()),
      [
        url,
        'https://cdn.example.com/lib-a.js',
        'https://cdn.example.com/lib-b.js',
      ],
    );
  });

  test('concatenates successful @require before body', () async {
    final url = 'https://cdn.example.com/with-req-ok.user.js';
    responses[url] = '''
// ==UserScript==
// @name With Require Ok
// @require https://cdn.example.com/lib-a.js
// ==/UserScript==
main();
''';
    responses['https://cdn.example.com/lib-a.js'] = 'var a = 1;';
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);

    final installed = await importer.importFromUrl(url);
    expect(installed.source.indexOf('var a = 1;'),
        lessThan(installed.source.indexOf('main();')));
  });

  test('duplicate sourceUrl does not write a second entry', () async {
    final url = 'https://cdn.example.com/hello.user.js';
    responses[url] = validScript;
    final importer = UserScriptImporter(catalog: catalog, httpGet: fakeGet);
    await importer.importFromUrl(url);
    await expectLater(
      importer.importFromUrl(url),
      throwsA(
        isA<UserScriptImportException>().having(
          (e) => e.message,
          'message',
          contains('already installed'),
        ),
      ),
    );
    expect(await catalog.list(), hasLength(1));
  });
}
