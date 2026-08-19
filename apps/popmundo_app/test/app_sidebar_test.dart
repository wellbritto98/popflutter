import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/menu/app_menu_item.dart';
import 'package:popmundo_app/menu/app_sidebar.dart';

import 'localization_helpers.dart';

Widget _harness(List<AppMenuItem> items) {
  return Scaffold(
    drawer: AppSidebar(items: items),
    body: Builder(
      builder: (context) => ElevatedButton(
        key: const Key('open-drawer'),
        onPressed: () => Scaffold.of(context).openDrawer(),
        child: const Text('open'),
      ),
    ),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-drawer')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the drawer with the Popflutter logo header',
      (tester) async {
    await pumpLocalized(
      tester,
      _harness(const [
        AppMenuItem(
          id: 'debug',
          icon: Icons.bug_report,
          label: 'Debug panel',
          onTap: _noop,
        ),
      ]),
    );
    await _openDrawer(tester);

    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-logo')), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('renders one ListTile per item with icon and label',
      (tester) async {
    await pumpLocalized(
      tester,
      _harness(const [
        AppMenuItem(
          id: 'debug',
          icon: Icons.bug_report,
          label: 'Debug panel',
          onTap: _noop,
        ),
        AppMenuItem(
          id: 'other',
          icon: Icons.settings,
          label: 'Other item',
          onTap: _noop,
        ),
      ]),
    );
    await _openDrawer(tester);

    expect(find.byKey(const Key('menu-item-debug')), findsOneWidget);
    expect(find.byKey(const Key('menu-item-other')), findsOneWidget);
    expect(find.text('Debug panel'), findsOneWidget);
    expect(find.text('Other item'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('menu-item-debug')),
        matching: find.byIcon(Icons.bug_report),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders the subtitle when the item has one', (tester) async {
    await pumpLocalized(
      tester,
      _harness(const [
        AppMenuItem(
          id: 'debug',
          icon: Icons.bug_report,
          label: 'Debug panel',
          subtitle: 'Inspect the app',
          onTap: _noop,
        ),
      ]),
    );
    await _openDrawer(tester);

    expect(find.text('Inspect the app'), findsOneWidget);
  });

  testWidgets('tapping an item closes the drawer and invokes onTap',
      (tester) async {
    var tapped = 0;
    await pumpLocalized(
      tester,
      _harness([
        AppMenuItem(
          id: 'debug',
          icon: Icons.bug_report,
          label: 'Debug panel',
          onTap: () => tapped++,
        ),
      ]),
    );
    await _openDrawer(tester);

    await tester.tap(find.byKey(const Key('menu-item-debug')));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(find.byKey(const Key('app-sidebar')), findsNothing);
  });

  testWidgets('shows the empty state and no ListTiles when items is empty',
      (tester) async {
    await pumpLocalized(tester, _harness(const []));
    await _openDrawer(tester);

    expect(find.byKey(const Key('menu-empty')), findsOneWidget);
    expect(find.text('No options available.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}

void _noop() {}
