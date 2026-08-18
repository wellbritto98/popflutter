import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}

class _FakeHistoryPort implements WebViewHistoryPort {
  _FakeHistoryPort({required this.canGoBackValue});

  final bool canGoBackValue;
  var goBackCalls = 0;

  @override
  Future<bool> canGoBack() async => canGoBackValue;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }
}

void main() {
  test('system back with history calls goBack once and does not allow exit', () async {
    final port = _FakeHistoryPort(canGoBackValue: true);

    final decision = await WebViewBackHandler.handle(port);

    expect(decision, SystemBackDecision.navigateBack);
    expect(port.goBackCalls, 1);
  });

  test('system back without history does not call goBack and allows exit', () async {
    final port = _FakeHistoryPort(canGoBackValue: false);

    final decision = await WebViewBackHandler.handle(port);

    expect(decision, SystemBackDecision.allowExit);
    expect(port.goBackCalls, 0);
  });

  test('system back with no attached WebView allows exit', () async {
    final decision = await WebViewBackHandler.handle(null);

    expect(decision, SystemBackDecision.allowExit);
  });

  test('route may pop only when the WebView has no history', () {
    expect(WebViewBackHandler.allowRoutePop(webViewCanGoBack: true), isFalse);
    expect(WebViewBackHandler.allowRoutePop(webViewCanGoBack: false), isTrue);
  });

  test('PopmundoWebView intercepts system back with PopScope', () {
    final src = _open([
      'lib/src/popmundo_webview_widget.dart',
      'packages/popmundo_webview/lib/src/popmundo_webview_widget.dart',
    ]);
    expect(src.contains('PopScope'), isTrue);
    expect(src.contains('WebViewBackHandler.allowRoutePop'), isTrue);
    expect(src.contains('WebViewBackHandler.handle'), isTrue);
  });
}
