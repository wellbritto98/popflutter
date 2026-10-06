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
  KeepaliveTaskHandler({
    Future<SchedulerRunner> Function()? createRunner,
    void Function(Map<String, Object?>)? send,
    bool? isAndroid,
  }) : _createRunner = createRunner ?? createSchedulerRunner,
       _send = send ?? FlutterForegroundTask.sendDataToMain,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final Future<SchedulerRunner> Function() _createRunner;
  final void Function(Map<String, Object?>) _send;
  final bool _isAndroid;
  SchedulerRunner? _runner;
  String? _error;
  Future<void>? _starting;
  Future<void>? _startupWork;
  bool _destroyed = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (!_isAndroid) return;
    debugPrint(
      'scheduler.start utc=${timestamp.toUtc().toIso8601String()} starter=${starter.name}',
    );
    await _beginStart();
  }

  Future<void> _beginStart() {
    if (_destroyed || !_isAndroid || _runner != null) return Future.value();
    // Track the underlying work: a UI deadline must not release ownership.
    if (_startupWork != null) return _starting!;
    final work = _start();
    _startupWork = work;
    unawaited(work.then((_) => _startupWork = null));
    return _starting = work.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _error = 'runtimeUnavailable';
      },
    );
  }

  Future<void> _start() async {
    try {
      final runner = await _createRunner();
      if (_destroyed) {
        runner.dispose();
        return;
      }
      _runner = runner;
      await runner.start();
      _error = null;
    } catch (_) {
      _error = 'runtimeUnavailable';
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _send({'heartbeat': timestamp.toUtc().toIso8601String()});
    final runner = _runner;
    if (_destroyed) return;
    if (runner != null) {
      unawaited(runner.reconcile());
    } else {
      unawaited(_beginStart());
    }
  }

  @override
  void onReceiveData(Object data) {
    unawaited(_receive(data));
  }

  Future<void> _receive(Object data) async {
    if (data is! Map ||
        data['type'] != 'scheduler.request' ||
        data['requestId'] is! String) {
      return;
    }
    if (_runner == null) {
      await _beginStart();
    } else {
      await _starting;
    }
    if (_runner != null && !_destroyed) {
      await _runner!.receive(data);
      return;
    }
    _send({
      'type': 'scheduler.response',
      'requestId': data['requestId'],
      'error': _error ?? 'serviceUnavailable',
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    _runner?.dispose();
  }
}
