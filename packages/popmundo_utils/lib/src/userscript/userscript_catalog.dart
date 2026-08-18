import '../storage.dart';
import 'userscript_parser.dart';

class UserScriptCatalogException implements Exception {
  UserScriptCatalogException(this.message);
  final String message;

  @override
  String toString() => 'UserScriptCatalogException: $message';
}

class InstalledUserScript {
  InstalledUserScript({
    required this.id,
    required this.sourceUrl,
    required this.name,
    required this.enabled,
    required this.source,
    required this.headers,
    required this.installedAt,
    required this.runAt,
    required this.forMainFrameOnly,
    this.version,
    this.description,
  });

  final String id;
  final String sourceUrl;
  final String name;
  final String? version;
  final String? description;
  final bool enabled;
  final String source;
  final Map<String, List<String>> headers;
  final DateTime installedAt;
  final UserScriptRunAt runAt;
  final bool forMainFrameOnly;

  static String groupNameFor(String id) => 'userscript:$id';

  String get groupName => groupNameFor(id);

  InstalledUserScript copyWith({bool? enabled}) {
    return InstalledUserScript(
      id: id,
      sourceUrl: sourceUrl,
      name: name,
      version: version,
      description: description,
      enabled: enabled ?? this.enabled,
      source: source,
      headers: headers,
      installedAt: installedAt,
      runAt: runAt,
      forMainFrameOnly: forMainFrameOnly,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'sourceUrl': sourceUrl,
        'name': name,
        'version': version,
        'description': description,
        'enabled': enabled,
        'source': source,
        'headers': headers,
        'installedAt': installedAt.toIso8601String(),
        'runAt': runAt.name,
        'forMainFrameOnly': forMainFrameOnly,
      };

  factory InstalledUserScript.fromJson(Map<String, dynamic> json) {
    final headersRaw = json['headers'];
    final headers = <String, List<String>>{};
    if (headersRaw is Map) {
      headersRaw.forEach((key, value) {
        if (value is List) {
          headers['$key'] = value.map((e) => '$e').toList();
        }
      });
    }
    final runAtName = '${json['runAt'] ?? 'documentEnd'}';
    final runAt = runAtName == UserScriptRunAt.documentStart.name
        ? UserScriptRunAt.documentStart
        : UserScriptRunAt.documentEnd;

    return InstalledUserScript(
      id: '${json['id']}',
      sourceUrl: '${json['sourceUrl']}',
      name: '${json['name']}',
      version: json['version'] == null ? null : '${json['version']}',
      description:
          json['description'] == null ? null : '${json['description']}',
      enabled: json['enabled'] == true,
      source: '${json['source'] ?? ''}',
      headers: headers,
      installedAt: DateTime.parse('${json['installedAt']}'),
      runAt: runAt,
      forMainFrameOnly: json['forMainFrameOnly'] == true,
    );
  }
}

/// Persists installed userscripts under a single [KeyValueStore] key.
class UserScriptCatalog {
  UserScriptCatalog(this.store, {this.storageKey = defaultStorageKey});

  static const defaultStorageKey = 'userscripts.v1';

  final KeyValueStore store;
  final String storageKey;

  Future<List<InstalledUserScript>> list() async {
    return _readAll();
  }

  Future<List<InstalledUserScript>> enabledOnly() async {
    return (await _readAll()).where((s) => s.enabled).toList();
  }

  Future<InstalledUserScript> add(InstalledUserScript script) async {
    final all = await _readAll();
    if (all.any((s) => s.sourceUrl == script.sourceUrl)) {
      throw UserScriptCatalogException(
        'Script already installed from ${script.sourceUrl}',
      );
    }
    if (all.any((s) => s.id == script.id)) {
      throw UserScriptCatalogException('Script id already exists: ${script.id}');
    }
    all.add(script);
    await _writeAll(all);
    return script;
  }

  Future<InstalledUserScript> toggleEnabled(String id) async {
    final all = await _readAll();
    final index = all.indexWhere((s) => s.id == id);
    if (index < 0) {
      throw UserScriptCatalogException('Unknown userscript id: $id');
    }
    final updated = all[index].copyWith(enabled: !all[index].enabled);
    all[index] = updated;
    await _writeAll(all);
    return updated;
  }

  Future<void> remove(String id) async {
    final all = await _readAll();
    final next = all.where((s) => s.id != id).toList();
    if (next.length == all.length) {
      throw UserScriptCatalogException('Unknown userscript id: $id');
    }
    await _writeAll(next);
  }

  Future<List<InstalledUserScript>> _readAll() async {
    final raw = await store.get(storageKey);
    if (raw == null) return [];
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map)
          InstalledUserScript.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> _writeAll(List<InstalledUserScript> scripts) async {
    await store.set(storageKey, scripts.map((s) => s.toJson()).toList());
  }
}
