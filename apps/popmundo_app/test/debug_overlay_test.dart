import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/debug_overlay.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

void main() {
  testWidgets('collapsed overlay renders no debug control and no panel', (tester) async {
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
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('debug-panel')), findsNothing);
  });

  testWidgets('visible overlay shows host, events, eval and clear', (tester) async {
    final bus = PopmundoEventBus();
    final host = HostTracker()..onNavigation(Uri.parse('https://73.popmundo.com/'));
    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlay(
          host: host,
          events: bus,
          evaluate: (source) async => 'result:$source',
          cookies: const [CookieSummary(name: 'session', domain: 'popmundo.com')],
          visible: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

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

  testWidgets('tapping debug-close invokes onClose, and visible:false hides the panel', (tester) async {
    final bus = PopmundoEventBus();
    var closeCount = 0;

    Widget harness(bool visible) {
      return MaterialApp(
        home: DebugOverlay(
          host: HostTracker(),
          events: bus,
          evaluate: (source) async => source,
          visible: visible,
          onClose: () => closeCount++,
          child: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(harness(true));
    expect(find.byKey(const Key('debug-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('debug-close')));
    await tester.pump();
    expect(closeCount, 1);

    await tester.pumpWidget(harness(false));
    await tester.pump();
    expect(find.byKey(const Key('debug-panel')), findsNothing);
  });
}
