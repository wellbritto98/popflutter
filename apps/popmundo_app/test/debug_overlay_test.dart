import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/debug_overlay.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

void main() {
  testWidgets('collapsed overlay does not show the panel', (tester) async {
    final bus = PopmundoEventBus();
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    expect(find.byKey(const Key('debug-toggle')), findsOneWidget);
    expect(find.byKey(const Key('debug-panel')), findsNothing);
  });

  testWidgets('expanded overlay shows host, events, eval and clear', (tester) async {
    final bus = PopmundoEventBus();
    final host = HostTracker()..onNavigation(Uri.parse('https://73.popmundo.com/'));
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: host,
          events: bus,
          evaluate: (source) async => 'result:$source',
          cookies: const [CookieSummary(name: 'session', domain: 'popmundo.com')],
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('debug-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debug-panel')), findsOneWidget);
    expect(find.byKey(const Key('debug-host')), findsOneWidget);
    expect(find.textContaining('73.popmundo.com'), findsWidgets);
    expect(find.text('session@popmundo.com'), findsOneWidget);
    expect(find.textContaining('secret-value'), findsNothing);

    bus.emitNetwork(NetworkEvent(method: 'GET', url: 'https://73.popmundo.com/a', status: 200));
    bus.emitConsole(ConsoleEvent(level: 'log', message: 'hello-console'));
    await tester.pump();
    expect(find.textContaining('GET'), findsOneWidget);
    expect(find.textContaining('hello-console'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('debug-eval-input')), '1+1');
    await tester.tap(find.byKey(const Key('debug-eval-run')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debug-eval-result')), findsOneWidget);
    expect(find.text('result:1+1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('debug-clear')));
    await tester.pump();
    expect(find.textContaining('GET 200'), findsNothing);
    expect(find.textContaining('hello-console'), findsNothing);
  });
}
