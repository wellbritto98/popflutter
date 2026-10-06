import 'dart:async';
import 'dart:convert';

import '../autologin/auth_http.dart';
import 'game_action_contracts.dart';
import 'game_notification_signals.dart';

/// Owns one private transport. Cancellation closes it before race completion.
class GameTransaction {
  GameTransaction({
    required this.transport,
    required this.limits,
    required this.now,
    required this.sleep,
    required this.onRequestFinished,
    DateTime? lastFinished,
  }) {
    _lastFinished = lastFinished ?? now().subtract(limits.cooldown);
    _deadline = Timer(
      limits.transactionTimeout,
      () => cancel('transactionTimeout'),
    );
    session = AuthSession(
      send: _send,
      userAgent: userAgent,
      delay: Duration.zero,
      now: now,
      sleep: sleep,
    );
  }
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36';
  final GameHttpTransport transport;
  final GameActionLimits limits;
  final DateTime Function() now;
  final Future<void> Function(Duration) sleep;
  final void Function(DateTime) onRequestFinished;
  late final AuthSession session;
  late final Timer _deadline;
  late DateTime _lastFinished;
  final _cancelled = Completer<String>();
  bool closed = false;
  bool gameplaySent = false;
  Uri? gameplayUrl;
  String? _cancelCode;
  void check() {
    if (closed) throw GameActionException(_cancelCode ?? 'serviceUnavailable');
  }

  void cancel(String code) {
    if (closed) return;
    closed = true;
    _cancelCode = code;
    _deadline.cancel();
    transport.close();
    _cancelled.complete(code);
  }

  void close() => cancel('serviceUnavailable');
  Future<T> wait<T>(Future<T> work) => Future.any<T>([
    work,
    _cancelled.future.then<T>((code) => throw GameActionException(code)),
  ]);
  static void validateUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        !(host == 'popmundo.com' || host.endsWith('.popmundo.com'))) {
      throw const GameActionException('unsafeTarget');
    }
  }

  Future<AuthHttpResponse> _send(AuthHttpRequest request) async {
    check();
    validateUrl(request.url);
    final remaining = limits.cooldown - now().difference(_lastFinished);
    if (remaining > Duration.zero) await wait(sleep(remaining));
    check();
    final timer = Timer(limits.requestTimeout, () => cancel('requestTimeout'));
    try {
      if (request.method == 'POST' && request.url == gameplayUrl) {
        if (gameplaySent) throw const GameActionException('duplicateAction');
        gameplaySent = true;
      }
      final response = await wait(transport.send(request));
      check();
      if (utf8.encode(response.body).length > limits.maxDecodedBodyBytes) {
        cancel('responseTooLarge');
        throw const GameActionException('responseTooLarge');
      }
      return response;
    } on GameActionException {
      rethrow;
    } catch (error) {
      if (error is AuthHttpException &&
          error.message == 'Response exceeds decoded body limit') {
        throw const GameActionException('responseTooLarge');
      }
      throw const GameActionException('networkError');
    } finally {
      _lastFinished = now();
      onRequestFinished(_lastFinished);
      timer.cancel();
    }
  }

  Future<GameNotificationSignals> _notifications(Uri origin) async {
    final url = origin.replace(
      path: '/WebServices/A/Open.asmx/GetPageNotifications',
    );
    final response = await session.postJson(
      url,
      jsonEncode({'ts': '${now().millisecondsSinceEpoch}'}),
    );
    if (response.status != 200 || response.finalUrl != url) {
      throw const GameActionException('preflightUnavailable');
    }
    return GameNotificationSignals.parse(response.body);
  }

  Future<void> establishNeutralBaseline(Uri origin) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final signals = await _notifications(origin);
      if (!signals.valid) {
        throw const GameActionException('preflightUnavailable');
      }
      if (signals.isNeutral) return;
    }
    throw const GameActionException('preflightUnavailable');
  }

  Future<GameActionOutcome> readOutcome(Uri origin) async {
    try {
      return (await _notifications(origin)).outcome;
    } catch (_) {
      return const GameActionOutcome(
        status: GameActionStatus.uncertain,
        errorCode: 'outcomeUncertain',
      );
    }
  }
}
