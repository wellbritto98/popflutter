import 'dart:async';
import 'dart:convert';

import 'recurrence_calculator.dart';
import 'scheduler_models.dart';
import 'scheduler_ports.dart';
import '../game_actions/game_action_contracts.dart';

part 'scheduler_commands.dart';
part 'scheduler_game_execution.dart';

/// Single writer and at-most-once attempt coordinator. All commands and ticks
/// share the same queue, including durable claims and bounded action waits.
class SchedulerCoordinator {
  SchedulerCoordinator({
    required this.store,
    required Map<String, ScheduledActionExecutor> executors,
    this.gameExecutor,
    this.gameNotifications,
    required this.now,
    required this.zoneId,
    RecurrenceCalculator? calculator,
  }) : _executors = Map.unmodifiable(executors),
       _calculator = calculator ?? RecurrenceCalculator();
  static const actionTimeout = Duration(seconds: 5);
  final SchedulerStore store;
  final ScheduledGameActionExecutor? gameExecutor;
  final ScheduledGameNotifications? gameNotifications;
  final Map<String, ScheduledActionExecutor> _executors;
  final DateTime Function() now;
  final String Function() zoneId;
  final RecurrenceCalculator _calculator;
  Future<void> _tail = Future.value();
  SchedulerSnapshot? _snapshot;
  bool _disposed = false;

  Future<void> dispose() async {
    _disposed = true;
    gameExecutor?.cancel();
    final shuttingDown = gameExecutor?.dispose() ?? Future<void>.value();
    await Future.wait<void>([_tail, shuttingDown]);
  }

  Future<SchedulerSnapshot> load() => _serialized(_load);
  Future<SchedulerSnapshot> list() => _serialized(_ensureLoaded);

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) {
      if (_disposed) throw const SchedulerException("serviceUnavailable");
      return operation();
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<SchedulerSnapshot> _ensureLoaded() async => _snapshot ?? await _load();

  Future<SchedulerSnapshot> _load() async {
    String? raw;
    try {
      raw = await store.read();
    } catch (_) {
      _snapshot = null;
      throw const SchedulerException('readFailed');
    }
    _snapshot = null;
    if (raw == null) return _snapshot = SchedulerSnapshot();
    final stored = SchedulerSnapshot.decode(raw);
    final now = this.now().toUtc();
    final rules = stored.rules.map((rule) {
      final interrupted =
          rule.lastClaim != null && rule.lastResult.atUtc == null;
      final restored = rule.copyWith(
        clearClaim: interrupted,
        lastAttemptUtc: rule.lastAttemptUtc ?? rule.lastClaim?.plannedUtc,
        lastResult: interrupted
            ? ScheduleResult(
                status: ScheduleResultStatus.skippedInterrupted,
                atUtc: now,
              )
            : null,
      );
      return _arm(restored, now);
    }).toList();
    final restored = SchedulerSnapshot(
      nextSequence: stored.nextSequence,
      rules: rules,
    );
    if (restored.encode() == stored.encode()) return _snapshot = restored;
    return _save(restored);
  }

  ScheduledRule _arm(
    ScheduledRule rule,
    DateTime now, {
    bool resetAnchor = false,
  }) {
    if (!rule.enabled) return rule.copyWith(clearDue: true);
    var recurrence = rule.recurrence;
    if (resetAnchor && recurrence is IntervalRecurrence) {
      recurrence = IntervalRecurrence(
        quantity: recurrence.quantity,
        unit: recurrence.unit,
        anchorUtc: now,
      );
    }
    final zone = zoneId();
    final cutoff =
        rule.lastAttemptUtc != null && rule.lastAttemptUtc!.isAfter(now)
        ? rule.lastAttemptUtc!
        : now;
    try {
      return rule.copyWith(
        recurrence: recurrence,
        zoneId: zone,
        nextDueUtc: _calculator.nextAfter(recurrence, cutoff, zoneId: zone),
      );
    } on SchedulerException catch (error) {
      if (error.code != 'zoneUnavailable') rethrow;
      return rule.copyWith(
        clearDue: true,
        zoneId: zone,
        lastResult: ScheduleResult(
          status: ScheduleResultStatus.failed,
          atUtc: now,
          errorCode: error.code,
        ),
      );
    }
  }

  Future<SchedulerSnapshot> _save(SchedulerSnapshot value) async {
    try {
      await store.write(value.encode());
    } catch (_) {
      // A write can fail after reaching storage. Re-read under startup policy
      // before any further command/tick so uncertain claims cannot be retried.
      _snapshot = null;
      throw const SchedulerException('writeFailed');
    }
    return _snapshot = value;
  }

  Future<SchedulerSnapshot> _replace(ScheduledRule rule) => _save(
    SchedulerSnapshot(
      nextSequence: _snapshot!.nextSequence,
      rules: _snapshot!.rules
          .map((old) => old.id == rule.id ? rule : old)
          .toList(),
    ),
  );

  ScheduledRule _find(String id, {int? expectedRevision}) {
    final candidates = _snapshot!.rules.where((rule) => rule.id == id);
    if (candidates.isEmpty) throw const SchedulerException('ruleNotFound');
    final rule = candidates.single;
    if (expectedRevision != null && rule.revision != expectedRevision) {
      throw const SchedulerException('revisionConflict');
    }
    return rule;
  }

  Future<SchedulerSnapshot> reconcile() => _serialized(() async {
    await _ensureLoaded();
    final ids = _snapshot!.rules.map((rule) => rule.id).toList();
    for (final id in ids) {
      var rule = _find(id);
      if (!rule.enabled) continue;
      final now = this.now().toUtc();
      final zone = zoneId();
      if (rule.nextDueUtc == null ||
          (rule.recurrence is WeeklyRecurrence && rule.zoneId != zone)) {
        rule = _arm(rule, now);
        if (jsonEncode(rule.toJson()) != jsonEncode(_find(id).toJson())) {
          await _replace(rule);
        }
        continue;
      }
      final due = rule.nextDueUtc!;
      if (due.isAfter(now)) continue;
      final localSlot = _calculator.localSlot(
        rule.recurrence,
        due,
        zoneId: zone,
      );
      if (!_calculator.isEligible(rule.recurrence, due, now) ||
          (rule.lastAttemptUtc != null && !due.isAfter(rule.lastAttemptUtc!)) ||
          (localSlot != null && localSlot == rule.lastClaim?.localSlot)) {
        await _replace(_arm(rule, now));
        continue;
      }
      final claim = ScheduleClaim(
        revision: rule.revision,
        plannedUtc: due,
        localSlot: localSlot,
      );
      rule = _arm(rule, now).copyWith(
        lastClaim: claim,
        lastAttemptUtc: due,
        lastResult: ScheduleResult(status: ScheduleResultStatus.neverExecuted),
      );
      await _replace(rule); // No platform action occurs before this succeeds.
      ScheduleResult result;
      GameActionOutcome? gameOutcome;
      if (rule.action is GameScheduledAction) {
        gameOutcome = await _runGame(rule, due, zone);
        result = ScheduleResult(
          status: ScheduleResultStatus.values.byName(gameOutcome.status.name),
          atUtc: this.now(),
          errorCode: gameOutcome.errorCode,
        );
        rule = _arm(rule, this.now().toUtc());
      } else {
        try {
          final executor = _executors['localNotification'];
          if (executor == null) {
            throw const SchedulerException('executorUnavailable');
          }
          await Future<void>.sync(
            () => executor.execute(
              action: rule.action as LocalNotificationAction,
              notificationId: rule.notificationId,
            ),
          ).timeout(actionTimeout);
          result = ScheduleResult(
            status: ScheduleResultStatus.submitted,
            atUtc: this.now(),
          );
        } catch (error) {
          result = ScheduleResult(
            status: ScheduleResultStatus.failed,
            atUtc: this.now(),
            errorCode: error is TimeoutException
                ? 'actionTimeout'
                : error is SchedulerException
                ? error.code
                : 'actionFailed',
          );
        }
      }
      try {
        await _replace(rule.copyWith(lastResult: result));
      } on SchedulerException {
        throw const SchedulerException('resultUncertain');
      }
      if (gameOutcome != null) await _publishGameResult(rule, gameOutcome);
    }
    return _snapshot!;
  });
}
