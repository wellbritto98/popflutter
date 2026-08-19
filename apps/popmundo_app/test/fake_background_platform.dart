import 'package:popmundo_app/background/background_platform.dart';

/// In-memory [BackgroundPlatform] for unit tests — never opens OS dialogs.
class FakeBackgroundPlatform implements BackgroundPlatform {
  FakeBackgroundPlatform({
    this.isAndroid = true,
    this.isIOS = false,
    this.notificationGranted = false,
    this.grantNotificationOnRequest = true,
    this.ignoringBattery = false,
    this.grantBatteryOnRequest = true,
    this.runningService = false,
    this.becomeRunningAfterStart = true,
    this.throwOnNotificationRequest = false,
    this.throwOnBatteryRequest = false,
    this.throwOnStart = false,
  });

  @override
  bool isAndroid;

  @override
  bool isIOS;

  bool notificationGranted;
  bool grantNotificationOnRequest;
  bool ignoringBattery;
  bool grantBatteryOnRequest;
  bool runningService;
  bool becomeRunningAfterStart;
  bool throwOnNotificationRequest;
  bool throwOnBatteryRequest;
  bool throwOnStart;

  int notificationRequestCount = 0;
  int batteryRequestCount = 0;
  int initCount = 0;
  int startCount = 0;
  String? lastNotificationTitle;
  String? lastNotificationText;

  final listeners = <void Function(Object)>[];

  void emitHeartbeat(DateTime tick) {
    final payload = {'heartbeat': tick.toIso8601String()};
    for (final cb in List.of(listeners)) {
      cb(payload);
    }
  }

  @override
  Future<bool> isNotificationGranted() async => notificationGranted;

  @override
  Future<bool> requestNotificationPermission() async {
    notificationRequestCount++;
    if (throwOnNotificationRequest) {
      throw StateError('notification request failed');
    }
    notificationGranted = grantNotificationOnRequest;
    return notificationGranted;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBattery;

  @override
  Future<void> requestIgnoreBatteryOptimization() async {
    batteryRequestCount++;
    if (throwOnBatteryRequest) {
      throw StateError('battery request failed');
    }
    if (grantBatteryOnRequest) {
      ignoringBattery = true;
    }
  }

  @override
  Future<bool> isRunningService() async => runningService;

  @override
  Future<void> initService() async {
    initCount++;
  }

  @override
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    startCount++;
    lastNotificationTitle = notificationTitle;
    lastNotificationText = notificationText;
    if (throwOnStart) {
      throw StateError('start failed');
    }
    if (becomeRunningAfterStart) {
      runningService = true;
    }
  }

  @override
  void addTaskDataCallback(void Function(Object data) callback) {
    listeners.add(callback);
  }

  @override
  void removeTaskDataCallback(void Function(Object data) callback) {
    listeners.remove(callback);
  }
}
