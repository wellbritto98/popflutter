import 'dart:convert';
import 'dart:io';

import 'auth_http.dart';

/// Real transport for [AuthSession], on `dart:io`.
///
/// `dart:io` is confined to this file so the rest of the auto-login code stays
/// platform-free and unit-testable with a fake [AuthHttpSend].
///
/// Redirect following is disabled on purpose: [AuthSession] walks the chain
/// itself so it can read every hop's `Set-Cookie`.
class IoAuthHttpSender {
  IoAuthHttpSender({
    HttpClient? client,
    this.timeout = const Duration(seconds: 20),
    this.maxDecodedBodyBytes,
  }) : _client = client ?? (HttpClient()..userAgent = null);

  final HttpClient _client;
  final Duration timeout;
  final int? maxDecodedBodyBytes;

  Future<AuthHttpResponse> call(AuthHttpRequest req) async {
    try {
      final request = await _client
          .openUrl(req.method, req.url)
          .timeout(timeout);
      request.followRedirects = false;
      // The session owns the jar; dart:io must not add its own Cookie header.
      request.cookies.clear();
      req.headers.forEach(request.headers.set);

      final body = req.body;
      if (body != null) {
        final bytes = utf8.encode(body);
        request.headers.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close().timeout(timeout);
      final text = await _readBody(response).timeout(timeout);

      return AuthHttpResponse(
        status: response.statusCode,
        body: text,
        setCookieHeaders:
            response.headers[HttpHeaders.setCookieHeader] ?? const [],
        location: response.headers.value(HttpHeaders.locationHeader),
      );
    } on AuthHttpException {
      rethrow;
    } catch (e) {
      throw AuthHttpException('${req.method} ${req.url} failed: $e');
    }
  }

  Future<String> _readBody(HttpClientResponse response) async {
    final decoded = StringBuffer();
    var decodedBytes = 0;
    await for (final chunk in response.transform(
      const Utf8Decoder(allowMalformed: true),
    )) {
      decodedBytes += utf8.encode(chunk).length;
      if (maxDecodedBodyBytes != null && decodedBytes > maxDecodedBodyBytes!) {
        close();
        throw AuthHttpException('Response exceeds decoded body limit');
      }
      decoded.write(chunk);
    }
    return decoded.toString();
  }

  void close() => _client.close(force: true);
}
