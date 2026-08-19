import 'dart:async';

import 'notification_service.dart';

/// Test double for [NotificationService]. Records call counts and lets a
/// test configure denial, init failure, and an in-flight delay — never a
/// real OS notification or permission dialog.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.permissionGranted = true,
    this.initializeError,
    this.showDelay,
  });

  /// What [requestPermission] resolves to.
  bool permissionGranted;

  /// If set, [initialize] throws this instead of succeeding.
  Object? initializeError;

  /// If set, [showTestNotification] waits this long before completing —
  /// lets a test hold the in-flight window open to exercise debouncing.
  Duration? showDelay;

  int initializeCalls = 0;
  int requestPermissionCalls = 0;
  int showCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return permissionGranted;
  }

  @override
  Future<void> showTestNotification() async {
    final delay = showDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    showCalls++;
  }
}
