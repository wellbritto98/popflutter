import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../menu/app_menu_item.dart';

/// This feature's sidebar entry. See `lib/menu/README.md`.
AppMenuItem languageMenuItem({required VoidCallback onTap}) => AppMenuItem(
  id: 'language',
  icon: Icons.language,
  label: 'menu.language'.tr(),
  subtitle: 'menu.languageSubtitle'.tr(),
  onTap: onTap,
);
