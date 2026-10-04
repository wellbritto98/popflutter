import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import '../notifications/notification_service.dart';
import 'auto_login_messages.dart';

/// A single tray slot for the latest background login result.
const kAutoLoginNotificationId = 2;

/// Publishes terminal Auto Login feedback when the app is not visible.
/// Foreground progress remains in the shell snackbar. Notification failures
/// must not interrupt the login controller or subsequent status events.
Future<void> notifyAutoLoginResult({
  required AutoLoginStatus status,
  required AppLifecycleState lifecycle,
  NotificationService? notificationService,
}) async {
  if (notificationService == null || lifecycle == AppLifecycleState.resumed) {
    return;
  }
  if (status.phase != AutoLoginPhase.done &&
      status.phase != AutoLoginPhase.failed) {
    return;
  }
  final message = autoLoginStatusMessage(status);
  if (message == null) return;
  try {
    await notificationService.showNotification(
      id: kAutoLoginNotificationId,
      title: 'autologin.title'.tr(),
      body: message,
    );
  } catch (_) {
    debugPrint('[AutoLogin] Could not show the background login result.');
  }
}
