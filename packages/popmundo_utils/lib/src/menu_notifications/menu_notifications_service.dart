import 'dart:convert';

import '../popmundo_runtime.dart';
import '../timed_fetch.dart';
import 'menu_notification.dart';

/// Fetches and parses the game's own `GetMenuNotifications` webservice.
///
/// Mirrors `Notifications.getPageNotifications`/`parsePageNotifications`
/// exactly: same double-encoded `{"d": "<json-array-string>"}` envelope, same
/// `TimedFetch` POST shape. `useCache: false` is mandatory here — `ts`
/// changes on every call, but `TimedFetch`'s cache key is `METHOD:URL` only,
/// so a cached entry would come back stale for a changed count.
class MenuNotificationsService {
  MenuNotificationsService(this.runtime, this.timedFetch, {ClockNow? now})
      : _now = now ?? DateTime.now;

  static const path = '/WebServices/A/Open.asmx/GetMenuNotifications';

  final PopmundoRuntime runtime;
  final TimedFetch timedFetch;
  final ClockNow _now;

  Future<List<MenuNotification>> fetch() async {
    final ts = _now().millisecondsSinceEpoch;
    final text = await timedFetch.fetch(
      path,
      options: {
        'method': 'POST',
        'headers': {'Content-Type': 'application/json; charset=utf-8'},
        'body': jsonEncode({'ts': '$ts'}),
      },
      useCache: false,
    );
    return parseMenuNotifications(text);
  }

  /// Unwraps `{"d": "<json-array-string>"}` (or a bare array/string) and maps
  /// each entry through [MenuNotification.fromJson], dropping malformed ones.
  static List<MenuNotification> parseMenuNotifications(String responseText) {
    final wrapper = jsonDecode(responseText);
    dynamic raw = wrapper is Map ? wrapper['d'] ?? wrapper : wrapper;
    if (raw is String) raw = jsonDecode(raw);
    if (raw is! List) return const [];
    return raw
        .map(MenuNotification.fromJson)
        .whereType<MenuNotification>()
        .toList();
  }
}
