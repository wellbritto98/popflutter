import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}

class _Runtime implements PopmundoRuntime {
  @override
  final host = HostTracker();
  @override
  final events = PopmundoEventBus();

  @override
  Future<String?> evaluate(String source) async => null;

  @override
  Future<InPageFetchResult> fetchInPage({
    required String url,
    Map<String, dynamic>? options,
  }) async =>
      const InPageFetchResult(ok: true, status: 200, text: '');

  @override
  Future<void> loadUrl(Uri url) async {}

  @override
  Future<void> waitUntilReady({Duration timeout = const Duration(seconds: 30)}) async {}
}

void main() {
  test('settings are non-incognito and enable intercept listeners', () {
    final settings = PopmundoWebSettings.defaults();
    expect(settings.incognito, isFalse);
    expect(settings.cacheEnabled, isTrue);
    expect(settings.javaScriptEnabled, isTrue);
    expect(settings.useShouldOverrideUrlLoading, isTrue);
    expect(settings.useShouldInterceptFetchRequest, isTrue);
    expect(settings.useShouldInterceptAjaxRequest, isTrue);
  });

  test('observe-only resource intercept returns null', () {
    expect(ObservePolicy.observeOnlyResourceResponse(), isNull);
  });

  test('JS hooks wrap fetch/xhr/console and helpers do not auto-run scoring', () {
    final hooks = _open(['assets/js/hooks.js', 'packages/popmundo_webview/assets/js/hooks.js']);
    final helpers = _open(['assets/js/helpers.js', 'packages/popmundo_webview/assets/js/helpers.js']);
    expect(hooks.contains('window.fetch'), isTrue);
    expect(hooks.contains('XMLHttpRequest'), isTrue);
    expect(hooks.contains("type: 'console'"), isTrue);
    expect(hooks.contains('flutterInAppWebViewPlatformReady'), isTrue);
    expect(hooks.contains('window.__popmundo.post = post;'), isTrue);
    expect(helpers.contains('getMyID'), isTrue);
    expect(helpers.contains('applyScoringNumbers();'), isFalse);
    expect(helpers.contains('applyBarPercentage();'), isFalse);
  });

  test('JS __popmundo.fetch passes options and exposes Location header', () {
    final hooks = _open(['assets/js/hooks.js', 'packages/popmundo_webview/assets/js/hooks.js']);
    expect(hooks.contains('originalFetch(url, options || {})'), isTrue);
    expect(hooks.contains("res.headers.get('Location')"), isTrue);
    expect(hooks.contains("res.headers.get('location')"), isTrue);
    expect(hooks.contains('headers.location'), isTrue);
    expect(hooks.contains('url: res.url'), isTrue);
  });

  test('inPageFetchResultFromJsMap normalizes headers and url', () {
    final result = inPageFetchResultFromJsMap({
      'ok': false,
      'status': 302,
      'text': '',
      'headers': {'Location': '/Login.aspx?t=abc', 'X-Unused': null},
      'url': 'https://73.popmundo.com/Login.aspx',
    });
    expect(result.ok, isFalse);
    expect(result.status, 302);
    expect(result.headers['location'], '/Login.aspx?t=abc');
    expect(result.headers.containsKey('x-unused'), isFalse);
    expect(result.locationHeader, '/Login.aspx?t=abc');
    expect(result.url, 'https://73.popmundo.com/Login.aspx');
  });

  test('loadUrl throws when WebView is not attached', () async {
    final runtime = InAppPopmundoRuntime();
    expect(
      () => runtime.loadUrl(Uri.parse('https://www.popmundo.com/')),
      throwsA(
        isA<PopmundoRuntimeException>().having(
          (e) => e.message,
          'message',
          'WebView not attached',
        ),
      ),
    );
  });

  test('JS bridge emits network and console events', () async {
    final runtime = _Runtime();
    final networks = <NetworkEvent>[];
    final consoles = <ConsoleEvent>[];
    runtime.events.network.listen(networks.add);
    runtime.events.console.listen(consoles.add);

    final bridge = PopmundoJsBridge(runtime);
    bridge.handleArguments([
      {
        'type': 'network',
        'payload': {
          'method': 'POST',
          'url': 'https://73.popmundo.com/x',
          'status': 200,
          'source': 'fetch',
          'body': 'ok',
          'bodyTruncated': false,
          'bodyOmitted': false,
        },
      },
    ]);
    bridge.handleArguments([
      {
        'type': 'console',
        'payload': {'level': 'error', 'message': 'boom'},
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(networks.single.method, 'POST');
    expect(networks.single.url, contains('73.popmundo.com'));
    expect(consoles.single.message, 'boom');
  });

  test('JS bridge emits gmValue events for set and delete', () async {
    final runtime = _Runtime();
    final events = <GmValueEvent>[];
    runtime.events.gmValue.listen(events.add);

    final bridge = PopmundoJsBridge(runtime);
    bridge.handleArguments([
      {
        'type': 'gmValue',
        'payload': {'scriptId': 'abc', 'action': 'set', 'key': 'count', 'value': 3},
      },
    ]);
    bridge.handleArguments([
      {
        'type': 'gmValue',
        'payload': {'scriptId': 'abc', 'action': 'delete', 'key': 'count', 'value': null},
      },
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0].action, 'set');
    expect(events[0].value, 3);
    expect(events[1].action, 'delete');
    expect(events[1].value, isNull);
  });

  test('initial URL default is www.popmundo.com', () {
    expect(HostTracker.defaultOrigin, 'https://www.popmundo.com');
  });
}
