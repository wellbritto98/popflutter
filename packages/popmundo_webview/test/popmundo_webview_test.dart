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
    expect(helpers.contains('getMyID'), isTrue);
    expect(helpers.contains('applyScoringNumbers();'), isFalse);
    expect(helpers.contains('applyBarPercentage();'), isFalse);
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

  test('initial URL default is www.popmundo.com', () {
    expect(HostTracker.defaultOrigin, 'https://www.popmundo.com');
  });
}
