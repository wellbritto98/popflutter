import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('always includes auto-login and userscripts', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
      includeDebugItem: false,
    );

    expect(items.map((e) => e.id), ['auto-login', 'userscripts', 'language']);
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
      includeDebugItem: true,
    );

    expect(
      items.map((e) => e.id),
      ['auto-login', 'userscripts', 'language', 'debug'],
    );
    expect(items[3].label, 'Debug panel');
    expect(
      items[3].subtitle,
      'Inspect host, network, console and eval JS',
    );
  });

  testWidgets("the debug item's onTap invokes onOpenDebugPanel exactly once",
      (tester) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () => callCount++,
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
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
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'userscripts').onTap();

    expect(callCount, 1);
    expect(items.firstWhere((e) => e.id == 'userscripts').label, 'Userscripts');
  });

  testWidgets("the auto-login item's onTap invokes onOpenAutoLogin exactly once",
      (tester) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () => callCount++,
      onOpenLanguage: () {},
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'auto-login').onTap();

    expect(callCount, 1);
  });

  testWidgets('defaults includeDebugItem to kDebugMode when omitted',
      (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () {},
    );

    expect(items.any((e) => e.id == 'auto-login'), isTrue);
    expect(items.any((e) => e.id == 'userscripts'), isTrue);
    expect(items.any((e) => e.id == 'language'), isTrue);
    expect(items.any((e) => e.id == 'debug'), kDebugMode);
  });

  testWidgets("the language item's onTap invokes onOpenLanguage exactly once",
      (tester) async {
    await pumpLocalized(tester, const SizedBox());
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      onOpenLanguage: () => callCount++,
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'language').onTap();

    expect(callCount, 1);
    expect(items.firstWhere((e) => e.id == 'language').label, 'Language');
  });

  testWidgets('PT locale resolves registry labels from the catalog',
      (tester) async {
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
      includeDebugItem: false,
    );

    expect(
      items.firstWhere((e) => e.id == 'auto-login').label,
      'Login automático',
    );
    expect(items.firstWhere((e) => e.id == 'language').label, 'Idioma');
  });
}
