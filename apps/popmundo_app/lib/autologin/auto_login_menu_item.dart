import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../menu/app_menu_item.dart';

/// This feature's sidebar entry. Lives here, next to the screen it opens, so
/// adding or changing a feature never touches the menu registry's signature.
AppMenuItem autoLoginMenuItem({required VoidCallback onTap}) => AppMenuItem(
  id: 'auto-login',
  icon: Icons.key,
  label: 'menu.autoLogin'.tr(),
  subtitle: 'menu.autoLoginSubtitle'.tr(),
  onTap: onTap,
);
