import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_menu_item.dart';

/// Single source of truth for the sidebar's item list.
///
/// Adding a new entry here is the only change required to surface it in
/// `AppSidebar` — no existing widget or menu item needs to change.
List<AppMenuItem> buildAppMenuItems({
  required VoidCallback onOpenDebugPanel,
  required VoidCallback onOpenUserScripts,
  required VoidCallback onOpenAutoLogin,
  bool includeDebugItem = kDebugMode,
}) {
  return [
    AppMenuItem(
      id: 'auto-login',
      icon: Icons.key,
      label: 'Auto Login',
      subtitle: 'Credentials and character for TimedFetch login',
      onTap: onOpenAutoLogin,
    ),
    AppMenuItem(
      id: 'userscripts',
      icon: Icons.extension,
      label: 'Userscripts',
      subtitle: 'Import, enable and remove .user.js scripts',
      onTap: onOpenUserScripts,
    ),
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
