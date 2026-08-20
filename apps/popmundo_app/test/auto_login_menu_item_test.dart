import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/autologin/auto_login_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('exposes the auto-login id, label and subtitle', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final item = autoLoginMenuItem(onTap: () {});

    expect(item.id, 'auto-login');
    expect(item.label, 'Auto Login');
    expect(item.subtitle, 'Credentials and character for TimedFetch login');
  });

  testWidgets('onTap invokes the supplied callback exactly once', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final item = autoLoginMenuItem(onTap: () => callCount++);

    item.onTap();

    expect(callCount, 1);
  });

  testWidgets('PT locale resolves the label from the catalog', (tester) async {
    await pumpLocalized(
      tester,
      const SizedBox(),
      startLocale: const Locale('pt'),
    );

    expect(autoLoginMenuItem(onTap: () {}).label, 'Login automático');
  });
}
