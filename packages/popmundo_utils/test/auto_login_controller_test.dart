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
  late FakePopmundoRuntime runtime;
  late TimedFetch timedFetch;
  late MemoryKeyValueStore kv;
  late MemorySecretStore secrets;
  late AutoLoginSettingsStore settingsStore;
  late LastUrlStore lastUrlStore;
  late AutoLoginController controller;

  const loginHtml = '''
<input type="hidden" name="__VIEWSTATE" value="VS" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN" />
<input type="hidden" name="__EVENTVALIDATION" value="EV" />
<input id="ctl00_cphRightColumn_ucLogin_txtUsername" />
''';

  const chooseHtml = '''
<input type="hidden" name="__EVENTTARGET" value="" />
<input type="hidden" name="__EVENTARGUMENT" value="" />
<input type="hidden" name="__VIEWSTATE" value="VS2" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN2" />
<input type="hidden" name="__EVENTVALIDATION" value="EV2" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl04\$btnChooseCharacter2" value="Escolher Troy" />
''';

  setUp(() async {
    runtime = FakePopmundoRuntime();
    final clock = _VirtualClock();
    timedFetch = TimedFetch(runtime, now: () => clock.now, sleep: clock.sleep);
    kv = MemoryKeyValueStore();
    secrets = MemorySecretStore();
    settingsStore = AutoLoginSettingsStore(kv);
    lastUrlStore = LastUrlStore(kv);
    controller = AutoLoginController(
      runtime: runtime,
      timedFetch: timedFetch,
      settingsStore: settingsStore,
      secretStore: secrets,
      lastUrlStore: lastUrlStore,
    );
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: true,
        username: 'troyfournier',
        characterName: 'Troy',
        status: 0,
      ),
    );
    await secrets.write(AutoLoginSettingsStore.passwordSecretKey, 'test-password-not-real');
    await lastUrlStore.record(
      'https://74.popmundo.com/World/Popmundo.aspx/Character/99',
    );
    controller.start();
  });

  tearDown(() async {
    await controller.dispose();
  });

  test('happy path: 302 loadUrl then choose then restore last URL', () async {
    var step = 0;
    runtime.fetchHandler = (url, options) async {
      step++;
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET' && url.endsWith('/')) {
        return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
      }
      if (method == 'POST' && url.endsWith('/')) {
        expect(options?['redirect'], 'manual');
        expect(options?['body'], contains('troyfournier'));
        expect(options?['body'], contains('test-password-not-real'));
        return const InPageFetchResult(
          ok: false,
          status: 302,
          text: '',
          headers: {
            'location':
                'https://74.popmundo.com/Login.aspx?t=token',
          },
        );
      }
      if (method == 'GET' && url.contains('ChooseCharacter')) {
        return const InPageFetchResult(ok: true, status: 200, text: chooseHtml);
      }
      if (method == 'POST' && url.contains('ChooseCharacter')) {
        expect(
          options?['body'],
          contains(
            Uri.encodeQueryComponent(
              r'ctl00$cphLeftColumn$repCharacters$ctl04$btnChooseCharacter2',
            ),
          ),
        );
        return const InPageFetchResult(ok: true, status: 200, text: 'ok');
      }
      return const InPageFetchResult(ok: true, status: 200, text: '');
    };

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Allow async cycle to progress through loadUrl → choose
    for (var i = 0; i < 20 && runtime.loadUrlCalls.length < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(runtime.loadUrlCalls, isNotEmpty);
    expect(
      runtime.loadUrlCalls.first.toString(),
      contains('74.popmundo.com/Login.aspx'),
    );

    // Fake loadUrl already emitted navigation; emit ChooseCharacter explicitly
    // if host path wasn't ChooseCharacter (loadUrl used Login.aspx URL).
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      ),
    );
    for (var i = 0; i < 30 && runtime.loadUrlCalls.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    expect(runtime.loadUrlCalls.length, greaterThanOrEqualTo(2));
    expect(
      runtime.loadUrlCalls.last.toString(),
      'https://74.popmundo.com/World/Popmundo.aspx/Character/99',
    );
    expect(controller.inFlight, isFalse);
    expect(step, greaterThanOrEqualTo(4));
  });

  test('200 login response aborts without choose-character', () async {
    runtime.fetchHandler = (url, options) async {
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET') {
        return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
      }
      return const InPageFetchResult(
        ok: true,
        status: 200,
        text: loginHtml,
      );
    };

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(runtime.loadUrlCalls, isEmpty);
    expect(
      runtime.fetchCalls.any((c) => c.url.contains('ChooseCharacter')),
      isFalse,
    );
  });

  test('disabled settings skip login', () async {
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: false,
        username: 'troyfournier',
        characterName: 'Troy',
      ),
    );
    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(runtime.fetchCalls, isEmpty);
  });

  test('missing password skips login', () async {
    await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(runtime.fetchCalls, isEmpty);
  });

  test('inFlight ignores second trigger', () async {
    final getStarts = <String>[];
    runtime.fetchHandler = (url, options) async {
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET' && url.endsWith('/')) {
        getStarts.add(url);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
    };
    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(getStarts.length, 1);
  });

  test('null last URL restores World home after choose (NAV-02)', () async {
    await kv.remove(LastUrlStore.defaultStorageKey);
    runtime.fetchHandler = (url, options) async {
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET' && url.endsWith('/')) {
        return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
      }
      if (method == 'POST' && url.endsWith('/')) {
        return const InPageFetchResult(
          ok: false,
          status: 302,
          text: '',
          headers: {
            'location': 'https://74.popmundo.com/Login.aspx?t=token',
          },
        );
      }
      if (method == 'GET' && url.contains('ChooseCharacter')) {
        return const InPageFetchResult(ok: true, status: 200, text: chooseHtml);
      }
      if (method == 'POST' && url.contains('ChooseCharacter')) {
        return const InPageFetchResult(ok: true, status: 200, text: 'ok');
      }
      return const InPageFetchResult(ok: true, status: 200, text: '');
    };

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      ),
    );
    for (var i = 0; i < 30 && runtime.loadUrlCalls.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    expect(
      runtime.loadUrlCalls.last.toString(),
      'https://74.popmundo.com/World/Popmundo.aspx',
    );
  });

  test('missing VIEWSTATE tokens abort without loadUrl', () async {
    runtime.fetchHandler = (url, options) async {
      return const InPageFetchResult(
        ok: true,
        status: 200,
        text: '<html><body>no tokens</body></html>',
      );
    };
    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(runtime.loadUrlCalls, isEmpty);
    expect(controller.inFlight, isFalse);
  });

  test('missing character button aborts without restore', () async {
    runtime.fetchHandler = (url, options) async {
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET' && url.endsWith('/')) {
        return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
      }
      if (method == 'POST' && url.endsWith('/')) {
        return const InPageFetchResult(
          ok: false,
          status: 302,
          text: '',
          headers: {
            'location': 'https://74.popmundo.com/Login.aspx?t=token',
          },
        );
      }
      if (url.contains('ChooseCharacter')) {
        return const InPageFetchResult(
          ok: true,
          status: 200,
          text: '''
<input type="hidden" name="__VIEWSTATE" value="VS2" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN2" />
<input type="hidden" name="__EVENTVALIDATION" value="EV2" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl00\$btnChooseCharacter2" value="Escolher Peter" />
''',
        );
      }
      return const InPageFetchResult(ok: true, status: 200, text: '');
    };

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      runtime.loadUrlCalls
          .where((u) => u.path.contains('Character/99'))
          .isEmpty,
      isTrue,
    );
  });
}
