import 'dart:ui';

/// Locales the app shell supports (AD-014).
///
/// Single source of truth — consumed by the EasyLocalization wrapper in
/// main.dart and by the language selector.
const List<Locale> supportedAppLocales = [Locale('en'), Locale('pt')];

/// Asset directory holding the JSON translation catalogs (AD-014).
const String kTranslationsPath = 'assets/translations';

/// Locale used when the device locale is unsupported or a key is missing
/// from the active catalog (useFallbackTranslations).
const Locale fallbackAppLocale = Locale('en');
