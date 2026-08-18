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

  void wireLoginGet() {
    runtime.fetchHandler = (url, options) async {
      final method = (options?['method'] as String? ?? 'GET').toUpperCase();
      if (method == 'GET' && (url.endsWith('/') || url.contains('Default'))) {
        return const InPageFetchResult(ok: true, status: 200, text: loginHtml);
      }
      return const InPageFetchResult(ok: true, status: 200, text: '');
    };
  }

  void wireChooseDom(String html) {
    runtime.evaluateHandler = (source) {
      if (source.contains('document.documentElement.outerHTML')) {
        return html;
      }
      return 'ok';
    };
  }

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

  test('happy path: form-nav login then choose then restore last URL', () async {
    wireLoginGet();
    wireChooseDom(chooseHtml);

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    for (var i = 0; i < 30 && runtime.evaluateCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(runtime.evaluateCalls, isNotEmpty);
    expect(runtime.evaluateCalls.first, contains("form.method='POST'"));
    expect(runtime.evaluateCalls.first, contains('troyfournier'));
    expect(controller.inFlight, isTrue);

    runtime.host.onNavigation(Uri.parse('https://74.popmundo.com/'));
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      ),
    );
    for (var i = 0; i < 30; i++) {
      final chose = runtime.evaluateCalls.any(
        (c) =>
            c.contains('btnChooseCharacter2') ||
            c.contains('Escolher Troy'),
      );
      if (chose) break;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    expect(
      runtime.evaluateCalls.any((c) => c.contains('Escolher Troy')),
      isTrue,
    );

    // Character form-nav lands on World; restore runs on that navigation.
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx',
      ),
    );
    for (var i = 0; i < 30 && runtime.loadUrlCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    expect(runtime.loadUrlCalls, isNotEmpty);
    expect(
      runtime.loadUrlCalls.last.toString(),
      'https://74.popmundo.com/World/Popmundo.aspx/Character/99',
    );
    expect(controller.inFlight, isFalse);
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
    wireLoginGet();
    wireChooseDom(chooseHtml);

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    for (var i = 0; i < 30 && runtime.evaluateCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    runtime.host.onNavigation(Uri.parse('https://74.popmundo.com/'));
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      ),
    );
    for (var i = 0; i < 30; i++) {
      if (runtime.evaluateCalls.any((c) => c.contains('Escolher Troy'))) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    runtime.events.emitNavigation(
      NavigationEvent(
        url: 'https://74.popmundo.com/World/Popmundo.aspx',
      ),
    );
    for (var i = 0; i < 30 && runtime.loadUrlCalls.isEmpty; i++) {
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
    expect(runtime.evaluateCalls, isEmpty);
    expect(controller.inFlight, isFalse);
  });

  test('missing character button aborts without restore', () async {
    wireLoginGet();
    wireChooseDom('''
<input type="hidden" name="__VIEWSTATE" value="VS2" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="GEN2" />
<input type="hidden" name="__EVENTVALIDATION" value="EV2" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl00\$btnChooseCharacter2" value="Escolher Peter" />
''');

    runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    for (var i = 0; i < 30 && runtime.evaluateCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
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
