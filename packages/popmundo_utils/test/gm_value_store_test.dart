import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  group('GmValueStore', () {
    late MemoryKeyValueStore kv;
    late GmValueStore store;

    setUp(() {
      kv = MemoryKeyValueStore();
      store = GmValueStore(kv);
    });

    test('keyFor namespaces under the script id', () {
      expect(GmValueStore.keyFor('abc'), 'userscript:abc:gmvalues');
    });

    test('loadAll on an unknown script id returns an empty map', () async {
      expect(await store.loadAll('missing'), isEmpty);
    });

    test('setValue then loadAll round-trips', () async {
      await store.setValue('abc', 'count', 3);
      expect(await store.loadAll('abc'), {'count': 3});
    });

    test('deleteValue removes only the targeted key, leaves siblings', () async {
      await store.setValue('abc', 'count', 3);
      await store.setValue('abc', 'label', 'hi');
      await store.deleteValue('abc', 'count');
      expect(await store.loadAll('abc'), {'label': 'hi'});
    });

    test('applyEvent dispatches set and delete actions', () async {
      await store.applyEvent(
        GmValueEvent(scriptId: 'abc', action: 'set', key: 'count', value: 5),
      );
      expect(await store.loadAll('abc'), {'count': 5});

      await store.applyEvent(
        GmValueEvent(scriptId: 'abc', action: 'delete', key: 'count'),
      );
      expect(await store.loadAll('abc'), isEmpty);
    });

    test('clearForScript removes the whole blob', () async {
      await store.setValue('abc', 'count', 3);
      await store.clearForScript('abc');
      expect(await kv.get(GmValueStore.keyFor('abc')), isNull);
      expect(await store.loadAll('abc'), isEmpty);
    });

    test('values for different script ids do not collide', () async {
      await store.setValue('a', 'x', 1);
      await store.setValue('b', 'x', 2);
      expect(await store.loadAll('a'), {'x': 1});
      expect(await store.loadAll('b'), {'x': 2});
    });
  });
}
