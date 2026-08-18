import 'package:flutter/widgets.dart';

/// Snapshot of background keepalive state for the debug panel.
class BackgroundStatus {
  const BackgroundStatus({
    this.notificationGranted,
    this.batteryUnrestricted,
    required this.serviceRunning,
    required this.lifecycle,
    this.lastHeartbeat,
  });

  /// `null` means unknown / not yet queried.
  final bool? notificationGranted;

  /// `null` means not applicable (e.g. iOS) → display `n/a`.
  final bool? batteryUnrestricted;

  final bool serviceRunning;
  final AppLifecycleState lifecycle;
  final DateTime? lastHeartbeat;

  String get bgLabel => serviceRunning ? 'running' : 'stopped';

  String get notifLabel {
    if (notificationGranted == null) return 'unknown';
    return notificationGranted! ? 'granted' : 'denied';
  }

  String get batteryLabel {
    if (batteryUnrestricted == null) return 'n/a';
    return batteryUnrestricted! ? 'unrestricted' : 'optimized';
  }

  String get lifecycleLabel => lifecycle.name;

  /// Relative heartbeat for debug: `never`, `just now`, or `Ns ago`.
  String heartbeatLabel([DateTime? now]) {
    final tick = lastHeartbeat;
    if (tick == null) return 'never';
    final n = now ?? DateTime.now();
    final seconds = n.difference(tick).inSeconds;
    if (seconds <= 0) return 'just now';
    return '${seconds}s ago';
  }

  BackgroundStatus copyWith({
    bool? notificationGranted,
    bool? batteryUnrestricted,
    bool? serviceRunning,
    AppLifecycleState? lifecycle,
    DateTime? lastHeartbeat,
    bool clearHeartbeat = false,
  }) {
    return BackgroundStatus(
      notificationGranted: notificationGranted ?? this.notificationGranted,
      batteryUnrestricted: batteryUnrestricted ?? this.batteryUnrestricted,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      lifecycle: lifecycle ?? this.lifecycle,
      lastHeartbeat: clearHeartbeat
          ? null
          : (lastHeartbeat ?? this.lastHeartbeat),
    );
  }
}
