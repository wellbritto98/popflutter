import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

class _VirtualClock {
  DateTime now = DateTime.utc(2026, 1, 1);

  Future<void> sleep(Duration d) async {
    now = now.add(d);
  }
}

void main() {
  test('serializes overlapping fetches', () async {
    final runtime = FakePopmundoRuntime();
    var inFlight = 0;
    var maxInFlight = 0;
    runtime.fetchHandler = (url, options) async {
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      return InPageFetchResult(ok: true, status: 200, text: url);
    };
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    await Future.wait([tf.fetch('/a'), tf.fetch('/b')]);
    expect(maxInFlight, 1);
    expect(runtime.fetchCalls.length, 2);
  });

  test('waits at least 750ms between network attempts', () async {
    final runtime = FakePopmundoRuntime();
    final times = <DateTime>[];
    runtime.fetchHandler = (url, options) {
      return const InPageFetchResult(ok: true, status: 200, text: 'ok');
    };
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    final start = clock.now;
    await tf.fetch('/a');
    times.add(clock.now);
    await tf.fetch('/b');
    times.add(clock.now);

    expect(times.last.difference(start) >= const Duration(milliseconds: 750), isTrue);
  });

  test('caches METHOD:URL on success', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: 'html');
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    expect(await tf.fetch('/x'), 'html');
    expect(await tf.fetch('/x'), 'html');
    expect(runtime.fetchCalls.length, 1);
  });

  test('useCache false always hits the network', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: 'html');
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    await tf.fetch('/x');
    await tf.fetch('/x', useCache: false);
    expect(runtime.fetchCalls.length, 2);
  });

  test('non-2xx is an error and is not cached', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: false, status: 500, text: 'nope');
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    await expectLater(tf.fetch('/x'), throwsA(isA<TimedFetchException>()));
    runtime.fetchHandler =
        (url, options) => const InPageFetchResult(ok: true, status: 200, text: 'ok');
    expect(await tf.fetch('/x'), 'ok');
    expect(runtime.fetchCalls.length, 2);
  });

  test('relative paths resolve against the current sticky host', () async {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://84.popmundo.com/'));
    runtime.fetchHandler =
        (url, options) => InPageFetchResult(ok: true, status: 200, text: url);
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    final text = await tf.fetch('/WebServices/A/Open.asmx/GetPageNotifications');
    expect(text, contains('84.popmundo.com'));
    expect(text, contains('/WebServices/A/Open.asmx/GetPageNotifications'));
    expect(text.contains('www.popmundo.com'), isFalse);
  });

  test('fetchResponse acceptRedirect returns 302 without throwing', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler = (url, options) => const InPageFetchResult(
          ok: false,
          status: 302,
          text: '',
          headers: {
            'location':
                'https://74.popmundo.com/Login.aspx?t=abc',
          },
        );
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    final result = await tf.fetchResponse(
      '/',
      options: {'method': 'POST', 'redirect': 'manual'},
      useCache: false,
      acceptRedirect: true,
    );
    expect(result.status, 302);
    expect(result.locationHeader, contains('74.popmundo.com/Login.aspx'));
  });

  test('fetchResponse without acceptRedirect throws on 302', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler = (url, options) => const InPageFetchResult(
          ok: false,
          status: 302,
          text: '',
          headers: {'location': 'https://74.popmundo.com/Login.aspx?t=abc'},
        );
    final clock = _VirtualClock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);

    await expectLater(
      tf.fetchResponse('/', useCache: false),
      throwsA(isA<TimedFetchException>()),
    );
  });
}
