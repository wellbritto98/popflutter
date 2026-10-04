import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('release schedules callback and EN/PT label are present', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var calls = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () => calls++,
      includeDebugItem: false,
    );
    final schedules = items.singleWhere((item) => item.id == 'schedules');
    expect(schedules.label, 'Schedules');
    expect(schedules.subtitle, 'Recurring local reminders');
    schedules.onTap();
    expect(calls, 1);
    expect(items.any((item) => item.id == 'debug'), false);
    await tester.pumpWidget(const SizedBox());
    await pumpLocalized(
      tester,
      const SizedBox(),
      startLocale: const Locale('pt'),
    );
    final pt = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () {},
      includeDebugItem: false,
    );
    expect(
      pt.singleWhere((item) => item.id == 'schedules').label,
      'Agendamentos',
    );
  });
  testWidgets('always includes auto-login and userscripts', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () {},
      includeDebugItem: false,
    );

    expect(items.map((e) => e.id), [
      'auto-login',
      'userscripts',
      'schedules',
      'language',
    ]);
    expect(items.first.label, 'Auto Login');
    expect(
      items.first.subtitle,
      'Credentials and character for TimedFetch login',
    );
  });

  testWidgets(
    'returns auto-login + userscripts + debug when includeDebugItem is true',
    (tester) async {
      await pumpLocalized(tester, const SizedBox());
      final items = buildAppMenuItems(
        onOpenDebugPanel: () {},
        onOpenUserScripts: () {},
        onOpenAutoLogin: () {},
        onOpenLanguage: () {},
        onOpenSchedules: () {},
        includeDebugItem: true,
      );

      expect(items.map((e) => e.id), [
        'auto-login',
        'userscripts',
        'schedules',
        'language',
        'debug',
      ]);
      expect(items[4].label, 'Debug panel');
      expect(items[4].subtitle, 'Inspect host, network, console and eval JS');
    },
  );

  testWidgets("the debug item's onTap invokes onOpenDebugPanel exactly once", (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () => callCount++,
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () {},
      includeDebugItem: true,
    );

    items.firstWhere((e) => e.id == 'debug').onTap();

    expect(callCount, 1);
  });

  testWidgets(
    "the userscripts item's onTap invokes onOpenUserScripts exactly once",
    (tester) async {
      await pumpLocalized(tester, const SizedBox());
      var callCount = 0;
      final items = buildAppMenuItems(
        onOpenDebugPanel: () {},
        onOpenUserScripts: () => callCount++,
        onOpenAutoLogin: () {},
        onOpenLanguage: () {},
        onOpenSchedules: () {},
        includeDebugItem: false,
      );

      items.firstWhere((e) => e.id == 'userscripts').onTap();

      expect(callCount, 1);
      expect(
        items.firstWhere((e) => e.id == 'userscripts').label,
        'Userscripts',
      );
    },
  );

  testWidgets(
    "the auto-login item's onTap invokes onOpenAutoLogin exactly once",
    (tester) async {
      await pumpLocalized(tester, const SizedBox());
      var callCount = 0;
      final items = buildAppMenuItems(
        onOpenDebugPanel: () {},
        onOpenUserScripts: () {},
        onOpenAutoLogin: () => callCount++,
        onOpenLanguage: () {},
        onOpenSchedules: () {},
        includeDebugItem: false,
      );

      items.firstWhere((e) => e.id == 'auto-login').onTap();

      expect(callCount, 1);
    },
  );

  testWidgets('defaults includeDebugItem to kDebugMode when omitted', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () {},
    );

    expect(items.any((e) => e.id == 'auto-login'), isTrue);
    expect(items.any((e) => e.id == 'userscripts'), isTrue);
    expect(items.any((e) => e.id == 'language'), isTrue);
    expect(items.any((e) => e.id == 'debug'), kDebugMode);
  });

  testWidgets("the language item's onTap invokes onOpenLanguage exactly once", (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () => callCount++,
      onOpenSchedules: () {},
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'language').onTap();

    expect(callCount, 1);
    expect(items.firstWhere((e) => e.id == 'language').label, 'Language');
  });

  testWidgets('PT locale resolves registry labels from the catalog', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const SizedBox(),
      startLocale: const Locale('pt'),
    );
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      onOpenSchedules: () {},
      includeDebugItem: false,
    );

    expect(
      items.firstWhere((e) => e.id == 'auto-login').label,
      'Login automático',
    );
    expect(items.firstWhere((e) => e.id == 'language').label, 'Idioma');
  });
}
