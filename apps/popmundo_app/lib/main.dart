import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:popmundo_webview/popmundo_webview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'l10n.dart';
import 'background/background_keepalive.dart';
import 'background/flutter_foreground_task_platform.dart';
import 'prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final prefs = await SharedPreferences.getInstance();
  final keepalive = BackgroundKeepalive(
    platform: FlutterForegroundTaskPlatform(),
    translator: (key) => key.tr(),
  );
  runApp(
    EasyLocalization(
      supportedLocales: supportedAppLocales,
      path: kTranslationsPath,
      fallbackLocale: fallbackAppLocale,
      useOnlyLangCode: true,
      useFallbackTranslations: true,
      child: PopmundoApp(
        runtime: InAppPopmundoRuntime(),
        store: SharedPreferencesStore(prefs),
        keepalive: keepalive,
      ),
    ),
  );
}
