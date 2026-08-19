import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// Fixed notification id. Reused on every `show()` call so a repeat tap of
/// the debug button replaces the prior notification instead of stacking one
/// (NOTIF-07).
const kTestNotificationId = 1;

const kTestNotificationChannelId = 'popflutter_debug_channel';
const kTestNotificationChannelName = 'Debug';
const kTestNotificationChannelDescription =
    'Manual test notifications triggered from the debug panel.';

const kTestNotificationTitle = 'Popflutter debug';
const kTestNotificationBody = 'This is a test notification.';

/// Real [NotificationService] backed by `flutter_local_notifications`. The
/// only class in the app that imports the plugin.
class LocalNotificationsService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    // AD-008 scopes this app to Android/iOS; other platforms are N/A.
    return true;
  }

  @override
  Future<void> showTestNotification() async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      kTestNotificationChannelId,
      kTestNotificationChannelName,
      channelDescription: kTestNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    // SPEC_DEVIATION: design.md's Components section shows show() called
    // positionally, matching Context7's cached doc snippet. The installed
    // flutter_local_notifications 22.3.0 requires named parameters instead.
    // Reason: version drift between the doc snippet and the resolved
    // package version; behavior (fixed id/title/body/details) is unchanged.
    await _plugin.show(
      id: kTestNotificationId,
      title: kTestNotificationTitle,
      body: kTestNotificationBody,
      notificationDetails: details,
    );
  }
}
