import 'package:flutter/widgets.dart';

/// Sidebar entry registered dynamically by `GM.registerMenuCommand`.
@immutable
class GmMenuCommandItem {
  const GmMenuCommandItem({
    required this.scriptId,
    required this.commandId,
    required this.caption,
  });

  final String scriptId;
  final String commandId;
  final String caption;
}
