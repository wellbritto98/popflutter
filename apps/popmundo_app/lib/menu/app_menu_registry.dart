import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_menu_item.dart';

/// Single source of truth for the sidebar's item list.
List<AppMenuItem> buildAppMenuItems({
  required VoidCallback onOpenDebugPanel,
  required VoidCallback onOpenUserScripts,
  required VoidCallback onOpenAutoLogin,
  required VoidCallback onOpenLanguage,
  required VoidCallback onOpenSchedules,
  bool includeDebugItem = kDebugMode,
}) {
  return [
    AppMenuItem(
      id: 'auto-login',
      icon: Icons.key,
      label: 'menu.autoLogin'.tr(),
      subtitle: 'menu.autoLoginSubtitle'.tr(),
      onTap: onOpenAutoLogin,
    ),
    AppMenuItem(
      id: 'userscripts',
      icon: Icons.extension,
      label: 'menu.userscripts'.tr(),
      subtitle: 'menu.userscriptsSubtitle'.tr(),
      onTap: onOpenUserScripts,
    ),
    AppMenuItem(
      id: 'schedules',
      icon: Icons.schedule,
      label: 'menu.schedules'.tr(),
      subtitle: 'menu.schedulesSubtitle'.tr(),
      onTap: onOpenSchedules,
    ),
    AppMenuItem(
      id: 'language',
      icon: Icons.language,
      label: 'menu.language'.tr(),
      subtitle: 'menu.languageSubtitle'.tr(),
      onTap: onOpenLanguage,
    ),
    if (includeDebugItem)
      AppMenuItem(
        id: 'debug',
        icon: Icons.bug_report,
        label: 'menu.debugPanel'.tr(),
        subtitle: 'menu.debugPanelSubtitle'.tr(),
        onTap: onOpenDebugPanel,
      ),
  ];
}
