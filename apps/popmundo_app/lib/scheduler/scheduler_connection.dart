import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';

import '../background/background_keepalive.dart';
import '../background/background_platform.dart';

/// The Android service can be running before its Dart channel is ready.
/// Observe a task heartbeat before sending commands; never retry mutations.
Future<void> waitForSchedulerService(
  BackgroundKeepalive keepalive,
  BackgroundPlatform platform, {
  Duration timeout = const Duration(seconds: 12),
  DateTime Function()? now,
}) async {
  final clock = now ?? DateTime.now;
  final deadline = clock().add(timeout);
  Duration remaining() => deadline.difference(clock());
  try {
    await keepalive.bootstrap().timeout(timeout);
    while (remaining() > Duration.zero) {
      if (await platform.isRunningService().timeout(remaining()) &&
          keepalive.status.value.lastHeartbeat != null) {
        return;
      }
      final budget = remaining();
      if (budget <= Duration.zero) break;
      await Future<void>.delayed(
        budget < const Duration(milliseconds: 100)
            ? budget
            : const Duration(milliseconds: 100),
      );
    }
  } on TimeoutException {
    throw const SchedulerException('serviceUnavailable');
  }
  throw const SchedulerException('serviceUnavailable');
}
