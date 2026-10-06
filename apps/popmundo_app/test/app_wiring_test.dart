import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/app_wiring.dart';
import 'package:popmundo_app/gm/gm_menu_registry.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

/// [AppWiring] takes the concrete [InAppPopmundoRuntime] because
/// [PopmundoWebView] and `syncUserScripts` are defined on the adapter, not on
/// the [PopmundoRuntime] port. That is fine to construct here: with no
/// WebView attached its `controller` is null, which is exactly the
/// "WebView not attached yet" path CRS-09 says must be swallowed. Its event
/// bus is a real [PopmundoEventBus], so events can be driven directly.
AppWiring _wiring({KeyValueStore? store}) {
  // MemoryCookieSink implements both ports; the real InAppCookieSink builds a
  // CookieManager eagerly, which needs a platform channel `flutter test` has
  // no way to provide.
  final jar = MemoryCookieSink();
  return AppWiring(
    runtime: InAppPopmundoRuntime(),
    store: store ?? MemoryKeyValueStore(),
    secretStore: MemorySecretStore(),
    cookieSink: jar,
    cookieSource: jar,
  );
}

/// A store whose reads resolve only when released, so `catalog.list()` can be
/// made to land *after* `dispose()`. With `MemoryKeyValueStore` the read always
/// wins the race, which is why an earlier version of the dispose test could not
/// tell the `_disposed` guard from its absence.
class _GatedStore implements KeyValueStore {
  _GatedStore(this._inner);

  final KeyValueStore _inner;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<Object?> get(String key) async {
    await _gate.future;
    return _inner.get(key);
  }

  @override
  Future<void> set(String key, Object? value) => _inner.set(key, value);

  @override
  Future<void> remove(String key) => _inner.remove(key);
}

InstalledUserScript _script(
  String id, {
  required bool enabled,
  Map<String, List<String>> headers = const {},
}) => InstalledUserScript(
  id: id,
  sourceUrl: 'https://example.test/$id.user.js',
  name: id,
  enabled: enabled,
  source: '// $id',
  headers: headers,
  installedAt: DateTime.utc(2026, 1, 1),
  runAt: UserScriptRunAt.documentEnd,
  forMainFrameOnly: true,
);

void main() {
  test('start() publishes the catalog, split into all and enabled', () async {
    final store = MemoryKeyValueStore();
    final catalog = UserScriptCatalog(store);
    await catalog.add(_script('a', enabled: true));
    await catalog.add(_script('b', enabled: false));

    final wiring = _wiring(store: store);
    expect(
      wiring.userscripts.value.ready,
      isFalse,
      reason: 'the shell shows a spinner until the catalog resolves',
    );

    wiring.start();
    await pumpEventQueue();

    final state = wiring.userscripts.value;
    expect(state.ready, isTrue);
    expect(state.all.map((s) => s.id), ['a', 'b']);
    expect(state.enabled.map((s) => s.id), ['a']);
    expect(state.previouslyEnabledIds, {'a'});

    await wiring.dispose();
  });

  test(
    'applyUserScripts sets previouslyEnabledIds to exactly the enabled ids '
    '(the diff base syncUserScripts gets on the next call) — CRS-12',
    () async {
      final wiring = _wiring();
      wiring.start();
      await pumpEventQueue();

      await wiring.applyUserScripts([
        _script('a', enabled: true),
        _script('b', enabled: false),
        _script('c', enabled: true),
      ]);

      expect(wiring.userscripts.value.previouslyEnabledIds, {'a', 'c'});
      expect(wiring.userscripts.value.enabled.map((s) => s.id), ['a', 'c']);
      expect(wiring.userscripts.value.all.map((s) => s.id), ['a', 'b', 'c']);

      // Disabling 'a' must move it out of the diff base, not just out of the
      // rendered list — otherwise the next sync would fail to unregister it.
      await wiring.applyUserScripts([
        _script('a', enabled: false),
        _script('c', enabled: true),
      ]);

      expect(wiring.userscripts.value.previouslyEnabledIds, {'c'});

      await wiring.dispose();
    },
  );

  test('applyUserScripts swallows the not-attached WebView and still publishes '
      '— CRS-09', () async {
    final wiring = _wiring();
    wiring.start();
    await pumpEventQueue();

    // No controller is attached, so syncUserScripts throws
    // PopmundoRuntimeException('WebView not attached'). The catalog must
    // still reach the UI.
    await expectLater(
      wiring.applyUserScripts([_script('a', enabled: true)]),
      completes,
    );
    expect(wiring.userscripts.value.all.map((s) => s.id), ['a']);

    await wiring.dispose();
  });

  test(
    'a second start() leaks no subscription behind dispose() — CRS-10',
    () async {
      final wiring = _wiring();
      wiring.gmMenuRegistry.register(
        const GmMenuCommand(scriptId: 's', commandId: 'c', caption: 'Cmd'),
      );

      wiring.start();
      wiring.start();
      await pumpEventQueue();
      await wiring.dispose();

      // Without the _started guard the second start() would overwrite the
      // subscription fields, so dispose() would cancel only the newer ones and
      // the first navigation subscription would still be live — clearing the
      // registry on an event that arrives after disposal.
      wiring.runtime.events.emitNavigation(
        NavigationEvent(url: 'https://www.popmundo.com/'),
      );
      await pumpEventQueue();

      expect(
        wiring.gmMenuRegistry.commands,
        hasLength(1),
        reason: 'no live subscription may survive dispose()',
      );
    },
  );

  test('a navigation event clears the GM menu while started', () async {
    final wiring = _wiring();
    wiring.gmMenuRegistry.register(
      const GmMenuCommand(scriptId: 's', commandId: 'c', caption: 'Cmd'),
    );
    wiring.start();
    await pumpEventQueue();

    wiring.runtime.events.emitNavigation(
      NavigationEvent(url: 'https://www.popmundo.com/'),
    );
    await pumpEventQueue();

    expect(
      wiring.gmMenuRegistry.commands,
      isEmpty,
      reason: 'scripts re-register their commands on each page',
    );

    await wiring.dispose();
  });

  test('dispose() is a no-op when start() never ran, and is idempotent '
      '— CRS-11', () async {
    final wiring = _wiring();

    await expectLater(wiring.dispose(), completes);
    await expectLater(wiring.dispose(), completes);
  });

  test('a catalog read that lands after dispose() is dropped, not published '
      '— CRS-11', () async {
    final store = _GatedStore(MemoryKeyValueStore());
    final jar = MemoryCookieSink();
    final wiring = AppWiring(
      runtime: InAppPopmundoRuntime(),
      store: store,
      secretStore: MemorySecretStore(),
      cookieSink: jar,
      cookieSource: jar,
    );

    // start() fires catalog.list() unawaited. Holding the read open until
    // after dispose() forces the exact race the _disposed guard exists for;
    // without gating, the read always wins and the guard is never exercised.
    wiring.start();
    await wiring.dispose();
    store.release();
    await pumpEventQueue();

    // _publish assigns before notifyListeners() throws, so without the guard
    // `ready` flips to true observably — asserting "does not throw" alone
    // would not discriminate.
    expect(
      wiring.userscripts.value.ready,
      isFalse,
      reason: 'nothing may be published into a disposed notifier',
    );
  });

  test('connectHeadersFor returns the script @connect list, and empty for an '
      'unknown id', () async {
    final wiring = _wiring();
    wiring.start();
    await pumpEventQueue();

    await wiring.applyUserScripts([
      _script(
        'a',
        enabled: true,
        headers: {
          'connect': ['api.example.test', 'cdn.example.test'],
        },
      ),
      _script('b', enabled: true),
    ]);

    expect(wiring.connectHeadersFor('a'), [
      'api.example.test',
      'cdn.example.test',
    ]);
    expect(
      wiring.connectHeadersFor('b'),
      isEmpty,
      reason: 'a script with no @connect grants no hosts',
    );
    expect(
      wiring.connectHeadersFor('gone'),
      isEmpty,
      reason: 'a script can be deleted while a request is still in flight',
    );

    await wiring.dispose();
  });
}
