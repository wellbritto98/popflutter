import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

void main() {
  test('waitUntilReady succeeds when fake is ready', () async {
    final runtime = FakePopmundoRuntime();
    await runtime.waitUntilReady();
  });

  test('waitUntilReady throws when not ready', () async {
    final runtime = FakePopmundoRuntime()..ready = false;
    expect(
      runtime.waitUntilReady(),
      throwsA(isA<PopmundoRuntimeException>()),
    );
  });

  test('evaluate and fetchInPage record calls', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => '1';
    runtime.fetchHandler = (url, options) =>
        InPageFetchResult(ok: true, status: 200, text: url);

    expect(await runtime.evaluate('1+1'), '1');
    final fetched = await runtime.fetchInPage(url: 'https://x', options: {'method': 'GET'});
    expect(fetched.text, 'https://x');
    expect(runtime.evaluateCalls, isNotEmpty);
    expect(runtime.fetchCalls.single.url, 'https://x');
  });
}
