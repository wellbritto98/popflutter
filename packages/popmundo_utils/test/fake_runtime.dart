import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';

class FakePopmundoRuntime implements PopmundoRuntime {
  FakePopmundoRuntime();

  @override
  final host = HostTracker();

  @override
  final events = PopmundoEventBus();

  final evaluateCalls = <String>[];
  String? Function(String source)? evaluateHandler;

  final fetchCalls = <({String url, Map<String, dynamic>? options})>[];
  FutureOr<InPageFetchResult> Function(String url, Map<String, dynamic>? options)?
      fetchHandler;

  final loadUrlCalls = <Uri>[];

  var ready = true;
  Duration? readyDelay;

  @override
  Future<String?> evaluate(String source) async {
    evaluateCalls.add(source);
    if (evaluateHandler != null) return evaluateHandler!(source);
    return null;
  }

  @override
  Future<InPageFetchResult> fetchInPage({
    required String url,
    Map<String, dynamic>? options,
  }) async {
    fetchCalls.add((url: url, options: options));
    if (fetchHandler != null) return await fetchHandler!(url, options);
    return const InPageFetchResult(ok: true, status: 200, text: '');
  }

  @override
  Future<void> loadUrl(Uri url) async {
    loadUrlCalls.add(url);
    host.onNavigation(url);
    events.emitNavigation(NavigationEvent(url: url.toString()));
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (readyDelay != null) {
      await Future<void>.delayed(readyDelay!);
    }
    if (!ready) {
      throw PopmundoRuntimeException('JS bridge not ready');
    }
  }
}
