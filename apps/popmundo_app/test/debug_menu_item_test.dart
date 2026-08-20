import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/debug_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('exposes the debug id, label and subtitle', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final item = debugMenuItem(onTap: () {});

    expect(item.id, 'debug');
    expect(item.label, 'Debug panel');
    expect(item.subtitle, 'Inspect host, network, console and eval JS');
  });

  testWidgets('onTap invokes the supplied callback exactly once', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final item = debugMenuItem(onTap: () => callCount++);

    item.onTap();

    expect(callCount, 1);
  });
}
