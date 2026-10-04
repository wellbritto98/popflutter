import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../scheduler/scheduler_environment.dart';
import '../scheduler/scheduler_runner.dart';

/// Entrypoint initializes bindings and plugin registration via setTaskHandler.
@pragma('vm:entry-point')
void keepaliveStartCallback() {
  FlutterForegroundTask.setTaskHandler(KeepaliveTaskHandler());
}

/// Existing heartbeat plus the Android local-service scheduler (AD-021).
class KeepaliveTaskHandler extends TaskHandler {
  SchedulerRunner? _runner;
  String? _error;
  Future<void>? _starting;
  bool _destroyed = false;
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (!Platform.isAndroid) return;
    debugPrint(
      'scheduler.start utc=${timestamp.toUtc().toIso8601String()} starter=${starter.name}',
    );
    _starting = _start().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _error = 'runtimeUnavailable';
      },
    );
    await _starting;
  }

  Future<void> _start() async {
    try {
      final runner = await createSchedulerRunner();
      if (_destroyed) {
        runner.dispose();
        return;
      }
      _runner = runner;
      await runner.start();
    } catch (_) {
      _error = 'runtimeUnavailable';
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({
      'heartbeat': timestamp.toUtc().toIso8601String(),
    });
    final runner = _runner;
    if (runner != null) unawaited(runner.reconcile());
  }

  @override
  void onReceiveData(Object data) {
    unawaited(_receive(data));
  }

  Future<void> _receive(Object data) async {
    await _starting;
    if (_runner != null) {
      await _runner!.receive(data);
      return;
    }
    if (data is Map &&
        data['type'] == 'scheduler.request' &&
        data['requestId'] is String) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'scheduler.response',
        'requestId': data['requestId'],
        'error': _error ?? 'serviceUnavailable',
      });
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    _runner?.dispose();
  }
}
