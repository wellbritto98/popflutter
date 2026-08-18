/// Port over platform APIs used by [BackgroundKeepalive].
///
/// Real impl: flutter_foreground_task. Tests use a fake — never real OS dialogs.
abstract class BackgroundPlatform {
  bool get isAndroid;
  bool get isIOS;

  Future<bool> isNotificationGranted();
  Future<bool> requestNotificationPermission();

  /// Android only; iOS implementations should return `true` (N/A).
  Future<bool> isIgnoringBatteryOptimizations();

  Future<void> requestIgnoreBatteryOptimization();

  Future<bool> isRunningService();
  Future<void> initService();
  Future<void> startService();

  void addTaskDataCallback(void Function(Object data) callback);
  void removeTaskDataCallback(void Function(Object data) callback);
}
