import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_menu_item.dart';

/// Single source of truth for the sidebar's item list.
///
/// Adding a new entry here is the only change required to surface it in
/// `AppSidebar` — no existing widget or menu item needs to change.
List<AppMenuItem> buildAppMenuItems({
  required VoidCallback onOpenDebugPanel,
  bool includeDebugItem = kDebugMode,
}) {
  return [
    if (includeDebugItem)
      AppMenuItem(
        id: 'debug',
        icon: Icons.bug_report,
        label: 'Debug panel',
        subtitle: 'Inspect host, network, console and eval JS',
        onTap: onOpenDebugPanel,
      ),
  ];
}
