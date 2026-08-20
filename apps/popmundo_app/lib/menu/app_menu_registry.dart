import 'package:flutter/foundation.dart';

import 'app_menu_item.dart';

/// Assembles the sidebar's fixed item list.
///
/// This function knows nothing about which features exist — each feature owns
/// its own `AppMenuItem` builder in its own folder (see `lib/menu/README.md`).
/// All this does is preserve the caller's order and append the debug entry
/// last, when the gate allows it. Adding a feature therefore never changes
/// this signature.
List<AppMenuItem> buildAppMenuItems({
  required List<AppMenuItem> items,
  AppMenuItem? debugItem,
  bool includeDebugItem = kDebugMode,
}) => [
  ...items,
  if (includeDebugItem && debugItem != null) debugItem,
];
