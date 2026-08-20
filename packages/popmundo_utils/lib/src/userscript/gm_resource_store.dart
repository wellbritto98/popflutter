import 'dart:convert';

import '../core/storage.dart';

/// One persisted `@resource` body keyed by resource name.
class GmResourceEntry {
  const GmResourceEntry({required this.mimeType, required this.base64});

  final String mimeType;
  final String base64;

  Map<String, Object?> toJson() => {
        'mimeType': mimeType,
        'base64': base64,
      };

  factory GmResourceEntry.fromJson(Map<String, dynamic> json) {
    return GmResourceEntry(
      mimeType: '${json['mimeType'] ?? 'application/octet-stream'}',
      base64: '${json['base64'] ?? ''}',
    );
  }

  /// Builds a `data:` URL suitable for `GM.getResourceUrl`.
  String toDataUrl({String? overrideMimeType}) {
    final mime = overrideMimeType?.trim();
    final type = (mime != null && mime.isNotEmpty) ? mime : mimeType;
    return 'data:$type;base64,$base64';
  }
}

/// Persists downloaded `@resource` bodies per userscript id.
class GmResourceStore {
  GmResourceStore(this.store);

  final KeyValueStore store;

  static String keyFor(String scriptId) => 'userscript:$scriptId:gmresources';

  Future<Map<String, GmResourceEntry>> loadAll(String scriptId) async {
    final raw = await store.get(keyFor(scriptId));
    if (raw is! Map) return {};
    final result = <String, GmResourceEntry>{};
    raw.forEach((key, value) {
      if (value is Map) {
        result['$key'] = GmResourceEntry.fromJson(Map<String, dynamic>.from(value));
      }
    });
    return result;
  }

  Future<GmResourceEntry?> get(String scriptId, String name) async {
    final all = await loadAll(scriptId);
    return all[name];
  }

  Future<void> setAll(String scriptId, Map<String, GmResourceEntry> resources) {
    final encoded = <String, Object?>{
      for (final e in resources.entries) e.key: e.value.toJson(),
    };
    return store.set(keyFor(scriptId), encoded);
  }

  Future<void> clearForScript(String scriptId) => store.remove(keyFor(scriptId));

  /// Encodes [bytes] as base64 for storage.
  static String encodeBytes(List<int> bytes) => base64Encode(bytes);
}
