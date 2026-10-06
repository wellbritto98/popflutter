import '../autologin/auth_http.dart';
import '../autologin/auth_http_io.dart';

class GameCredentials {
  const GameCredentials({
    required this.username,
    required this.password,
    this.status = 0,
  });
  final String username;
  final String password;
  final int status;
}

class GameActionLimits {
  const GameActionLimits({
    this.transactionTimeout = const Duration(seconds: 120),
    this.requestTimeout = const Duration(seconds: 20),
    this.maxDecodedBodyBytes = 2 * 1024 * 1024,
    this.cooldown = const Duration(milliseconds: 750),
  });
  final Duration transactionTimeout;
  final Duration requestTimeout;
  final int maxDecodedBodyBytes;
  final Duration cooldown;
}

abstract interface class GameHttpTransport {
  Future<AuthHttpResponse> send(AuthHttpRequest request);

  /// Must immediately prevent every future send and abort current IO.
  void close();
}

class IoGameHttpTransport implements GameHttpTransport {
  IoGameHttpTransport({GameActionLimits limits = const GameActionLimits()})
    : _sender = IoAuthHttpSender(
        timeout: limits.requestTimeout,
        maxDecodedBodyBytes: limits.maxDecodedBodyBytes,
      );
  final IoAuthHttpSender _sender;
  bool _closed = false;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) {
    if (_closed) throw const GameActionException('serviceUnavailable');
    return _sender.call(request);
  }

  @override
  void close() {
    _closed = true;
    _sender.close();
  }
}

class GameActionException implements Exception {
  const GameActionException(this.code);
  final String code;
  @override
  String toString() => code;
}

enum GameActionStatus { confirmed, unavailable, failed, uncertain }

class GameActionOutcome {
  const GameActionOutcome({required this.status, this.errorCode});
  final GameActionStatus status;
  final String? errorCode;
  Map<String, Object?> toJson() => {
    'status': status.name,
    'errorCode': errorCode,
  };
}
