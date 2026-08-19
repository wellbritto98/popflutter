import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/l10n.dart';

import 'localization_helpers.dart';

/// Boot smoke (I18N-01 / I18N-05 / I18N-07 wiring): catalogs load and `tr()`
/// resolves under the supported locales.
///
/// Unsupported-device-locale fallback cannot be faked with `startLocale`
/// (`startLocale: Locale('fr')` forces `fr` and tries to load `fr.json`;
/// it is not the device-locale path). Production omits `startLocale` so
/// EasyLocalization uses `Platform.localeName` + `fallbackLocale`. VM tests
/// cannot override the platform locale, so AC2 is covered by: (1) the
/// composition-root config, (2) the supported/fallback locale contract.
void main() {
  Widget probe() => Builder(
        builder: (context) => Scaffold(body: Text('menu.empty'.tr())),
      );

  testWidgets('EN locale renders the English catalog', (tester) async {
    await pumpLocalized(tester, probe(), startLocale: const Locale('en'));
    expect(find.text('No options available.'), findsOneWidget);
  });

  testWidgets('PT locale renders the Portuguese catalog', (tester) async {
    await pumpLocalized(tester, probe(), startLocale: const Locale('pt'));
    expect(find.text('Nenhuma opção disponível.'), findsOneWidget);
  });

  test('unsupported language codes fall back to English (I18N-01 AC2)', () {
    expect(supportedAppLocales, const [Locale('en'), Locale('pt')]);
    expect(fallbackAppLocale, const Locale('en'));
    expect(_localeForLanguageCode('pt'), const Locale('pt'));
    expect(_localeForLanguageCode('en'), const Locale('en'));
    expect(_localeForLanguageCode('fr'), const Locale('en'));
  });

  test('composition root uses device locale with English fallback', () {
    final source = _open([
      'lib/main.dart',
      'apps/popmundo_app/lib/main.dart',
    ]);
    expect(source.contains('fallbackLocale: fallbackAppLocale'), isTrue);
    expect(source.contains('useFallbackTranslations: true'), isTrue);
    expect(source.contains('useOnlyLangCode: true'), isTrue);
    expect(source.contains('startLocale:'), isFalse);
  });

  test('MaterialApp receives locale wiring from EasyLocalization', () {
    final source = _open([
      'lib/app.dart',
      'apps/popmundo_app/lib/app.dart',
    ]);
    expect(
      source.contains('localizationsDelegates: context.localizationDelegates'),
      isTrue,
    );
    expect(
      source.contains('supportedLocales: context.supportedLocales'),
      isTrue,
    );
    expect(source.contains('locale: context.locale'), isTrue);
    expect(source.contains("title: 'app.title'.tr()"), isTrue);
  });

  testWidgets(
      'missing PT key displays the English value and never the raw key',
      (tester) async {
    await pumpLocalized(
      tester,
      probe(),
      startLocale: const Locale('pt'),
      assetLoader: const _PtMissingMenuEmptyLoader(),
    );
    expect(find.text('No options available.'), findsOneWidget);
    expect(find.text('menu.empty'), findsNothing);
    expect(find.text('Nenhuma opção disponível.'), findsNothing);
  });
}

Locale _localeForLanguageCode(String languageCode) {
  for (final locale in supportedAppLocales) {
    if (locale.languageCode == languageCode) return locale;
  }
  return fallbackAppLocale;
}

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}

/// Serves the real catalogs except `menu.empty` is stripped from PT so
/// I18N-05 can assert EN fallback (never the raw key).
class _PtMissingMenuEmptyLoader extends RootBundleAssetLoader {
  const _PtMissingMenuEmptyLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final localePath = getLocalePath(path, locale);
    final data = json.decode(
      await rootBundle.loadString(localePath, cache: false),
    ) as Map<String, dynamic>;
    if (locale.languageCode == 'pt') {
      (data['menu'] as Map).remove('empty');
    }
    return data;
  }
}
