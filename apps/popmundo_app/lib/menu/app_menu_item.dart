import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Immutable value object describing a single entry in the app's sidebar menu.
///
/// No field may carry a [BuildContext] or mutable state — the sidebar closes
/// itself before [onTap] fires, so the context would already be on its way
/// to being unmounted.
@immutable
class AppMenuItem {
  const AppMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}
