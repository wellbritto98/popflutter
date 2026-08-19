import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/app_shell.dart';
import 'package:popmundo_app/menu/app_menu_item.dart';

import 'localization_helpers.dart';

void main() {
  testWidgets('renders the drawer content and the given body', (tester) async {
    await pumpLocalized(
      tester,
      AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const Text('shell-body'),
      ),
    );

    expect(find.text('shell-body'), findsOneWidget);

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('menu-item-debug')), findsOneWidget);
  });

  testWidgets('disables the drawer edge-swipe gesture (DBG-01)', (tester) async {
    await pumpLocalized(
      tester,
      const AppShell(items: [], body: SizedBox.shrink()),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.drawerEnableOpenDragGesture, isFalse);
  });

  testWidgets('always renders the FAB when items is empty', (tester) async {
    await pumpLocalized(
      tester,
      const AppShell(items: [], body: SizedBox.shrink()),
    );

    final fabFinder = find.byKey(const Key('menu-toggle'));
    expect(fabFinder, findsOneWidget);
    expect(tester.widget<FloatingActionButton>(fabFinder).mini, isTrue);
    expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.menu)), findsOneWidget);
  });

  testWidgets('always renders the FAB when items is non-empty', (tester) async {
    await pumpLocalized(
      tester,
      AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const SizedBox.shrink(),
      ),
    );

    expect(find.byKey(const Key('menu-toggle')), findsOneWidget);
  });

  testWidgets('tapping the FAB opens the AppSidebar', (tester) async {
    await pumpLocalized(
      tester,
      AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const SizedBox.shrink(),
      ),
    );

    expect(find.byKey(const Key('app-sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('menu-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
  });

  testWidgets('tapping outside the open drawer closes it (MENU-01 AC4)', (tester) async {
    await pumpLocalized(
      tester,
      AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const SizedBox.shrink(),
      ),
    );

    await tester.tap(find.byKey(const Key('menu-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);

    // Tap the scrim outside the drawer's own width.
    await tester.tapAt(const Offset(700, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sidebar')), findsNothing);
  });

  testWidgets(
    'popping the navigator (Android back) closes the open drawer without touching WebView content (MENU-01 AC4)',
    (tester) async {
      await pumpLocalized(
        tester,
        AppShell(
          items: const [
            AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
          ],
          body: const Text('webview-body'),
        ),
      );

      await tester.tap(find.byKey(const Key('menu-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-sidebar')), findsOneWidget);

      final popped = await Navigator.of(tester.element(find.byType(Scaffold))).maybePop();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.byKey(const Key('app-sidebar')), findsNothing);
      expect(find.text('webview-body'), findsOneWidget);
    },
  );
}

void _noop() {}
