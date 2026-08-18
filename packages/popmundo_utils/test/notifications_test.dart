import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

void main() {
  test('unknown notification level throws', () async {
    final runtime = FakePopmundoRuntime();
    final tf = TimedFetch(runtime, now: () => DateTime.now(), sleep: (_) async {});
    final notifications = Notifications(runtime, tf);
    expect(
      notifications.createNotification(level: 'banana'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('missing container does not throw', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => null;
    final tf = TimedFetch(runtime, now: () => DateTime.now(), sleep: (_) async {});
    final result = await Notifications(runtime, tf).notifySuccess(textContent: 'hi');
    expect(result, isNull);
  });

  test('getPageNotifications POSTs without cache on current host', () async {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://73.popmundo.com/'));
    runtime.fetchHandler = (url, options) {
      return InPageFetchResult(
        ok: true,
        status: 200,
        text: jsonEncode({
          'd': jsonEncode([
            {'Status': 1, 'Text': 'Welcome'},
          ]),
        }),
      );
    };
    final clock = _Clock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    final parsed = await Notifications(runtime, tf).getPageNotifications();

    expect(parsed.status, 'success');
    expect(parsed.text, 'Welcome');
    expect(runtime.fetchCalls, hasLength(1));
    expect(runtime.fetchCalls.single.url, contains('73.popmundo.com'));
    expect(
      runtime.fetchCalls.single.url,
      contains('/WebServices/A/Open.asmx/GetPageNotifications'),
    );
    expect(runtime.fetchCalls.single.options?['method'], 'POST');
  });

  test('parsePageNotifications maps status codes', () {
    expect(
      Notifications.parsePageNotifications(jsonEncode({
        'd': {'Status': 0, 'Text': 'n'},
      })).status,
      'normal',
    );
    expect(
      Notifications.parsePageNotifications(jsonEncode({
        'd': {'Status': 2, 'Text': 'e'},
      })).status,
      'error',
    );
  });
}
