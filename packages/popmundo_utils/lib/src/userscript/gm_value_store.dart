import '../core/events.dart';
import '../core/storage.dart';

/// Persists per-userscript `GM_setValue`/`GM_getValue` data (USM GM-polyfill).
///
/// One JSON blob per script id, mirroring the `userscript:<id>` groupName
/// prefix already used by [InstalledUserScript.groupNameFor].
class GmValueStore {
  GmValueStore(this.store);

  final KeyValueStore store;

  static String keyFor(String scriptId) => 'userscript:$scriptId:gmvalues';

  Future<Map<String, Object?>> loadAll(String scriptId) async {
    final raw = await store.get(keyFor(scriptId));
    if (raw is Map) return Map<String, Object?>.from(raw);
    return <String, Object?>{};
  }

  Future<void> setValue(String scriptId, String key, Object? value) async {
    final all = await loadAll(scriptId);
    all[key] = value;
    await store.set(keyFor(scriptId), all);
  }

  Future<void> deleteValue(String scriptId, String key) async {
    final all = await loadAll(scriptId);
    all.remove(key);
    await store.set(keyFor(scriptId), all);
  }

  Future<void> applyEvent(GmValueEvent event) {
    return event.action == 'delete'
        ? deleteValue(event.scriptId, event.key)
        : setValue(event.scriptId, event.key, event.value);
  }

  /// Removes the whole blob — call when a script is uninstalled to avoid an
  /// orphaned entry.
  Future<void> clearForScript(String scriptId) => store.remove(keyFor(scriptId));
}
