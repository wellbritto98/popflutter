import 'dart:convert';

abstract class KeyValueStore {
  Future<Object?> get(String key);
  Future<void> set(String key, Object? value);
  Future<void> remove(String key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<Object?> get(String key) async {
    final raw = _data[key];
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  @override
  Future<void> set(String key, Object? value) async {
    _data[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }
}

class StorageService {
  StorageService(this.store);

  final KeyValueStore store;
  static const int excludeNameBuckets = 8;

  static Map<String, dynamic> normalizeExcludeMap(dynamic raw) {
    if (raw is Map && raw is! List) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  static int? excludeEntryId(dynamic entry) {
    final raw = entry is Map ? entry['id'] : entry;
    final id = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (id != null && id > 0) return id;
    return null;
  }

  Future<List<int>> getExcludedIds(String featureKey, int myCharID) async {
    final shardKey = '${featureKey}_$myCharID';
    final shard = await store.get(shardKey);
    if (shard is List) {
      return shard.map(excludeEntryId).whereType<int>().toList();
    }
    final legacy = await store.get(featureKey);
    final map = normalizeExcludeMap(legacy);
    final list = map['$myCharID'];
    if (list is List) {
      return list.map(excludeEntryId).whereType<int>().toList();
    }
    return [];
  }

  Future<bool> toggleExclusion({
    required String featureKey,
    required String myCharKey,
    required int charID,
    required String charName,
  }) async {
    final shardKey = '${featureKey}_$myCharKey';
    final ids = List<int>.from(await getExcludedIds(featureKey, int.parse(myCharKey)));
    final idx = ids.indexOf(charID);
    final nowExcluded = idx == -1;
    if (nowExcluded) {
      ids.add(charID);
    } else {
      ids.removeAt(idx);
    }
    await store.set(shardKey, ids);
    if (nowExcluded) {
      await cacheCharName(charID, charName);
    }
    return nowExcluded;
  }

  Future<void> cacheCharName(int charID, String charName) async {
    if (charID <= 0 || charName.isEmpty) return;
    final bucketKey = 'synced_char_names_${charID % excludeNameBuckets}';
    final stored = await store.get(bucketKey);
    final bucket = normalizeExcludeMap(stored);
    bucket['$charID'] = charName;
    await store.set(bucketKey, bucket);
  }

  Future<Map<String, String>> loadSyncedCharNames() async {
    final merged = <String, String>{};
    for (var i = 0; i < excludeNameBuckets; i++) {
      final stored = await store.get('synced_char_names_$i');
      final bucket = normalizeExcludeMap(stored);
      bucket.forEach((key, value) {
        merged[key] = '$value';
      });
    }
    return merged;
  }
}
