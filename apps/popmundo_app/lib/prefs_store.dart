import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this.prefs);

  final SharedPreferences prefs;

  @override
  Future<Object?> get(String key) async {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  @override
  Future<void> set(String key, Object? value) async {
    await prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    await prefs.remove(key);
  }
}
