import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/cookie_watcher.dart';
import 'package:popmundo_app/debug_overlay.dart' show CookieSummary;
import 'package:popmundo_utils/popmundo_utils.dart';

void main() {
  test(
    'refresh() publishes the jar it read for the current sticky origin',
    () async {
      Uri? asked;
      final watcher = CookieWatcher(
        HostTracker(),
        read: (origin) async {
          asked = origin;
          return const [
            CookieSummary(
              name: 'ASP.NET_SessionId',
              domain: 'www.popmundo.com',
            ),
          ];
        },
      );

      await watcher.refresh();

      expect(asked, Uri.parse('https://www.popmundo.com'));
      expect(watcher.cookies.value.single.name, 'ASP.NET_SessionId');
      expect(watcher.cookies.value.single.domain, 'www.popmundo.com');

      watcher.dispose();
    },
  );

  test(
    'refresh() resolves against the host at call time, not construction',
    () async {
      final host = HostTracker();
      final asked = <Uri>[];
      final watcher = CookieWatcher(
        host,
        read: (origin) async {
          asked.add(origin);
          return const [];
        },
      );

      await watcher.refresh();
      // AD-007: the sticky host moves to the load-balanced node after login.
      host.onNavigation(
        Uri.parse('https://5.popmundo.com/World/Popmundo.aspx'),
      );
      await watcher.refresh();

      expect(asked, [
        Uri.parse('https://www.popmundo.com'),
        Uri.parse('https://5.popmundo.com'),
      ]);

      watcher.dispose();
    },
  );

  test(
    'a failing read leaves the last good jar in place and does not throw',
    () async {
      var fail = false;
      final watcher = CookieWatcher(
        HostTracker(),
        read: (origin) async {
          if (fail) throw StateError('CookieManager unavailable');
          return const [CookieSummary(name: 'a', domain: 'www.popmundo.com')];
        },
      );

      await watcher.refresh();
      fail = true;
      await expectLater(watcher.refresh(), completes);

      expect(
        watcher.cookies.value.single.name,
        'a',
        reason:
            'CookieManager is absent in test/desktop bindings; the overlay '
            'keeps showing what it last knew instead of crashing the shell',
      );

      watcher.dispose();
    },
  );

  test(
    'a read that completes after dispose() is dropped, not written — CRS-11',
    () async {
      final gate = Completer<List<CookieSummary>>();
      final watcher = CookieWatcher(
        HostTracker(),
        read: (origin) => gate.future,
      );

      // refresh() is fire-and-forget in AppWiring.start()/_onNavigation, so it
      // routinely outlives the widget that owns it.
      final pending = watcher.refresh();
      watcher.dispose();
      gate.complete(const [
        CookieSummary(name: 'late', domain: 'www.popmundo.com'),
      ]);

      await pending;

      // Asserting "completes" would NOT discriminate: refresh()'s broad catch
      // swallows the disposed-ValueNotifier assertion too. But ValueNotifier's
      // setter assigns _value *before* notifyListeners() throws, so without
      // the guard the late jar is observably written.
      expect(
        watcher.cookies.value,
        isEmpty,
        reason: 'a read that lands after dispose() must be dropped, not stored',
      );
    },
  );

  test('refresh() after dispose() never reaches the reader', () async {
    var reads = 0;
    final watcher = CookieWatcher(
      HostTracker(),
      read: (origin) async {
        reads++;
        return const [];
      },
    );

    watcher.dispose();
    await watcher.refresh();

    expect(reads, 0);
  });

  test('dispose() is idempotent', () {
    final watcher = CookieWatcher(HostTracker(), read: (_) async => const []);

    watcher.dispose();
    expect(watcher.dispose, returnsNormally);
  });
}
