import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app_menu_item.dart';

/// The debug panel's sidebar entry. Unlike the feature entries this one lives
/// in `menu/`: debug is a shell capability, not a feature slice, and it is the
/// item `buildAppMenuItems`'s `includeDebugItem` gate exists for.
AppMenuItem debugMenuItem({required VoidCallback onTap}) => AppMenuItem(
  id: 'debug',
  icon: Icons.bug_report,
  label: 'menu.debugPanel'.tr(),
  subtitle: 'menu.debugPanelSubtitle'.tr(),
  onTap: onTap,
);
