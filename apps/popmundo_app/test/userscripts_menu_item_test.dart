import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/userscripts/userscripts_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('exposes the userscripts id and label', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final item = userscriptsMenuItem(onTap: () {});

    expect(item.id, 'userscripts');
    expect(item.label, 'Userscripts');
  });

  testWidgets('onTap invokes the supplied callback exactly once', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final item = userscriptsMenuItem(onTap: () => callCount++);

    item.onTap();

    expect(callCount, 1);
  });
}
