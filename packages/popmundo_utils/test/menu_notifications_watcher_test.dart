import 'dart:async';
import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

const _countUrl =
    'https://www.popmundo.com/WebServices/A/Open.asmx/GetMenuNotificationCount';

NetworkEvent _countEvent(int count) => NetworkEvent(
      method: 'POST',
      url: _countUrl,
      body: jsonEncode({'d': '$count'}),
    );

String _notificationsResponse(List<Map<String, Object?>> items) =>
    jsonEncode({'d': jsonEncode(items)});

Map<String, Object?> _item(String uid, {String text = 't'}) =>
    {'UID': uid, 'Text': text};

class _Harness {
  _Harness()
      : runtime = FakePopmundoRuntime(),
        store = MemoryKeyValueStore() {
    final clock = _Clock();
    timedFetch = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    service = MenuNotificationsService(runtime, timedFetch, now: () => clock.now);
    stateStore = MenuNotificationStateStore(store);
    watcher = MenuNotificationsWatcher(
      runtime: runtime,
      service: service,
      stateStore: stateStore,
    );
  }

  final FakePopmundoRuntime runtime;
  final MemoryKeyValueStore store;
  late final TimedFetch timedFetch;
  late final MenuNotificationsService service;
  late final MenuNotificationStateStore stateStore;
  late final MenuNotificationsWatcher watcher;
}

void main() {
  test('first run: no persisted state, any real count notifies every '
      'outstanding item', () async {
    final h = _Harness();
    h.runtime.fetchHandler = (url, options) => InPageFetchResult(
          ok: true,
          status: 200,
          text: _notificationsResponse([_item('u1'), _item('u2')]),
        );
    final batches = <List<MenuNotification>>[];
    h.watcher.newNotifications.listen(batches.add);
    h.watcher.start();

    h.runtime.events.emitNetwork(_countEvent(2));
    await Future<void>.delayed(Duration.zero);

    expect(h.runtime.fetchCalls, hasLength(1));
    expect(batches, hasLength(1));
    expect(batches.single.map((n) => n.uid).toSet(), {'u1', 'u2'});

    final state = await h.stateStore.load();
    expect(state.lastCount, 2);
    expect(state.notifiedUids, {'u1', 'u2'});
  });

  test('no-op when the new count equals the persisted count (MENUNOTIF-03)',
      () async {
    final h = _Harness();
    await h.stateStore.save(const MenuNotificationState(lastCount: 5));
    h.runtime.fetchHandler = (url, options) =>
        InPageFetchResult(ok: true, status: 200, text: _notificationsResponse([]));
    h.watcher.start();

    h.runtime.events.emitNetwork(_countEvent(5));
    await Future<void>.delayed(Duration.zero);

    expect(h.runtime.fetchCalls, isEmpty);
  });

  test('malformed/unparsable count body is ignored silently (MENUNOTIF-02)',
      () async {
    final h = _Harness();
    h.runtime.fetchHandler = (url, options) =>
        InPageFetchResult(ok: true, status: 200, text: _notificationsResponse([]));
    h.watcher.start();

    h.runtime.events.emitNetwork(
      NetworkEvent(method: 'POST', url: _countUrl, body: 'not json at all'),
    );
    h.runtime.events.emitNetwork(
      NetworkEvent(method: 'POST', url: _countUrl, body: null),
    );
    h.runtime.events.emitNetwork(
      NetworkEvent(method: 'POST', url: _countUrl, body: jsonEncode({'d': 'NaN'})),
    );
    await Future<void>.delayed(Duration.zero);

    expect(h.runtime.fetchCalls, isEmpty);
    final state = await h.stateStore.load();
    expect(state.lastCount, isNull);
    expect(state.notifiedUids, isEmpty);
  });

  test('a fetch failure leaves the persisted lastCount unchanged so a later '
      'differing count still retries (MENUNOTIF-08)', () async {
    final h = _Harness();
    h.runtime.fetchHandler = (url, options) =>
        throw Exception('network error');
    h.watcher.start();

    h.runtime.events.emitNetwork(_countEvent(7));
    await Future<void>.delayed(Duration.zero);

    var state = await h.stateStore.load();
    expect(state.lastCount, isNull, reason: 'save() must be skipped on failure');
    expect(h.runtime.fetchCalls, hasLength(1));

    // Retry: same count (7) still differs from the untouched persisted
    // lastCount (null), so the watcher tries again — this time it succeeds.
    h.runtime.fetchHandler = (url, options) => InPageFetchResult(
          ok: true,
          status: 200,
          text: _notificationsResponse([_item('u1')]),
        );
    h.runtime.events.emitNetwork(_countEvent(7));
    await Future<void>.delayed(Duration.zero);

    state = await h.stateStore.load();
    expect(state.lastCount, 7);
    expect(state.notifiedUids, {'u1'});
    expect(h.runtime.fetchCalls, hasLength(2));
  });

  test('UID pruning drops items no longer present in a later response '
      '(MENUNOTIF-09)', () async {
    final h = _Harness();
    h.runtime.fetchHandler = (url, options) => InPageFetchResult(
          ok: true,
          status: 200,
          text: _notificationsResponse([_item('u1'), _item('u2')]),
        );
    h.watcher.start();

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);
    expect((await h.stateStore.load()).notifiedUids, {'u1', 'u2'});

    // u2 is resolved in-game and no longer appears; count changes again.
    h.runtime.fetchHandler = (url, options) => InPageFetchResult(
          ok: true,
          status: 200,
          text: _notificationsResponse([_item('u1')]),
        );
    h.runtime.events.emitNetwork(_countEvent(2));
    await Future<void>.delayed(Duration.zero);

    final state = await h.stateStore.load();
    expect(state.lastCount, 2);
    expect(state.notifiedUids, {'u1'});
  });

  test('reentrancy guard drops an overlapping second trigger', () async {
    final h = _Harness();
    final completer = Completer<InPageFetchResult>();
    var fetchCallCount = 0;
    h.runtime.fetchHandler = (url, options) {
      fetchCallCount++;
      return completer.future;
    };
    final batches = <List<MenuNotification>>[];
    h.watcher.newNotifications.listen(batches.add);
    h.watcher.start();

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);
    // The first trigger is now blocked mid-fetch (inside the un-completed
    // completer). A second, different count arrives before it resolves.
    h.runtime.events.emitNetwork(_countEvent(2));
    await Future<void>.delayed(Duration.zero);

    expect(fetchCallCount, 1, reason: 'the overlapping trigger must be dropped, not queued');

    completer.complete(InPageFetchResult(
      ok: true,
      status: 200,
      text: _notificationsResponse([_item('u1')]),
    ));
    await Future<void>.delayed(Duration.zero);

    final state = await h.stateStore.load();
    expect(state.lastCount, 1, reason: 'only the first trigger\'s count is persisted');
    expect(batches, hasLength(1));
  });

  test('start() is idempotent and dispose() stops delivering events',
      () async {
    final h = _Harness();
    h.runtime.fetchHandler = (url, options) =>
        InPageFetchResult(ok: true, status: 200, text: _notificationsResponse([]));
    h.watcher.start();
    h.watcher.start(); // no-op, does not double-subscribe

    h.runtime.events.emitNetwork(_countEvent(1));
    await Future<void>.delayed(Duration.zero);
    expect(h.runtime.fetchCalls, hasLength(1));

    await h.watcher.dispose();
    h.runtime.events.emitNetwork(_countEvent(2));
    await Future<void>.delayed(Duration.zero);
    expect(h.runtime.fetchCalls, hasLength(1));
  });
}
