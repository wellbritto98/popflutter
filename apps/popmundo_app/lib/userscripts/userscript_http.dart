import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:popmundo_utils/popmundo_utils.dart';

/// App-level HTTP GET for userscript / `@require` downloads (not TimedFetch).
Future<String> fetchUserScriptUrl(
  Uri url, {
  Duration? timeout,
}) async {
  final client = HttpClient();
  final effectiveTimeout = timeout ?? const Duration(seconds: 20);
  try {
    final request = await client.getUrl(url).timeout(effectiveTimeout);
    final response = await request.close().timeout(effectiveTimeout);
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserScriptImportException(
        'Download failed: HTTP ${response.statusCode} for $url',
      );
    }
    return body;
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
