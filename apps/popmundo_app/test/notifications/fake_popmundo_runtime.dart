import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';

/// Minimal [PopmundoRuntime] fake for `apps/popmundo_app` tests.
///
/// Mirrors `packages/popmundo_utils/test/fake_runtime.dart`'s shape — that
/// file lives under another package's `test/` directory and isn't part of
/// the public `popmundo_utils` API, so it can't be imported here; this is a
/// small local copy of just what this app's tests need (network events,
/// in-page fetch, and `evaluate` for `Utils.getMyName()`).
class FakePopmundoRuntime implements PopmundoRuntime {
  FakePopmundoRuntime();

  @override
  final host = HostTracker();

  @override
  final events = PopmundoEventBus();

  String? Function(String source)? evaluateHandler;
  final evaluateCalls = <String>[];

  final fetchCalls = <({String url, Map<String, dynamic>? options})>[];
  FutureOr<InPageFetchResult> Function(
    String url,
    Map<String, dynamic>? options,
  )? fetchHandler;

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
    host.onNavigation(url);
    events.emitNavigation(NavigationEvent(url: url.toString()));
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {}
}
