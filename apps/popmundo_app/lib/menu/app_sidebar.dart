import 'package:flutter/material.dart';

import 'app_menu_item.dart';

/// Renders the sidebar `Drawer` content from a list of [AppMenuItem]s.
///
/// The entire visible item list is derived from [items] — no entry is ever
/// hardcoded here, so adding a menu item never requires touching this file.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.items});

  final List<AppMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('app-sidebar'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Popmundo'),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No options available.',
                key: Key('menu-empty'),
              ),
            )
          else
            for (final item in items)
              ListTile(
                key: Key('menu-item-${item.id}'),
                leading: Icon(item.icon),
                title: Text(item.label),
                subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                onTap: () {
                  Scaffold.maybeOf(context)?.closeDrawer();
                  item.onTap();
                },
              ),
        ],
      ),
    );
  }
}
