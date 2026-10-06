import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';

/// A single timer and coalesced ticks share the command queue.
class SchedulerRunner {
  SchedulerRunner({
    required this.coordinator,
    required this.refreshZone,
    required this.configureBoot,
    required this.notificationGranted,
    required this.send,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final SchedulerCoordinator coordinator;
  final Future<void> Function() refreshZone;
  final Future<void> Function(bool enabled) configureBoot;
  final Future<bool> Function() notificationGranted;
  final void Function(Map<String, Object?> data) send;
  final DateTime Function() now;
  Future<void> _tail = Future.value();
  Future<void>? _tick;
  Future<void>? _startup;
  Timer? _timer;
  bool _disposed = false;
  String? errorCode;

  Future<T> _queue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<void> start() => _startup ??= _queue(() async {
    await refreshZone();
    final snapshot = await coordinator.load();
    await _boot(snapshot);
    _arm(snapshot);
  });
  Future<void> _boot(SchedulerSnapshot snapshot) async {
    try {
      await configureBoot(snapshot.rules.any((rule) => rule.enabled));
    } catch (_) {
      throw const SchedulerException('bootConfigurationFailed');
    }
  }

  Future<void> reconcile() {
    if (_disposed) return Future.value();
    return _tick ??= _queue(() async {
      try {
        await refreshZone();
        final snapshot = await coordinator.reconcile();
        await _boot(snapshot);
        errorCode = null;
        _arm(snapshot);
      } catch (error) {
        errorCode = _code(error);
        _timer?.cancel();
      }
    }).whenComplete(() => _tick = null);
  }

  Future<void> receive(Object data) async {
    if (data is! Map || data['type'] != 'scheduler.request') return;
    final requestId = data['requestId'];
    if (requestId is! String) return;
    await _queue(() async {
      try {
        await refreshZone();
        final command = data['command'];
        final draft = data['draft'] is Map
            ? _draft(data['draft'] as Map)
            : null;
        if (((command == 'create' || command == 'update') &&
                draft != null &&
                draft.enabled) ||
            (command == 'toggle' && data['enabled'] == true)) {
          if (!await notificationGranted()) {
            throw const SchedulerException('permissionDenied');
          }
        }
        final snapshot = switch (command) {
          'list' => await coordinator.list(),
          'create' when draft != null => await coordinator.create(
            draft,
            id: data['id'] as String,
          ),
          'update' when draft != null => await coordinator.update(
            data['id'] as String,
            draft,
            expectedRevision: data['revision'] as int,
          ),
          'toggle' => await coordinator.toggle(
            data['id'] as String,
            expectedRevision: data['revision'] as int,
            enabled: data['enabled'] as bool,
          ),
          'delete' => await coordinator.delete(
            data['id'] as String,
            expectedRevision: data['revision'] as int,
          ),
          _ => throw const SchedulerException('invalidCommand'),
        };
        await _boot(snapshot);
        _arm(snapshot);
        errorCode = null;
        send({
          'type': 'scheduler.response',
          'requestId': requestId,
          'snapshot': snapshot.toJson(),
        });
      } catch (error) {
        errorCode = _code(error);
        send({
          'type': 'scheduler.response',
          'requestId': requestId,
          'error': errorCode,
        });
      }
    });
  }

  ScheduleDraft _draft(Map data) => ScheduleDraft(
    name: data['name'] as String,
    enabled: data['enabled'] as bool,
    recurrence: ScheduleRecurrence.fromJson(
      Map<String, dynamic>.from(data['recurrence'] as Map),
    ),
    action: ScheduledAction.fromJson(
      Map<String, dynamic>.from(data['action'] as Map),
    ),
  );
  void _arm(SchedulerSnapshot snapshot) {
    _timer?.cancel();
    if (_disposed) return;
    final due =
        snapshot.rules
            .where((r) => r.enabled && r.nextDueUtc != null)
            .map((r) => r.nextDueUtc!)
            .toList()
          ..sort();
    if (due.isEmpty) return;
    final delay = due.first.difference(now().toUtc());
    _timer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(reconcile()),
    );
  }

  String _code(Object error) =>
      error is SchedulerException ? error.code : 'runtimeUnavailable';
  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
