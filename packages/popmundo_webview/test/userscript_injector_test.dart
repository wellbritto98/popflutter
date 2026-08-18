import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';
import 'dart:io';

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}

class _FakePort implements UserScriptWebViewPort {
  final added = <UserScript>[];
  final removedGroups = <String>[];
  var reloadCount = 0;

  @override
  Future<void> addUserScript(UserScript userScript) async {
    added.add(userScript);
  }

  @override
  Future<void> removeUserScriptsByGroupName(String groupName) async {
    removedGroups.add(groupName);
  }

  @override
  Future<void> reload() async {
    reloadCount++;
  }
}

InstalledUserScript _script({
  required String id,
  bool enabled = true,
  UserScriptRunAt runAt = UserScriptRunAt.documentEnd,
  bool forMainFrameOnly = false,
  String source = '1;',
  List<String> grants = const [],
}) {
  return InstalledUserScript(
    id: id,
    sourceUrl: 'https://example.com/$id.user.js',
    name: id,
    enabled: enabled,
    source: source,
    headers: {
      'name': [id],
      if (grants.isNotEmpty) 'grant': grants,
    },
    installedAt: DateTime.utc(2026, 8, 17),
    runAt: runAt,
    forMainFrameOnly: forMainFrameOnly,
  );
}

GmValueStore _store([Map<String, Object?>? seed]) {
  final kv = MemoryKeyValueStore();
  final store = GmValueStore(kv);
  if (seed != null) {
    for (final entry in seed.entries) {
      kv.set(GmValueStore.keyFor(entry.key), entry.value);
    }
  }
  return store;
}

void main() {
  test('toUserScript maps runAt, forMainFrameOnly, groupName, PAGE world', () {
    final us = UserScriptInjector.toUserScript(
      _script(
        id: 'abc',
        runAt: UserScriptRunAt.documentStart,
        forMainFrameOnly: true,
        source: 'window.x=1;',
      ),
    );
    expect(us.groupName, 'userscript:abc');
    expect(us.source, 'window.x=1;');
    expect(us.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
    expect(us.forMainFrameOnly, isTrue);
    expect(us.contentWorld, ContentWorld.PAGE);
  });

  test('toUserScript maps documentEnd injection time', () {
    final us = UserScriptInjector.toUserScript(_script(id: 'z'));
    expect(us.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_END);
    expect(us.forMainFrameOnly, isFalse);
  });

  test('mergeInitial appends only enabled catalog scripts after builtins', () async {
    final builtin = [
      UserScript(
        source: 'builtin;',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ];
    final merged = await UserScriptInjector.mergeInitial(
      builtin: builtin,
      enabled: [
        _script(id: 'a'),
        _script(id: 'b'),
      ],
      valueStore: _store(),
    );
    expect(merged, hasLength(3));
    expect(merged.first.source, 'builtin;');
    expect(merged[1].groupName, 'userscript:a');
    expect(merged[2].groupName, 'userscript:b');
  });

  test('sync adds new enabled scripts and reloads', () async {
    final port = _FakePort();
    await UserScriptInjector.sync(
      port: port,
      previouslyEnabledIds: const [],
      nextCatalog: [_script(id: 'a')],
      valueStore: _store(),
    );
    expect(port.added, hasLength(1));
    expect(port.added.single.groupName, 'userscript:a');
    expect(port.removedGroups, isEmpty);
    expect(port.reloadCount, 1);
  });

  test('sync removes disabled/deleted by groupName and reloads', () async {
    final port = _FakePort();
    await UserScriptInjector.sync(
      port: port,
      previouslyEnabledIds: const ['a', 'b'],
      nextCatalog: [
        _script(id: 'a', enabled: false),
        _script(id: 'b'),
      ],
      valueStore: _store(),
    );
    expect(port.removedGroups, ['userscript:a']);
    expect(port.added, isEmpty);
    expect(port.reloadCount, 1);
  });

  test('toUserScript wraps source with GM shim when a Core grant is present', () {
    final us = UserScriptInjector.toUserScript(
      InstalledUserScript(
        id: 'gm1',
        sourceUrl: 'https://example.com/gm1.user.js',
        name: 'GM Script',
        enabled: true,
        source: 'window.__usm = GM_getValue("x", 0);',
        headers: {
          'name': ['GM Script'],
          'grant': ['GM_getValue', 'GM_setValue'],
        },
        installedAt: DateTime.utc(2026, 8, 17),
        runAt: UserScriptRunAt.documentEnd,
        forMainFrameOnly: false,
      ),
      initialGmValues: {'x': 5},
    );
    expect(us.source, contains('GM_getValue'));
    expect(us.source, contains('"x":5'));
    expect(us.source, contains('window.__usm = GM_getValue("x", 0);'));
    expect(us.source, endsWith('})();'));
  });

  test('toUserScript leaves grant-less script source untouched', () {
    final us = UserScriptInjector.toUserScript(_script(id: 'plain', source: 'window.x=1;'));
    expect(us.source, 'window.x=1;');
  });

  test('refreshGmSnapshots re-registers only value-grant scripts with fresh values', () async {
    final port = _FakePort();
    final kv = MemoryKeyValueStore();
    final store = GmValueStore(kv);
    await store.setValue('a', 'x', 42);

    await UserScriptInjector.refreshGmSnapshots(
      port: port,
      enabledScripts: [
        _script(id: 'a', grants: const ['GM_getValue', 'GM_setValue']),
        _script(id: 'b', grants: const ['GM_addStyle']),
        _script(id: 'c'),
      ],
      valueStore: store,
    );

    expect(port.removedGroups, ['userscript:a']);
    expect(port.added, hasLength(1));
    expect(port.added.single.groupName, 'userscript:a');
    expect(port.added.single.source, contains('"x":42'));
    expect(port.reloadCount, 0);
  });

  test('refreshGmSnapshots is a no-op when nothing has a value grant', () async {
    final port = _FakePort();
    await UserScriptInjector.refreshGmSnapshots(
      port: port,
      enabledScripts: [
        _script(id: 'a', grants: const ['GM_addStyle']),
        _script(id: 'b'),
      ],
      valueStore: _store(),
    );
    expect(port.removedGroups, isEmpty);
    expect(port.added, isEmpty);
    expect(port.reloadCount, 0);
  });

  test('injector source never calls removeAllUserScripts', () {
    final source = _open([
      'lib/src/userscript_injector.dart',
      'packages/popmundo_webview/lib/src/userscript_injector.dart',
    ]);
    expect(source.contains('removeAllUserScripts'), isFalse);
    expect(source.contains('removeUserScriptsByGroupName'), isTrue);
    expect(RegExp(r'\.addUserScript\b').hasMatch(source), isTrue);
  });
}
