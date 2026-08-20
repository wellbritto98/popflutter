import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  Future<void> sleep(Duration d) async => now = now.add(d);
}

void main() {
  test('fetch() POSTs GetMenuNotifications without cache on current host '
      '(MENUNOTIF-04)', () async {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://74.popmundo.com/'));
    runtime.fetchHandler = (url, options) {
      return InPageFetchResult(
        ok: true,
        status: 200,
        text: jsonEncode({
          'd': jsonEncode([
            {'UID': 'a1', 'Text': 'Offer'},
          ]),
        }),
      );
    };
    final clock = _Clock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    final service =
        MenuNotificationsService(runtime, tf, now: () => clock.now);

    final result = await service.fetch();

    expect(result, hasLength(1));
    expect(result.single.uid, 'a1');
    expect(result.single.text, 'Offer');
    expect(runtime.fetchCalls, hasLength(1));
    expect(runtime.fetchCalls.single.url, contains('74.popmundo.com'));
    expect(
      runtime.fetchCalls.single.url,
      contains('/WebServices/A/Open.asmx/GetMenuNotifications'),
    );
    expect(runtime.fetchCalls.single.options?['method'], 'POST');
    final body =
        jsonDecode(runtime.fetchCalls.single.options?['body'] as String)
            as Map;
    expect(body['ts'], '${clock.now.millisecondsSinceEpoch}');
  });

  test('useCache:false means a changed ts always hits the network', () async {
    final runtime = FakePopmundoRuntime();
    runtime.fetchHandler = (url, options) => InPageFetchResult(
          ok: true,
          status: 200,
          text: jsonEncode({'d': jsonEncode(<Object?>[])}),
        );
    final clock = _Clock();
    final tf = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    final service =
        MenuNotificationsService(runtime, tf, now: () => clock.now);

    await service.fetch();
    clock.now = clock.now.add(const Duration(seconds: 1));
    await service.fetch();

    expect(runtime.fetchCalls, hasLength(2));
  });

  test('parseMenuNotifications double-decodes the {d: ...} envelope and '
      'drops malformed entries (MENUNOTIF-05)', () {
    final responseText = jsonEncode({
      'd': jsonEncode([
        {
          'UID': 'u-1',
          'DateCreated': '2026-08-19',
          'TimeCreated': '09:30',
          'Text': 'Contract ready',
          'Url': '/World/Contract.aspx?id=1',
          'Repeats': 1,
          'Type': 3,
          'Int1': 10,
        },
        {'Text': 'no uid, dropped'},
        'not-a-map',
      ]),
    });

    final parsed = MenuNotificationsService.parseMenuNotifications(responseText);

    expect(parsed, hasLength(1));
    expect(parsed.single.uid, 'u-1');
    expect(parsed.single.dateCreated, '2026-08-19');
    expect(parsed.single.timeCreated, '09:30');
    expect(parsed.single.text, 'Contract ready');
    expect(parsed.single.url, '/World/Contract.aspx?id=1');
    expect(parsed.single.repeats, 1);
    expect(parsed.single.type, 3);
    expect(parsed.single.int1, 10);
  });

  test('parseMenuNotifications returns empty list for an empty array', () {
    final responseText = jsonEncode({'d': jsonEncode(<Object?>[])});
    expect(
      MenuNotificationsService.parseMenuNotifications(responseText),
      isEmpty,
    );
  });
}
