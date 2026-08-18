import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/userscripts/userscripts_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

void main() {
  late MemoryKeyValueStore store;
  late UserScriptCatalog catalog;
  late Map<String, String> httpBodies;
  late List<List<InstalledUserScript>> applyCalls;

  setUp(() {
    store = MemoryKeyValueStore();
    catalog = UserScriptCatalog(store);
    httpBodies = {};
    applyCalls = [];
  });

  Future<String> httpGet(Uri url, {Duration? timeout}) async {
    final body = httpBodies[url.toString()];
    if (body == null) {
      throw UserScriptImportException('Download failed: $url');
    }
    return body;
  }

  UserScriptImporter importer() =>
      UserScriptImporter(catalog: catalog, httpGet: httpGet);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserScriptsScreen(
          catalog: catalog,
          importer: importer(),
          onApply: (list) async {
            applyCalls.add(List.of(list));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  InstalledUserScript seed({
    String id = 'a',
    String name = 'Alpha',
    bool enabled = true,
  }) {
    return InstalledUserScript(
      id: id,
      sourceUrl: 'https://example.com/$id.user.js',
      name: name,
      version: '1.0',
      enabled: enabled,
      source: '1;',
      headers: {
        'name': [name],
      },
      installedAt: DateTime.utc(2026, 8, 17),
      runAt: UserScriptRunAt.documentEnd,
      forMainFrameOnly: false,
    );
  }

  testWidgets('shows empty state when catalog is empty', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('userscripts-empty')), findsOneWidget);
    expect(find.text('No userscripts yet'), findsOneWidget);
    expect(find.byKey(const Key('userscripts-empty-add')), findsOneWidget);
  });

  testWidgets('lists installed scripts with switch', (tester) async {
    await catalog.add(seed());
    await pumpScreen(tester);
    expect(find.byKey(const Key('userscripts-list')), findsOneWidget);
    expect(find.byKey(const Key('userscript-item-a')), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('userscript-item-a')),
    );
    expect(tile.value, isTrue);
  });

  testWidgets('import success shows snackbar and calls onApply', (tester) async {
    const url = 'https://cdn.example.com/hello.user.js';
    httpBodies[url] = '''
// ==UserScript==
// @name Hello UI
// @grant none
// ==/UserScript==
1;
''';
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('userscripts-empty-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('userscript-add-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('userscript-url-field')), url);
    await tester.tap(find.byKey(const Key('userscript-add-confirm')));
    await tester.pumpAndSettle();

    expect(find.text("Imported 'Hello UI'"), findsOneWidget);
    expect(applyCalls, hasLength(1));
    expect(applyCalls.single.single.name, 'Hello UI');
    expect(find.text('Hello UI'), findsOneWidget);
  });

  testWidgets('import failure shows error snackbar and leaves list empty',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('userscript-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('userscript-url-field')),
      'https://cdn.example.com/missing.user.js',
    );
    await tester.tap(find.byKey(const Key('userscript-add-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('userscript-snackbar')), findsOneWidget);
    expect(find.textContaining('Download failed'), findsOneWidget);
    expect(find.byKey(const Key('userscripts-empty')), findsOneWidget);
    expect(applyCalls, isEmpty);
  });

  testWidgets('toggle switch persists and calls onApply', (tester) async {
    await catalog.add(seed());
    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect((await catalog.list()).single.enabled, isFalse);
    expect(applyCalls, hasLength(1));
    expect(applyCalls.single.single.enabled, isFalse);
  });

  testWidgets('delete cancel leaves catalog unchanged', (tester) async {
    await catalog.add(seed());
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('userscript-delete-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('userscript-delete-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('userscript-delete-cancel')));
    await tester.pumpAndSettle();

    expect(await catalog.list(), hasLength(1));
    expect(applyCalls, isEmpty);
  });

  testWidgets('delete confirm removes script and calls onApply', (tester) async {
    await catalog.add(seed());
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('userscript-delete-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('userscript-delete-confirm')));
    await tester.pumpAndSettle();

    expect(await catalog.list(), isEmpty);
    expect(applyCalls, hasLength(1));
    expect(applyCalls.single, isEmpty);
    expect(find.byKey(const Key('userscripts-empty')), findsOneWidget);
  });

  testWidgets('disables add while an import is in progress', (tester) async {
    const url = 'https://cdn.example.com/slow.user.js';
    final gate = Completer<String>();
    Future<String> slowGet(Uri requested, {Duration? timeout}) async {
      if (requested.toString() != url) {
        throw UserScriptImportException('unexpected ${requested}');
      }
      return gate.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: UserScriptsScreen(
          catalog: catalog,
          importer: UserScriptImporter(catalog: catalog, httpGet: slowGet),
          onApply: (list) async {
            applyCalls.add(List.of(list));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('userscript-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('userscript-url-field')), url);
    await tester.tap(find.byKey(const Key('userscript-add-confirm')));
    await tester.pump(); // start import; dialog closes

    final addButton = tester.widget<IconButton>(
      find.byKey(const Key('userscript-add')),
    );
    expect(addButton.onPressed, isNull);

    gate.complete('''
// ==UserScript==
// @name Slow
// @grant none
// ==/UserScript==
1;
''');
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('userscript-add'))).onPressed,
      isNotNull,
    );
  });
}
