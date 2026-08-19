import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_menu_item.dart';
import 'gm_menu_command_item.dart';

/// Renders the sidebar `Drawer` content from a list of [AppMenuItem]s.
///
/// The entire visible item list is derived from [items] — no entry is ever
/// hardcoded here, so adding a menu item never requires touching this file.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    this.gmMenuCommands = const [],
    this.onGmMenuCommand,
    this.gmMenuSectionTitle,
  });

  final List<AppMenuItem> items;
  final List<GmMenuCommandItem> gmMenuCommands;
  final ValueChanged<GmMenuCommandItem>? onGmMenuCommand;
  final String? gmMenuSectionTitle;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('app-sidebar'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _SidebarBrandHeader(),
          const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'menu.empty'.tr(),
                key: const Key('menu-empty'),
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
          if (gmMenuCommands.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                gmMenuSectionTitle ?? 'menu.gmCommands'.tr(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final cmd in gmMenuCommands)
              ListTile(
                key: Key('gm-menu-${cmd.commandId}'),
                leading: const Icon(Icons.play_arrow_outlined),
                title: Text(cmd.caption),
                onTap: () {
                  Scaffold.maybeOf(context)?.closeDrawer();
                  onGmMenuCommand?.call(cmd);
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// Compact brand strip: black plate matching the logo art, wordmark kept small.
class _SidebarBrandHeader extends StatelessWidget {
  const _SidebarBrandHeader();

  static const _logoHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 100,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/popflutter_logo.png',
        height: _logoHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Popflutter',
        key: const Key('sidebar-logo'),
      ),
    );
  }
}
