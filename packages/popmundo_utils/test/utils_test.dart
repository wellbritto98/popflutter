import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

void main() {
  test('getMyID returns integer from page', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => '42';
    expect(await Utils(runtime).getMyID(), 42);
  });

  test('getMyID returns 0 when missing or non-numeric', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => null;
    expect(await Utils(runtime).getMyID(), 0);
    runtime.evaluateHandler = (_) => 'abc';
    expect(await Utils(runtime).getMyID(), 0);
  });

  test('getMyName returns empty when missing', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => null;
    expect(await Utils(runtime).getMyName(), '');
    runtime.evaluateHandler = (_) => 'Ada';
    expect(await Utils(runtime).getMyName(), 'Ada');
  });

  test('getServerLink uses current host', () {
    final runtime = FakePopmundoRuntime();
    runtime.host.onNavigation(Uri.parse('https://12.popmundo.com/'));
    expect(
      Utils(runtime).getServerLink('/World/Popmundo.aspx/Character/1').toString(),
      'https://12.popmundo.com/World/Popmundo.aspx/Character/1/',
    );
  });
}
