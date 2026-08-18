import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('streams deliver emitted events', () async {
    final bus = PopmundoEventBus();
    final networks = <NetworkEvent>[];
    final consoles = <ConsoleEvent>[];
    final navs = <NavigationEvent>[];
    bus.network.listen(networks.add);
    bus.console.listen(consoles.add);
    bus.navigation.listen(navs.add);

    bus.emitNetwork(NetworkEvent(method: 'GET', url: 'https://www.popmundo.com/a'));
    bus.emitConsole(ConsoleEvent(level: 'log', message: 'hi'));
    bus.emitNavigation(NavigationEvent(url: 'https://www.popmundo.com/'));
    await Future<void>.delayed(Duration.zero);

    expect(networks.single.method, 'GET');
    expect(consoles.single.message, 'hi');
    expect(navs.single.url, 'https://www.popmundo.com/');
    await bus.dispose();
  });

  test('truncates text bodies over 32768 bytes', () {
    final big = 'a' * 40000;
    final result = BodyCapture.capture(big);
    expect(result.truncated, isTrue);
    expect(result.omitted, isFalse);
    expect(result.body!.length, lessThan(big.length));
  });

  test('omits binary bodies', () {
    final result = BodyCapture.capture('xyz', binary: true);
    expect(result.body, isNull);
    expect(result.omitted, isTrue);
    expect(result.truncated, isFalse);
  });

  test('keeps small text bodies intact', () {
    final result = BodyCapture.capture('ok');
    expect(result.body, 'ok');
    expect(result.truncated, isFalse);
    expect(result.omitted, isFalse);
  });
}
