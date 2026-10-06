import 'package:popmundo_utils/popmundo_utils.dart';

import 'game_notification_messages.dart';

class NativeScheduledGameNotifications implements ScheduledGameNotifications {
  NativeScheduledGameNotifications({
    required this.loadMessages,
    required this.show,
  });
  final Future<GameNotificationMessages> Function() loadMessages;
  final Future<void> Function({
    required int id,
    required String title,
    required String body,
  })
  show;
  Future<void> _publish(int id, GameNotificationText text) =>
      show(id: id, title: text.title, body: text.body);
  @override
  Future<void> showStart({
    required GameScheduledAction action,
    required int notificationId,
  }) async => _publish(notificationId, (await loadMessages()).start(action));
  @override
  Future<void> showResult({
    required GameScheduledAction action,
    required int notificationId,
    required GameActionOutcome outcome,
  }) async =>
      _publish(notificationId, (await loadMessages()).result(action, outcome));
}
