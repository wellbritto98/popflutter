import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('GmResourceStore round-trips entries per script', () async {
    final store = MemoryKeyValueStore();
    final resources = GmResourceStore(store);
    await resources.setAll('abc', {
      'icon': GmResourceEntry(
        mimeType: 'image/png',
        base64: GmResourceStore.encodeBytes([1, 2, 3]),
      ),
    });

    final loaded = await resources.loadAll('abc');
    expect(loaded['icon']!.mimeType, 'image/png');
    expect(loaded['icon']!.toDataUrl(), startsWith('data:image/png;base64,'));

    await resources.clearForScript('abc');
    expect(await resources.loadAll('abc'), isEmpty);
  });
}
