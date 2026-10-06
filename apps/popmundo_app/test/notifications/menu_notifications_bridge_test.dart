import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/notifications/fake_notification_service.dart';
import 'package:popmundo_app/notifications/menu_notifications_bridge.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_popmundo_runtime.dart';

const _countUrl =
    'https://www.popmundo.com/WebServices/A/Open.asmx/GetMenuNotificationCount';

NetworkEvent _countEvent(int count) => NetworkEvent(
  method: 'POST',
  url: _countUrl,
  body: jsonEncode({'d': '$count'}),
);

String _notificationsResponse(List<Map<String, Object?>> items) =>
    jsonEncode({'d': jsonEncode(items)});

/// `Utils.getMyName()` reads the character page over [TimedFetch] and parses
/// the HTML (it no longer calls `evaluate`), so the fake has to serve that
/// page too. Same selectors as `packages/popmundo_utils/test/utils_test.dart`.
String _characterHtml(String name) =>
    '''
<html><body>
<div class="idHolder">42</div>
<div id="ppm-content">
  <div class="box ofauto charPresBox"><h2>$name</h2></div>
</div>
</body></html>
''';

/// One fetch handler serving both endpoints the bridge exercises: the
/// character page (for `getMyName()`) and `GetMenuNotifications`.
InPageFetchResult Function(String, Map<String, dynamic>?) _serve(
  String notificationsBody, {
  String characterName = 'Ada',
}) =>
    (url, options) => InPageFetchResult(
      ok: true,
      status: 200,
      text: url.contains(Utils.characterPath)
          ? _characterHtml(characterName)
          : notificationsBody,
    );

Map<String, Object?> _item(
  String uid, {
  String text = 'Item offer',
  String dateCreated = '2026-08-19',
  String timeCreated = '10:00',
  String url = '/World/Popmundo.aspx/Item/1',
}) => {
  'UID': uid,
  'Text': text,
  'DateCreated': dateCreated,
  'TimeCreated': timeCreated,
  'Url': url,
};

/// `TimedFetch` caches `METHOD:URL`, so the character page is fetched at most
/// once no matter how often `getMyName()` is called — counting fetches would
/// pass even for a once-per-item implementation. Count the calls themselves.
class _CountingUtils extends Utils {
  _CountingUtils(super.runtime, super.timedFetch);

  int getMyNameCalls = 0;

  @override
  Future<String> getMyName() {
    getMyNameCalls++;
    return super.getMyName();
  }
}

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

/// Wires a real [MenuNotificationsWatcher] (network-event-driven, exactly as
/// used in `_PopmundoHomeState`) to a [MenuNotificationsBridge], so the test
/// exercises the real integration end to end rather than a hand-rolled
/// stand-in stream.
///
/// [TimedFetch] gets a virtual clock (matching
/// `menu_notifications_watcher_test.dart`'s harness) so its real 750ms
/// throttle never makes a test involving two fetches actually wait.
class _Harness {
  _Harness()
    : runtime = FakePopmundoRuntime(),
      store = MemoryKeyValueStore(),
      notificationService = FakeNotificationService() {
    final clock = _Clock();
    timedFetch = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    service = MenuNotificationsService(
      runtime,
      timedFetch,
      now: () => clock.now,
    );
    stateStore = MenuNotificationStateStore(store);
    watcher = MenuNotificationsWatcher(
      runtime: runtime,
      service: service,
      stateStore: stateStore,
    );
    utils = _CountingUtils(runtime, timedFetch);
    bridge = MenuNotificationsBridge(
      watcher: watcher,
      utils: utils,
      notificationService: notificationService,
    );
  }

  final FakePopmundoRuntime runtime;
  final MemoryKeyValueStore store;
  final FakeNotificationService notificationService;
  late final TimedFetch timedFetch;
  late final MenuNotificationsService service;
  late final MenuNotificationStateStore stateStore;
  late final MenuNotificationsWatcher watcher;
  late final _CountingUtils utils;
  late final MenuNotificationsBridge bridge;

  int get getMyNameCalls => utils.getMyNameCalls;
}

void main() {
  test('shows one notification per new item, with title/body/id/payload shape '
      '(MENUNOTIF-06)', () async {
    final h = _Harness();
    h.runtime.fetchHandler = _serve(
      _notificationsResponse([
        _item(
          'u1',
          text: 'Item offer',
          dateCreated: '2026-08-19',
          timeCreated: '10:00',
          url: '/World/Popmundo.aspx/Item/1',
        ),
      ]),
    );
    h.watcher.start();
    h.bridge.start();

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);

    expect(h.notificationService.shownNotifications, hasLength(1));
    final shown = h.notificationService.shownNotifications.single;
    expect(shown.id, menuNotificationIdFor('u1'));
    expect(shown.title, 'Item offer');
    expect(shown.body, '2026-08-19 10:00 - Ada');
    expect(shown.payload, '/World/Popmundo.aspx/Item/1');
  });

  test('getMyName() is resolved once per batch, not once per item', () async {
    final h = _Harness();
    h.runtime.fetchHandler = _serve(
      _notificationsResponse([_item('u1'), _item('u2'), _item('u3')]),
    );
    h.watcher.start();
    h.bridge.start();

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);

    expect(h.notificationService.shownNotifications, hasLength(3));
    expect(h.getMyNameCalls, 1);
  });

  test(
    'already-notified items do not produce a second call on a repeat batch',
    () async {
      final h = _Harness();
      h.runtime.fetchHandler = _serve(_notificationsResponse([_item('u1')]));
      h.watcher.start();
      h.bridge.start();

      h.runtime.events.emitNetwork(_countEvent(1));
      await Future<void>.delayed(Duration.zero);
      expect(h.notificationService.shownNotifications, hasLength(1));

      // Count changes again, but the same item ('u1') is still the only one
      // outstanding — already in notifiedUids, so it must not be re-shown.
      h.runtime.fetchHandler = _serve(
        _notificationsResponse([_item('u1'), _item('u2')]),
      );
      h.runtime.events.emitNetwork(_countEvent(2));
      await Future<void>.delayed(Duration.zero);

      expect(h.notificationService.shownNotifications, hasLength(2));
      expect(
        h.notificationService.shownNotifications.map((s) => s.id),
        containsAll([menuNotificationIdFor('u1'), menuNotificationIdFor('u2')]),
      );
      // u1 shown exactly once across both batches.
      expect(
        h.notificationService.shownNotifications.where(
          (s) => s.id == menuNotificationIdFor('u1'),
        ),
        hasLength(1),
      );
    },
  );

  test('dispose() stops delivering further batches', () async {
    final h = _Harness();
    h.runtime.fetchHandler = _serve(_notificationsResponse([_item('u1')]));
    h.watcher.start();
    h.bridge.start();

    await h.bridge.dispose();

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);

    expect(h.notificationService.shownNotifications, isEmpty);
  });
}
