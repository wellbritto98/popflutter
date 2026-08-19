import 'dart:async';

/// Seam between the debug UI and the local-notifications plugin, so the
/// plugin never has to run under `flutter test`.
///
/// Real impl: flutter_local_notifications. Tests use a fake — never a real
/// OS notification or permission dialog.
abstract class NotificationService {
  /// One-time plugin/channel setup. Must swallow its own errors so a failed
  /// init never crashes app startup.
  Future<void> initialize();

  /// Requests (or reads, if already decided) the OS notification permission.
  /// Returns the grant state.
  Future<bool> requestPermission();

  /// Shows the fixed test notification using a fixed channel/notification id.
  Future<void> showTestNotification();
}
