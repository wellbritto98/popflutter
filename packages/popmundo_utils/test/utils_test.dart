import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

Utils _utils(FakePopmundoRuntime runtime, _Clock clock) {
  return Utils(
    runtime,
    TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep),
  );
}

const _characterHtml = '''
<html><body>
<div class="idHolder">42</div>
<div id="ppm-content">
  <div class="box ofauto charPresBox"><h2>Ada</h2></div>
</div>
</body></html>
''';

void main() {
  test('getMyID returns integer from Character page HTML', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: _characterHtml);
    expect(await _utils(runtime, _Clock()).getMyID(), 42);
    expect(runtime.evaluateCalls, isEmpty);
    expect(runtime.fetchCalls.single.url, contains('/World/Popmundo.aspx/Character'));
  });

  test('getMyID returns 0 when missing or non-numeric', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler = (url, options) =>
        const InPageFetchResult(ok: true, status: 200, text: '<div class="idHolder">abc</div>');
    expect(await _utils(runtime, _Clock()).getMyID(), 0);

    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: '<html></html>');
    expect(await _utils(runtime, _Clock()).getMyID(), 0);
  });

  test('getMyName returns empty when missing', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: '<html></html>');
    expect(await _utils(runtime, _Clock()).getMyName(), '');

    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: _characterHtml);
    expect(await _utils(runtime, _Clock()).getMyName(), 'Ada');
  });

  test('getMyCharDetails parses id and name from one cached fetch', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: _characterHtml);
    final utils = _utils(runtime, _Clock());
    final first = await utils.getMyCharDetails();
    final id = await utils.getMyID();
    final name = await utils.getMyName();
    expect(first, (id: 42, name: 'Ada'));
    expect(id, 42);
    expect(name, 'Ada');
    expect(runtime.fetchCalls, hasLength(1));
  });

  test('failed Character fetch yields 0 and empty name', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: false, status: 500, text: 'nope');
    final details = await _utils(runtime, _Clock()).getMyCharDetails();
    expect(details, (id: 0, name: ''));
  });

  test('Character fetch resolves against the sticky host', () async {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://12.popmundo.com/'));
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: _characterHtml);
    await _utils(runtime, _Clock()).getMyID();
    expect(runtime.fetchCalls.single.url, contains('12.popmundo.com'));
    expect(runtime.fetchCalls.single.url.contains('www.popmundo.com'), isFalse);
  });

  test('getServerLink uses current host', () {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://12.popmundo.com/'));
    expect(
      _utils(runtime, _Clock())
          .getServerLink('/World/Popmundo.aspx/Character/1')
          .toString(),
      'https://12.popmundo.com/World/Popmundo.aspx/Character/1/',
    );
  });
}
