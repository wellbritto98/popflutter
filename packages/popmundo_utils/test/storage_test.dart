import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeExcludeMap returns empty for null and lists', () {
    expect(StorageService.normalizeExcludeMap(null), isEmpty);
    expect(StorageService.normalizeExcludeMap([1, 2]), isEmpty);
    expect(StorageService.normalizeExcludeMap({'a': 1})['a'], 1);
  });

  test('excludeEntryId accepts object and plain id', () {
    expect(StorageService.excludeEntryId({'id': 7}), 7);
    expect(StorageService.excludeEntryId(7), 7);
    expect(StorageService.excludeEntryId('nope'), isNull);
    expect(StorageService.excludeEntryId({'id': 0}), isNull);
  });

  test('toggleExclusion adds and removes ids', () async {
    final store = MemoryKeyValueStore();
    final storage = StorageService(store);

    expect(await storage.toggleExclusion(
      featureKey: 'mass_interact_exclude_id',
      myCharKey: '10',
      charID: 99,
      charName: 'Ada',
    ), isTrue);
    expect(await storage.getExcludedIds('mass_interact_exclude_id', 10), [99]);

    expect(await storage.toggleExclusion(
      featureKey: 'mass_interact_exclude_id',
      myCharKey: '10',
      charID: 99,
      charName: 'Ada',
    ), isFalse);
    expect(await storage.getExcludedIds('mass_interact_exclude_id', 10), isEmpty);
  });

  test('memory store round-trips values in process', () async {
    final store = MemoryKeyValueStore();
    await store.set('k', {'n': 1});
    expect(await store.get('k'), {'n': 1});
  });
}
