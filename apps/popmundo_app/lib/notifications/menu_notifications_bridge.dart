import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';

import 'notification_service.dart';

/// Deterministic, non-negative `int` id for a menu notification's `uid`
/// (a GUID string), to satisfy `flutter_local_notifications`' plugin-level
/// `int id` requirement — the plugin has no notion of string ids.
///
/// Actual dedup already happened upstream, in [MenuNotificationsWatcher] via
/// its persisted `notifiedUids` string set; this hash only needs to produce
/// a valid Android 32-bit signed notification id, not to be collision-free.
/// A theoretical collision between two different UIDs would only mean two
/// different game notifications share one tray slot — an accepted
/// low-probability edge case (see design.md), not a dedup-correctness bug.
int menuNotificationIdFor(String uid) => uid.hashCode & 0x7fffffff;

/// Bridges [MenuNotificationsWatcher.newNotifications] into
/// [NotificationService.showNotification] calls, resolving the character
/// name once per batch (not once per item — it's the same character every
/// time) via [Utils.getMyName].
///
/// Self-managed-subscription lifecycle, matching
/// `AutoLoginController`/`MenuNotificationsWatcher`'s own shape: owns its
/// [StreamSubscription], started explicitly with [start] and torn down with
/// [dispose].
class MenuNotificationsBridge {
  MenuNotificationsBridge({
    required this.watcher,
    required this.utils,
    required this.notificationService,
  });

  final MenuNotificationsWatcher watcher;
  final Utils utils;
  final NotificationService notificationService;

  StreamSubscription<List<MenuNotification>>? _sub;

  void start() {
    if (_sub != null) return;
    _sub = watcher.newNotifications.listen(_onBatch);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onBatch(List<MenuNotification> notifications) async {
    if (notifications.isEmpty) return;
    final charName = await utils.getMyName();
    for (final n in notifications) {
      await notificationService.showNotification(
        id: menuNotificationIdFor(n.uid),
        title: n.text,
        body: '${n.dateCreated} ${n.timeCreated} - $charName',
        // Retained for a future tap-to-navigate feature; not acted on here
        // (deferred by explicit user decision, see spec.md Out of Scope).
        payload: n.url,
      );
    }
  }
}
