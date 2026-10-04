import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../background/flutter_foreground_task_platform.dart';
import '../notifications/local_notifications_service.dart';
import 'device_zone.dart';
import 'scheduler_runner.dart';
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

/// Composition for the secondary engine; no page, auth or game dependencies.
Future<SchedulerRunner> createSchedulerRunner() async {
  tz.initializeTimeZones();
  final zone = DeviceZone();
  final service = LocalNotificationsService();
  final prefs = await SharedPreferences.getInstance();
  return SchedulerRunner(
    coordinator: SchedulerCoordinator(
      store: PreferencesSchedulerStore(prefs),
      executors: {'localNotification': ScheduledNotificationExecutor(service)},
      now: DateTime.now,
      zoneId: () => zone.identifier,
    ),
    refreshZone: zone.refresh,
    configureBoot: FlutterForegroundTaskPlatform.configureSchedulerBoot,
    notificationGranted: service.isScheduledNotificationGranted,
    send: FlutterForegroundTask.sendDataToMain,
  );
}
