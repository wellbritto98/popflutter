import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../background/flutter_foreground_task_platform.dart';
import '../notifications/local_notifications_service.dart';
import 'device_zone.dart';
import 'scheduler_runner.dart';
import 'game_actions_api.dart';
import 'game_credentials.dart';
import 'game_notification_messages.dart';
import 'scheduled_game_notifications.dart';
import '../autologin/secure_secret_store.dart';
import 'scheduler_store.dart';

class ScheduledNotificationExecutor implements ScheduledActionExecutor {
  ScheduledNotificationExecutor(this.service);
  final LocalNotificationsService service;
  @override
  Future<void> execute({
    required LocalNotificationAction action,
    required int notificationId,
  }) => service.showScheduledNotification(
    id: notificationId,
    title: action.title,
    body: action.body,
  );
}

/// Composition for the secondary engine; private HTTP only, no page dependencies.
Future<SchedulerRunner> createSchedulerRunner({
  GameHttpTransport Function()? createGameTransport,
}) async {
  tz.initializeTimeZones();
  final zone = DeviceZone();
  final service = LocalNotificationsService();
  final prefs = await SharedPreferences.getInstance();
  final secrets = FlutterSecureSecretStore();
  final game = GameActionsService(
    readCredentials: () => readSavedGameCredentials(prefs, secrets),
    createTransport: createGameTransport,
  );
  final notices = NativeScheduledGameNotifications(
    loadMessages: () => GameNotificationMessages.load(prefs),
    show: service.showScheduledNotification,
  );
  return SchedulerRunner(
    gameActions: NativeGameActionsApi(game),
    coordinator: SchedulerCoordinator(
      store: PreferencesSchedulerStore(prefs),
      executors: {'localNotification': ScheduledNotificationExecutor(service)},
      gameExecutor: game,
      gameNotifications: notices,
      now: DateTime.now,
      zoneId: () => zone.identifier,
    ),
    refreshZone: zone.refresh,
    configureBoot: FlutterForegroundTaskPlatform.configureSchedulerBoot,
    notificationGranted: service.isScheduledNotificationGranted,
    send: FlutterForegroundTask.sendDataToMain,
  );
}
