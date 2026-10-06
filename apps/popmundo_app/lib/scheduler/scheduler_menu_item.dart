import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../menu/app_menu_item.dart';

/// This feature's sidebar entry. Lives next to `SchedulerScreen` so the menu
/// registry stays unaware of schedules.
AppMenuItem schedulesMenuItem({required VoidCallback onTap}) => AppMenuItem(
  id: 'schedules',
  icon: Icons.schedule,
  label: 'menu.schedules'.tr(),
  subtitle: 'menu.schedulesSubtitle'.tr(),
  onTap: onTap,
);
