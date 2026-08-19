import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/language/language_selector.dart';

import 'localization_helpers.dart';

Widget _harness() {
  return Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          Text('menu.autoLogin'.tr()),
          TextButton(
            key: const Key('open-language'),
            onPressed: () => showLanguageDialog(context),
            child: const Text('open'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-language')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog lists exactly English and Português and marks the active locale',
      (tester) async {
    await pumpLocalized(tester, _harness());
    await _openDialog(tester);

    expect(find.byKey(const Key('language-dialog')), findsOneWidget);
    expect(find.byKey(const Key('language-option-en')), findsOneWidget);
    expect(find.byKey(const Key('language-option-pt')), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);

    final enTile = tester.widget<RadioListTile<String>>(
      find.byKey(const Key('language-option-en')),
    );
    final ptTile = tester.widget<RadioListTile<String>>(
      find.byKey(const Key('language-option-pt')),
    );
    expect(enTile.groupValue, 'en');
    expect(enTile.value, 'en');
    expect(ptTile.groupValue, 'en');
    expect(ptTile.value, 'pt');
  });

  testWidgets('selecting Português re-renders shell strings live', (tester) async {
    await pumpLocalized(tester, _harness());
    expect(find.text('Auto Login'), findsOneWidget);

    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('language-option-pt')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language-dialog')), findsNothing);
    expect(find.text('Login automático'), findsOneWidget);
    expect(find.text('Auto Login'), findsNothing);
  });

  testWidgets('saved PT locale renders Portuguese on a fresh pump',
      (tester) async {
    await pumpLocalized(
      tester,
      _harness(),
      startLocale: const Locale('pt'),
    );
    expect(find.text('Login automático'), findsOneWidget);

    await _openDialog(tester);
    final ptTile = tester.widget<RadioListTile<String>>(
      find.byKey(const Key('language-option-pt')),
    );
    expect(ptTile.groupValue, 'pt');
  });

  testWidgets('re-selecting the active locale closes the dialog', (tester) async {
    await pumpLocalized(tester, _harness());
    await _openDialog(tester);

    await tester.tap(find.byKey(const Key('language-option-en')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language-dialog')), findsNothing);
    expect(find.text('Auto Login'), findsOneWidget);
  });
}
