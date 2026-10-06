import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'background_platform.dart';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../scheduler/scheduler_store.dart';
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
    final status = await FlutterForegroundTask.requestNotificationPermission();
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
  static ForegroundTaskOptions schedulerOptions(bool enabled) =>
      ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: enabled,
        autoRunOnMyPackageReplaced: enabled,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      );

  static bool? _appliedBoot;
  static Future<void> configureSchedulerBoot(bool enabled) async {
    if (_appliedBoot == enabled) return;
    final result = await FlutterForegroundTask.updateService(
      foregroundTaskOptions: schedulerOptions(enabled),
    );
    if (result is ServiceRequestFailure) throw result.error;
    _appliedBoot = enabled;
  }

  @override
  Future<void> initService() async {
    var enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await PreferencesSchedulerStore(prefs).read();
      if (raw != null) {
        enabled = SchedulerSnapshot.decode(raw).rules.any((r) => r.enabled);
      }
    } catch (_) {
      // An unavailable scheduler must not prevent the existing session service.
      // Its corrupt blob is preserved and the runner reports the read error.
    }
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
      foregroundTaskOptions: schedulerOptions(enabled),
    );
  }

  @override
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: notificationTitle,
      notificationText: notificationText,
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
