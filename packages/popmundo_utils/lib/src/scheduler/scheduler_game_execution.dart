part of 'scheduler_coordinator.dart';

extension _GameScheduling on SchedulerCoordinator {
  Future<GameActionOutcome> _runGame(
    ScheduledRule rule,
    DateTime due,
    String zone,
  ) async {
    try {
      final executor = gameExecutor;
      final notices = gameNotifications;
      if (executor == null) {
        throw const SchedulerException("executorUnavailable");
      }
      if (notices == null) {
        throw const SchedulerException("notificationUnavailable");
      }
      final action = rule.action as GameScheduledAction;
      return await executor.execute(
        action,
        isEligible: () =>
            !_disposed &&
            _calculator.isEligible(rule.recurrence, due, now().toUtc()) &&
            (rule.recurrence is! WeeklyRecurrence || zoneId() == zone),
        beforeHttp: () => notices.showStart(
          action: action,
          notificationId: rule.notificationId,
        ),
      );
    } catch (error) {
      return GameActionOutcome(
        status: GameActionStatus.failed,
        errorCode: error is SchedulerException
            ? error.code
            : error is GameActionException
            ? error.code
            : 'actionFailed',
      );
    }
  }

  Future<void> _publishGameResult(
    ScheduledRule rule,
    GameActionOutcome outcome,
  ) async {
    if (_disposed || outcome.errorCode == 'occurrenceExpired') return;
    try {
      await gameNotifications?.showResult(
        action: rule.action as GameScheduledAction,
        notificationId: rule.notificationId,
        outcome: outcome,
      );
    } catch (_) {
      // The durable effect outcome already won; publishing must never retry it.
    }
  }
}
