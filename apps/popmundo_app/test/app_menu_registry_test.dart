import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_item.dart';
import 'package:popmundo_app/menu/app_menu_registry.dart';

/// The registry no longer knows which features exist — each feature owns its
/// own `AppMenuItem` builder (tested in `*_menu_item_test.dart`). What is left
/// to prove here is ordering and the debug gate, so stubs are the right input:
/// using the real feature builders would couple this back to feature identity.
AppMenuItem _stub(String id, {VoidCallback? onTap}) => AppMenuItem(
  id: id,
  icon: Icons.circle,
  label: id,
  onTap: onTap ?? () {},
);

void main() {
  test('preserves the order the caller passed', () {
    final items = buildAppMenuItems(
      items: [_stub('a'), _stub('b'), _stub('c')],
      includeDebugItem: false,
    );

    expect(items.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('appends the debug item last when includeDebugItem is true', () {
    final items = buildAppMenuItems(
      items: [_stub('a'), _stub('b'), _stub('c')],
      debugItem: _stub('debug'),
      includeDebugItem: true,
    );

    expect(items.map((e) => e.id), ['a', 'b', 'c', 'debug']);
    expect(items.last.id, 'debug');
  });

  test('omits the debug item when includeDebugItem is false', () {
    final items = buildAppMenuItems(
      items: [_stub('a')],
      debugItem: _stub('debug'),
      includeDebugItem: false,
    );

    expect(items.map((e) => e.id), ['a']);
  });

  test('omits the debug entry when no debugItem is supplied', () {
    final items = buildAppMenuItems(items: [_stub('a')], includeDebugItem: true);

    expect(items.map((e) => e.id), ['a']);
  });

  test('defaults includeDebugItem to kDebugMode when omitted', () {
    final items = buildAppMenuItems(
      items: [_stub('a')],
      debugItem: _stub('debug'),
    );

    expect(items.any((e) => e.id == 'a'), isTrue);
    expect(items.any((e) => e.id == 'debug'), kDebugMode);
  });

  test('passes each item through untouched, onTap included', () {
    var calls = 0;
    final items = buildAppMenuItems(
      items: [_stub('a', onTap: () => calls++)],
      includeDebugItem: false,
    );

    items.single.onTap();

    expect(calls, 1);
  });
}
