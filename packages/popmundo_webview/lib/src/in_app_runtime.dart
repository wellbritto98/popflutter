import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'js_bridge.dart';
import 'userscript_injector.dart';

class InAppPopmundoRuntime implements PopmundoRuntime {
  InAppPopmundoRuntime({
    HostTracker? host,
    PopmundoEventBus? events,
  })  : host = host ?? HostTracker(),
        events = events ?? PopmundoEventBus() {
    _bridge = PopmundoJsBridge(this, onReady: _markReady);
  }

  @override
  final HostTracker host;

  @override
  final PopmundoEventBus events;

  late final PopmundoJsBridge _bridge;
  InAppWebViewController? controller;
  Completer<void> _ready = Completer<void>();

  void attach(InAppWebViewController next) {
    controller = next;
    if (_ready.isCompleted) {
      _ready = Completer<void>();
    }
    next.addJavaScriptHandler(
      handlerName: 'popmundo',
      callback: _bridge.handleArguments,
    );
  }

  /// Applies catalog enablement diff via [UserScriptInjector.sync] and reloads.
  Future<void> syncUserScripts({
    required Iterable<String> previouslyEnabledIds,
    required Iterable<InstalledUserScript> nextCatalog,
  }) async {
    final c = controller;
    if (c == null) {
      throw PopmundoRuntimeException('WebView not attached');
    }
    await UserScriptInjector.sync(
      port: InAppUserScriptWebViewPort(c),
      previouslyEnabledIds: previouslyEnabledIds,
      nextCatalog: nextCatalog,
    );
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void onNativeNavigation(Uri? url) {
    if (url == null) return;
    host.onNavigation(url);
    events.emitNavigation(NavigationEvent(url: url.toString()));
  }

  void onNativeConsole(ConsoleMessage message) {
    events.emitConsole(
      ConsoleEvent(
        level: message.messageLevel.toString(),
        message: message.message,
      ),
    );
  }

  @override
  Future<String?> evaluate(String source) async {
    final c = controller;
    if (c == null) {
      throw PopmundoRuntimeException('WebView not attached');
    }
    final result = await c.evaluateJavascript(source: source);
    if (result == null) return null;
    if (result is String) return result;
    return jsonEncode(result);
  }

  @override
  Future<InPageFetchResult> fetchInPage({
    required String url,
    Map<String, dynamic>? options,
  }) async {
    final c = controller;
    if (c == null) {
      throw PopmundoRuntimeException('WebView not attached');
    }
    final result = await c.callAsyncJavaScript(
      functionBody: '''
        const raw = await window.__popmundo.fetch(url, options || {});
        return typeof raw === 'string' ? raw : JSON.stringify(raw);
      ''',
      arguments: {
        'url': url,
        'options': options ?? <String, dynamic>{},
      },
    );
    if (result?.error != null && result!.error!.isNotEmpty) {
      throw PopmundoRuntimeException(result.error!);
    }
    final value = result?.value;
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! Map) {
      throw PopmundoRuntimeException('Unexpected fetch result');
    }
    final map = Map<String, dynamic>.from(decoded);
    final status = map['status'] is int ? map['status'] as int : int.tryParse('${map['status']}') ?? 0;
    return InPageFetchResult(
      ok: map['ok'] == true,
      status: status,
      text: '${map['text'] ?? ''}',
    );
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_ready.isCompleted) return;
    try {
      await _ready.future.timeout(timeout);
    } on TimeoutException {
      throw PopmundoRuntimeException('JS bridge not ready');
    }
  }
}
