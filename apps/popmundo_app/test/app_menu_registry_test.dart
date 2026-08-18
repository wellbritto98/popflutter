import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

void main() {
  test('returns exactly one debug item when includeDebugItem is true', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      includeDebugItem: true,
    );

    expect(items.length, 1);
    expect(items.single.id, 'debug');
    expect(items.single.label, 'Debug panel');
  });

  test('returns an empty list when includeDebugItem is false', () {
    final items = buildAppMenuItems(
      onOpenDebugPanel: () {},
      includeDebugItem: false,
    );

    expect(items, isEmpty);
  });

  test("the debug item's onTap invokes onOpenDebugPanel exactly once", () {
    var callCount = 0;
    final items = buildAppMenuItems(
      onOpenDebugPanel: () => callCount++,
      includeDebugItem: true,
    );

    items.single.onTap();

    expect(callCount, 1);
  });

  test('defaults includeDebugItem to kDebugMode when omitted', () {
    final items = buildAppMenuItems(onOpenDebugPanel: () {});

    expect(items.length, kDebugMode ? 1 : 0);
  });
}
