import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../menu/app_menu_item.dart';

/// This feature's sidebar entry. See `lib/menu/README.md`.
AppMenuItem userscriptsMenuItem({required VoidCallback onTap}) => AppMenuItem(
  id: 'userscripts',
  icon: Icons.extension,
  label: 'menu.userscripts'.tr(),
  subtitle: 'menu.userscriptsSubtitle'.tr(),
  onTap: onTap,
);
