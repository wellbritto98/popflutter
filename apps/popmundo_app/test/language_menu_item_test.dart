import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/language/language_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('exposes the language id and label', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final item = languageMenuItem(onTap: () {});

    expect(item.id, 'language');
    expect(item.label, 'Language');
  });

  testWidgets('onTap invokes the supplied callback exactly once', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final item = languageMenuItem(onTap: () => callCount++);

    item.onTap();

    expect(callCount, 1);
  });

  testWidgets('PT locale resolves the label from the catalog', (tester) async {
    await pumpLocalized(
      tester,
      const SizedBox(),
      startLocale: const Locale('pt'),
    );

    expect(languageMenuItem(onTap: () {}).label, 'Idioma');
  });
}
