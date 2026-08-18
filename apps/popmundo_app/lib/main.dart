import 'package:flutter/material.dart';
import 'package:popmundo_webview/popmundo_webview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    PopmundoApp(
      runtime: InAppPopmundoRuntime(),
      store: SharedPreferencesStore(prefs),
    ),
  );
}
