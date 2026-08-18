import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'background_platform.dart';
import 'keepalive_task_handler.dart';

/// Real [BackgroundPlatform] backed by `flutter_foreground_task`.
class FlutterForegroundTaskPlatform implements BackgroundPlatform {
  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  Future<bool> isNotificationGranted() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    return status == NotificationPermission.granted;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final status =
        await FlutterForegroundTask.requestNotificationPermission();
    return status == NotificationPermission.granted;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isAndroid) return true;
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  @override
  Future<void> requestIgnoreBatteryOptimization() async {
    if (!isAndroid) return;
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  @override
  Future<bool> isRunningService() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'popmundo_keepalive',
        channelName: 'Session keepalive',
        channelDescription:
            'Shown while Popmundo keeps the session alive in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  @override
  Future<void> startService() async {
    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Popmundo is running',
      notificationText: 'Keeping your session alive in the background.',
      callback: keepaliveStartCallback,
    );
    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  }

  @override
  void addTaskDataCallback(void Function(Object data) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  @override
  void removeTaskDataCallback(void Function(Object data) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}
