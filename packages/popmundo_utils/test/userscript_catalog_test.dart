import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late UserScriptCatalog catalog;

  setUp(() {
    store = MemoryKeyValueStore();
    catalog = UserScriptCatalog(store);
  });

  InstalledUserScript sample({
    String id = 'id-1',
    String sourceUrl = 'https://example.com/hello.user.js',
    String name = 'Hello',
    bool enabled = true,
  }) {
    return InstalledUserScript(
      id: id,
      sourceUrl: sourceUrl,
      name: name,
      version: '1.0',
      description: 'desc',
      enabled: enabled,
      source: 'console.log(1);',
      headers: {
        'name': ['Hello'],
      },
      installedAt: DateTime.utc(2026, 8, 17),
      runAt: UserScriptRunAt.documentEnd,
      forMainFrameOnly: false,
    );
  }

  test('starts empty', () async {
    expect(await catalog.list(), isEmpty);
  });

  test('add then list returns the script', () async {
    await catalog.add(sample());
    final list = await catalog.list();
    expect(list, hasLength(1));
    expect(list.single.name, 'Hello');
    expect(list.single.sourceUrl, 'https://example.com/hello.user.js');
    expect(list.single.enabled, isTrue);
    expect(list.single.source, 'console.log(1);');
    expect(list.single.runAt, UserScriptRunAt.documentEnd);
  });

  test('rejects duplicate sourceUrl', () async {
    await catalog.add(sample());
    expect(
      () => catalog.add(sample(id: 'id-2')),
      throwsA(
        isA<UserScriptCatalogException>().having(
          (e) => e.message,
          'message',
          contains('already installed'),
        ),
      ),
    );
    expect(await catalog.list(), hasLength(1));
  });

  test('toggleEnabled persists new state', () async {
    await catalog.add(sample());
    final updated = await catalog.toggleEnabled('id-1');
    expect(updated.enabled, isFalse);
    expect((await catalog.list()).single.enabled, isFalse);
    final again = await catalog.toggleEnabled('id-1');
    expect(again.enabled, isTrue);
  });

  test('remove deletes the script', () async {
    await catalog.add(sample());
    await catalog.remove('id-1');
    expect(await catalog.list(), isEmpty);
  });

  test('toggle/remove unknown id throws', () async {
    expect(
      () => catalog.toggleEnabled('missing'),
      throwsA(isA<UserScriptCatalogException>()),
    );
    expect(
      () => catalog.remove('missing'),
      throwsA(isA<UserScriptCatalogException>()),
    );
  });

  test('enabledOnly returns only enabled scripts', () async {
    await catalog.add(sample(id: 'a', sourceUrl: 'https://a.example/a.user.js'));
    await catalog.add(
      sample(id: 'b', sourceUrl: 'https://b.example/b.user.js', enabled: false),
    );
    final enabled = await catalog.enabledOnly();
    expect(enabled.map((e) => e.id), ['a']);
  });
}
