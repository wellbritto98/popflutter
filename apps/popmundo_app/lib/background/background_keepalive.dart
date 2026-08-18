import 'package:flutter/widgets.dart';

import 'background_platform.dart';
import 'background_status.dart';

/// Orchestrates permission bootstrap, FGS start, lifecycle, and heartbeat.
class BackgroundKeepalive {
  BackgroundKeepalive({
    required BackgroundPlatform platform,
    AppLifecycleState initialLifecycle = AppLifecycleState.resumed,
  }) : _platform = platform,
       status = ValueNotifier(
         BackgroundStatus(
           serviceRunning: false,
           lifecycle: initialLifecycle,
           batteryUnrestricted: platform.isIOS ? null : false,
         ),
       );

  final BackgroundPlatform _platform;

  final ValueNotifier<BackgroundStatus> status;

  bool _bootstrapped = false;
  void Function(Object)? _heartbeatListener;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    _heartbeatListener = _onTaskData;
    _platform.addTaskDataCallback(_heartbeatListener!);

    var notifGranted = false;
    try {
      notifGranted = await _platform.isNotificationGranted();
      if (!notifGranted) {
        notifGranted = await _platform.requestNotificationPermission();
      }
    } catch (_) {
      notifGranted = false;
    }
    _patch(notificationGranted: notifGranted);

    bool? batteryUnrestricted;
    if (_platform.isAndroid) {
      try {
        var unrestricted = await _platform.isIgnoringBatteryOptimizations();
        if (!unrestricted) {
          await _platform.requestIgnoreBatteryOptimization();
          unrestricted = await _platform.isIgnoringBatteryOptimizations();
        }
        batteryUnrestricted = unrestricted;
      } catch (_) {
        batteryUnrestricted = false;
      }
      _patch(batteryUnrestricted: batteryUnrestricted);
    } else {
      _patch(batteryUnrestricted: null);
    }

    try {
      await _platform.initService();
    } catch (_) {
      // Init failure leaves service stopped; status already reflects that.
    }

    var running = false;
    try {
      running = await _platform.isRunningService();
      if (!running) {
        await _platform.startService();
        running = await _platform.isRunningService();
      }
    } catch (_) {
      running = false;
    }
    _patch(serviceRunning: running);
  }

  void onLifecycle(AppLifecycleState state) {
    _patch(lifecycle: state);
  }

  void dispose() {
    if (_heartbeatListener != null) {
      _platform.removeTaskDataCallback(_heartbeatListener!);
      _heartbeatListener = null;
    }
    status.dispose();
  }

  void _onTaskData(Object data) {
    DateTime? tick;
    if (data is Map) {
      final raw = data['heartbeat'];
      if (raw is String) {
        tick = DateTime.tryParse(raw);
      }
    } else if (data is String) {
      tick = DateTime.tryParse(data);
    }
    if (tick != null) {
      _patch(lastHeartbeat: tick);
    }
  }

  void _patch({
    bool? notificationGranted,
    Object? batteryUnrestricted = _unset,
    bool? serviceRunning,
    AppLifecycleState? lifecycle,
    DateTime? lastHeartbeat,
  }) {
    final current = status.value;
    status.value = BackgroundStatus(
      notificationGranted: notificationGranted ?? current.notificationGranted,
      batteryUnrestricted: identical(batteryUnrestricted, _unset)
          ? current.batteryUnrestricted
          : batteryUnrestricted as bool?,
      serviceRunning: serviceRunning ?? current.serviceRunning,
      lifecycle: lifecycle ?? current.lifecycle,
      lastHeartbeat: lastHeartbeat ?? current.lastHeartbeat,
    );
  }
}

const Object _unset = Object();

