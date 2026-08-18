import 'dart:async';

import 'popmundo_runtime.dart';

typedef ClockNow = DateTime Function();
typedef Sleeper = Future<void> Function(Duration duration);

class TimedFetchException implements Exception {
  TimedFetchException(this.message);
  final String message;

  @override
  String toString() => 'TimedFetchException: $message';
}

/// Serial in-page fetch with cooldown and per-process cache.
class TimedFetch {
  TimedFetch(
    this.runtime, {
    this.delay = const Duration(milliseconds: 750),
    ClockNow? now,
    Sleeper? sleep,
  })  : _now = now ?? DateTime.now,
        _sleep = sleep ?? Future<void>.delayed {
    _lastCall = _now().subtract(delay);
  }

  final PopmundoRuntime runtime;
  final Duration delay;
  final ClockNow _now;
  final Sleeper _sleep;

  final Map<String, String> _cache = {};
  Future<void> _queue = Future.value();
  late DateTime _lastCall;

  Future<String> fetch(
    String resource, {
    Map<String, dynamic> options = const {},
    bool useCache = true,
  }) async {
    final method = (options['method'] as String? ?? 'GET').toUpperCase();
    final url = _absoluteUrl(resource);
    final cacheKey = '$method:$url';

    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    try {
      await previous;
      while (_now().difference(_lastCall) < delay) {
        final remaining = delay - _now().difference(_lastCall);
        final waitMs = remaining.inMilliseconds < 50 ? 50 : remaining.inMilliseconds;
        await _sleep(Duration(milliseconds: waitMs));
      }
      await runtime.waitUntilReady();
      final result = await runtime.fetchInPage(url: url, options: options);
      if (!result.ok || result.status < 200 || result.status >= 300) {
        throw TimedFetchException('Bad response status: ${result.status}');
      }
      if (useCache) {
        _cache[cacheKey] = result.text;
      }
      return result.text;
    } finally {
      _lastCall = _now();
      done.complete();
    }
  }

  String _absoluteUrl(String resource) {
    final parsed = Uri.parse(resource);
    if (parsed.hasScheme) return resource;
    final origin = runtime.host.currentOrigin;
    final path = resource.startsWith('/') ? resource : '/$resource';
    return origin.replace(path: path, query: parsed.hasQuery ? parsed.query : null).toString();
  }
}
