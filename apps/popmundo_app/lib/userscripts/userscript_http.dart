import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:popmundo_utils/popmundo_utils.dart';

/// App-level HTTP GET for userscript / `@require` downloads (not TimedFetch).
Future<String> fetchUserScriptUrl(
  Uri url, {
  Duration? timeout,
}) async {
  final bytes = await fetchUserScriptBytes(url, timeout: timeout);
  return utf8.decode(bytes, allowMalformed: true);
}

/// Binary GET for `@resource` bodies (not TimedFetch).
Future<Uint8List> fetchUserScriptBytes(
  Uri url, {
  Duration? timeout,
}) async {
  final client = HttpClient();
  final effectiveTimeout = timeout ?? const Duration(seconds: 20);
  try {
    final request = await client.getUrl(url).timeout(effectiveTimeout);
    final response = await request.close().timeout(effectiveTimeout);
    final chunks = <List<int>>[];
    var total = 0;
    await for (final chunk in response.timeout(effectiveTimeout)) {
      total += chunk.length;
      if (total > GmConnectPolicy.maxResourceBytes) {
        throw UserScriptImportException(
          'Resource exceeds ${GmConnectPolicy.maxResourceBytes} bytes: $url',
        );
      }
      chunks.add(chunk);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserScriptImportException(
        'Download failed: HTTP ${response.statusCode} for $url',
      );
    }
    final builder = BytesBuilder(copy: false);
    for (final chunk in chunks) {
      builder.add(chunk);
    }
    return builder.toBytes();
  } on UserScriptImportException {
    rethrow;
  } on TimeoutException {
    throw UserScriptImportException('Download timed out: $url');
  } catch (e) {
    throw UserScriptImportException('Download failed: $url ($e)');
  } finally {
    client.close(force: true);
  }
}

/// Returns a MIME type guess from a response header or URL path.
String guessMimeType({String? contentTypeHeader, required Uri url}) {
  final header = contentTypeHeader?.split(';').first.trim();
  if (header != null && header.isNotEmpty) return header;
  final path = url.path.toLowerCase();
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.gif')) return 'image/gif';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.css')) return 'text/css';
  if (path.endsWith('.js')) return 'application/javascript';
  if (path.endsWith('.json')) return 'application/json';
  return 'application/octet-stream';
}

/// Executes a third-party GM XHR outside the WebView (no game cookies).
class GmExternalHttpClient {
  Future<GmExternalHttpResponse> send({
    required Uri url,
    required String method,
    Map<String, String> headers = const {},
    String? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      late final HttpClientRequest request;
      switch (method.toUpperCase()) {
        case 'GET':
          request = await client.getUrl(url).timeout(timeout);
        case 'POST':
          request = await client.postUrl(url).timeout(timeout);
        case 'PUT':
          request = await client.putUrl(url).timeout(timeout);
        case 'DELETE':
          request = await client.deleteUrl(url).timeout(timeout);
        case 'HEAD':
          request = await client.headUrl(url).timeout(timeout);
        case 'PATCH':
          request = await client.patchUrl(url).timeout(timeout);
        default:
          request = await client.openUrl(method.toUpperCase(), url).timeout(timeout);
      }
      headers.forEach((name, value) {
        if (name.toLowerCase() == 'cookie') return;
        request.headers.set(name, value);
      });
      if (body != null && body.isNotEmpty) {
        request.write(body);
      }
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join();
      final outHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isEmpty) return;
        outHeaders[name.toLowerCase()] = values.join(', ');
      });
      return GmExternalHttpResponse(
        status: response.statusCode,
        statusText: response.reasonPhrase,
        responseText: text,
        responseHeaders: outHeaders,
        finalUrl: url.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }
}

class GmExternalHttpResponse {
  const GmExternalHttpResponse({
    required this.status,
    required this.statusText,
    required this.responseText,
    required this.responseHeaders,
    required this.finalUrl,
  });

  final int status;
  final String statusText;
  final String responseText;
  final Map<String, String> responseHeaders;
  final String finalUrl;
}
