import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PopmundoWebSettings {
  static InAppWebViewSettings defaults() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      incognito: false,
      cacheEnabled: true,
      useShouldOverrideUrlLoading: true,
      useShouldInterceptAjaxRequest: true,
      useShouldInterceptFetchRequest: true,
      isInspectable: true,
      mediaPlaybackRequiresUserGesture: false,
    );
  }
}
