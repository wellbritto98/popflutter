import 'package:flutter/material.dart';

import 'menu/app_menu_item.dart';
import 'menu/app_sidebar.dart';

/// The app's `Scaffold`: hosts [AppSidebar] as its drawer, the FAB that
/// opens it, and the [body] slot. Runtime-agnostic — knows nothing about
/// `InAppPopmundoRuntime`, `PopmundoEventBus`, or `HostTracker`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.items, required this.body});

  final List<AppMenuItem> items;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppSidebar(items: items),
      // DBG-01: the drawer must never swallow horizontal drags meant for
      // the WebView, so the edge-swipe gesture to open it is disabled.
      drawerEnableOpenDragGesture: false,
      body: body,
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
          key: const Key('menu-toggle'),
          mini: true,
          onPressed: () => Scaffold.of(context).openDrawer(),
          child: const Icon(Icons.menu),
        ),
      ),
    );
  }
}
