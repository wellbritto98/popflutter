import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PopmundoUserScripts {
  static const hooksAsset = 'assets/js/hooks.js';
  static const helpersAsset = 'assets/js/helpers.js';

  static Future<String> _load(String relative) async {
    try {
      return await rootBundle.loadString('packages/popmundo_webview/$relative');
    } catch (_) {
      return rootBundle.loadString(relative);
    }
  }

  static Future<UnmodifiableListView<UserScript>> load() async {
    final hooks = await _load(hooksAsset);
    final helpers = await _load(helpersAsset);
    return UnmodifiableListView([
      UserScript(
        source: hooks,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: helpers,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
    ]);
  }
}
