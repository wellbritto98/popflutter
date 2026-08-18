import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/app_shell.dart';
import 'package:popmundo_app/menu/app_menu_item.dart';

void main() {
  testWidgets('renders the drawer content and the given body', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const Text('shell-body'),
      ),
    ));

    expect(find.text('shell-body'), findsOneWidget);

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('menu-item-debug')), findsOneWidget);
  });

  testWidgets('disables the drawer edge-swipe gesture (DBG-01)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppShell(items: [], body: SizedBox.shrink()),
    ));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.drawerEnableOpenDragGesture, isFalse);
  });

  testWidgets('always renders the FAB when items is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppShell(items: [], body: SizedBox.shrink()),
    ));

    final fabFinder = find.byKey(const Key('menu-toggle'));
    expect(fabFinder, findsOneWidget);
    expect(tester.widget<FloatingActionButton>(fabFinder).mini, isTrue);
    expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.menu)), findsOneWidget);
  });

  testWidgets('always renders the FAB when items is non-empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const SizedBox.shrink(),
      ),
    ));

    expect(find.byKey(const Key('menu-toggle')), findsOneWidget);
  });

  testWidgets('tapping the FAB opens the AppSidebar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppShell(
        items: const [
          AppMenuItem(id: 'debug', icon: Icons.bug_report, label: 'Debug panel', onTap: _noop),
        ],
        body: const SizedBox.shrink(),
      ),
    ));

    expect(find.byKey(const Key('app-sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('menu-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sidebar')), findsOneWidget);
  });
}

void _noop() {}
