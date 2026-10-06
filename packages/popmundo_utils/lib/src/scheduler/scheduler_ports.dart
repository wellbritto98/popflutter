import 'scheduler_models.dart';
import '../game_actions/game_action_contracts.dart';

/// The runtime engine is the only snapshot writer. Implementations must perform
/// fresh reads and throw when persistence cannot be confirmed.
abstract interface class SchedulerStore {
  Future<String?> read();
  Future<void> write(String snapshot);
}

/// Registered by action type. Completion means platform submission accepted,
/// never proof that the user saw a notification. Errors must be non-secret codes.
abstract interface class ScheduledActionExecutor {
  Future<void> execute({
    required LocalNotificationAction action,
    required int notificationId,
  });
}

/// Serial service admission rechecks current slot before notice/credentials/IO.
abstract interface class ScheduledGameActionExecutor {
  Future<GameActionOutcome> execute(
    GameScheduledAction action, {
    bool Function()? isEligible,
    Future<void> Function()? beforeHttp,
  });
  void cancel();
  Future<void> dispose();
}

/// Native strict submission with the rule's stable negative card ID.
abstract interface class ScheduledGameNotifications {
  Future<void> showStart({
    required GameScheduledAction action,
    required int notificationId,
  });
  Future<void> showResult({
    required GameScheduledAction action,
    required int notificationId,
    required GameActionOutcome outcome,
  });
}
