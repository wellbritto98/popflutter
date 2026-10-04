import 'scheduler_models.dart';

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
