import 'dart:async';
import 'dart:convert';

import '../core/events.dart';
import '../core/popmundo_runtime.dart';
import 'menu_notification.dart';
import 'menu_notification_state_store.dart';
import 'menu_notifications_service.dart';

/// Reacts to the game's own `GetMenuNotificationCount` polling — observed
/// passively via [PopmundoRuntime.events]'s network stream, this watcher
/// never calls the count endpoint itself (MENUNOTIF-01) — and turns a
/// changed count into a batch of newly-observed [MenuNotification]s.
class MenuNotificationsWatcher {
  MenuNotificationsWatcher({
    required this.runtime,
    required this.service,
    required this.stateStore,
  });

  /// Suffix match, not exact equality: there is no `WS_ROOT_URL` constant in
  /// this codebase, the host varies via `HostTracker`'s sticky host.
  static const _countPathSuffix =
      '/WebServices/A/Open.asmx/GetMenuNotificationCount';

  final PopmundoRuntime runtime;
  final MenuNotificationsService service;
  final MenuNotificationStateStore stateStore;

  final _newNotifications =
      StreamController<List<MenuNotification>>.broadcast();
  StreamSubscription<NetworkEvent>? _sub;

  /// Reentrancy guard: a second trigger arriving mid-fetch is dropped, not
  /// queued — the game keeps re-polling the count endpoint, so a genuinely
  /// different state is re-observed and retried on the next poll.
  var _checking = false;

  /// One emission per successful fetch-with-new-items pass.
  Stream<List<MenuNotification>> get newNotifications =>
      _newNotifications.stream;

  void start() {
    if (_sub != null) return;
    _sub = runtime.events.network.listen(_onNetwork);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _newNotifications.close();
  }

  Future<void> _onNetwork(NetworkEvent event) async {
    if (event.method.toUpperCase() != 'POST') return;
    if (!event.url.contains(_countPathSuffix)) return;

    final count = _parseCount(event.body);
    if (count == null) return; // Unparsable body: ignore silently, no state
    // read/write at all (MENUNOTIF-02).

    final state = await stateStore.load();
    if (count == state.lastCount) return; // MENUNOTIF-03.

    if (_checking) return; // Overlapping trigger — dropped, not queued.
    _checking = true;
    try {
      final notifications = await service.fetch();
      final currentUids = notifications.map((n) => n.uid).toSet();
      final newOnes = notifications
          .where((n) => !state.notifiedUids.contains(n.uid))
          .toList();
      if (newOnes.isNotEmpty && !_newNotifications.isClosed) {
        _newNotifications.add(newOnes);
      }
      // Only reached on fetch success — persisted lastCount is left
      // untouched on failure so the next differing count retries
      // (MENUNOTIF-08). notifiedUids is replaced wholesale with the
      // current response's UIDs, dropping ones no longer outstanding
      // (MENUNOTIF-09).
      await stateStore.save(
        MenuNotificationState(lastCount: count, notifiedUids: currentUids),
      );
    } catch (_) {
      // service.fetch() (or a downstream step) failed — swallow it here so
      // it doesn't surface as an unhandled async error from this listener;
      // the persisted state above is simply never reached.
    } finally {
      _checking = false;
    }
  }

  static int? _parseCount(String? body) {
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return int.tryParse('${decoded['d']}');
    } catch (_) {
      return null;
    }
  }
}
