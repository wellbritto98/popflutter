import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

void main() {
  test('always includes auto-login and userscripts', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      includeDebugItem: false,
    );

    expect(items.map((e) => e.id), ['auto-login', 'userscripts']);
    expect(items.first.label, 'Auto Login');
  });

  test('returns auto-login + userscripts + debug when includeDebugItem is true',
      () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      includeDebugItem: true,
    );

    expect(items.map((e) => e.id), ['auto-login', 'userscripts', 'debug']);
    expect(items[2].label, 'Debug panel');
  });

  test("the debug item's onTap invokes onOpenDebugPanel exactly once", () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () => callCount++,
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
      includeDebugItem: true,
    );

    items.firstWhere((e) => e.id == 'debug').onTap();

    expect(callCount, 1);
  });

  test("the userscripts item's onTap invokes onOpenUserScripts exactly once",
      () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () => callCount++,
      onOpenAutoLogin: () {},
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'userscripts').onTap();

    expect(callCount, 1);
  });

  test("the auto-login item's onTap invokes onOpenAutoLogin exactly once", () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () => callCount++,
      includeDebugItem: false,
    );

    items.firstWhere((e) => e.id == 'auto-login').onTap();

    expect(callCount, 1);
  });

  test('defaults includeDebugItem to kDebugMode when omitted', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      onOpenAutoLogin: () {},
    );

    expect(items.any((e) => e.id == 'auto-login'), isTrue);
    expect(items.any((e) => e.id == 'userscripts'), isTrue);
    expect(items.any((e) => e.id == 'debug'), kDebugMode);
  });
}
