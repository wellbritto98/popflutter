import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test-only asset loader that bypasses rootBundle's future cache.
///
/// CachingAssetBundle caches the Future per key. A cached future completed
/// under one test's FakeAsync zone never resumes when awaited from a later
/// test's zone — the second localized pump in a file hangs on the fallback
/// catalog load. Passing cache: false forces a fresh load in the current
/// zone every time.
class _NoCacheTestAssetLoader extends RootBundleAssetLoader {
  const _NoCacheTestAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final localePath = getLocalePath(path, locale);
    return json.decode(await rootBundle.loadString(localePath, cache: false));
  }
}

/// Pumps [child] inside a MaterialApp localized through the app's real
/// translation catalogs (I18N-06).
///
/// [startLocale] defaults to EN so the host/CI machine locale can never
/// change test outcomes; saveLocale is disabled for determinism.
///
/// Do NOT call `TestWidgetsFlutterBinding.ensureInitialized()` here:
/// re-entering binding setup inside a running test corrupts the
/// test binary messenger's asset channel and hangs later rootBundle
/// loads. `testWidgets` already guarantees an initialized binding.
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale startLocale = const Locale('en'),
  AssetLoader? assetLoader,
}) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: supportedAppLocales,
      path: kTranslationsPath,
      fallbackLocale: fallbackAppLocale,
      useOnlyLangCode: true,
      useFallbackTranslations: true,
      assetLoader: assetLoader ?? const _NoCacheTestAssetLoader(),
      saveLocale: false,
      startLocale: startLocale,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
