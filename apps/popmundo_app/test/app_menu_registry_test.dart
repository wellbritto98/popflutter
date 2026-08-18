import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

void main() {
  test('always includes the userscripts item', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      includeDebugItem: false,
    );

    expect(items.length, 1);
    expect(items.single.id, 'userscripts');
    expect(items.single.label, 'Userscripts');
  });

  test('returns userscripts + debug when includeDebugItem is true', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
      includeDebugItem: true,
    );

    expect(items.map((e) => e.id), ['userscripts', 'debug']);
    expect(items[1].label, 'Debug panel');
  });

  test("the debug item's onTap invokes onOpenDebugPanel exactly once", () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () => callCount++,
      onOpenUserScripts: () {},
      includeDebugItem: true,
    );

    items.firstWhere((e) => e.id == 'debug').onTap();

    expect(callCount, 1);
  });

  test("the userscripts item's onTap invokes onOpenUserScripts exactly once", () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () => callCount++,
      includeDebugItem: false,
    );

    items.single.onTap();

    expect(callCount, 1);
  });

  test('defaults includeDebugItem to kDebugMode when omitted', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      onOpenUserScripts: () {},
    );

    expect(items.any((e) => e.id == 'userscripts'), isTrue);
    expect(items.any((e) => e.id == 'debug'), kDebugMode);
  });
}
