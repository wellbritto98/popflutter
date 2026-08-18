import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Narrow port over WebView history so system-back can be unit-tested.
abstract class WebViewHistoryPort {
  Future<bool> canGoBack();
  Future<void> goBack();
}

class InAppWebViewHistoryPort implements WebViewHistoryPort {
  InAppWebViewHistoryPort(this.controller);

  final InAppWebViewController controller;

  @override
  Future<bool> canGoBack() => controller.canGoBack();

  @override
  Future<void> goBack() => controller.goBack();
}

enum SystemBackDecision { navigateBack, allowExit }

class WebViewBackHandler {
  /// Predictive-back: the Flutter route may pop only when WebView history is empty.
  static bool allowRoutePop({required bool webViewCanGoBack}) => !webViewCanGoBack;

  static Future<SystemBackDecision> handle(WebViewHistoryPort? port) async {
    if (port == null) return SystemBackDecision.allowExit;
    if (await port.canGoBack()) {
      await port.goBack();
      return SystemBackDecision.navigateBack;
    }
    return SystemBackDecision.allowExit;
  }
}
