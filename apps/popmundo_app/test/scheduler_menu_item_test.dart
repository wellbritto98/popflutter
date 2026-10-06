import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('exposes the schedules id, label and subtitle', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final item = schedulesMenuItem(onTap: () {});

    expect(item.id, 'schedules');
    expect(item.label, 'Schedules');
    expect(item.subtitle, 'Recurring local reminders');
  });

  testWidgets('onTap invokes the supplied callback exactly once', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final item = schedulesMenuItem(onTap: () => callCount++);

    item.onTap();

    expect(callCount, 1);
  });

  testWidgets('PT locale resolves the label from the catalog', (tester) async {
    await pumpLocalized(
      tester,
      const SizedBox(),
      startLocale: const Locale('pt'),
    );

    expect(schedulesMenuItem(onTap: () {}).label, 'Agendamentos');
  });
}
