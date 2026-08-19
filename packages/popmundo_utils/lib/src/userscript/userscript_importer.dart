import 'userscript_catalog.dart';
import 'userscript_parser.dart';
import 'gm_connect_policy.dart';
import 'gm_resource_store.dart';

typedef UserScriptHttpGet = Future<String> Function(
  Uri url, {
  Duration? timeout,
});

typedef UserScriptHttpGetBytes = Future<List<int>> Function(
  Uri url, {
  Duration? timeout,
});

class UserScriptImportException implements Exception {
  UserScriptImportException(this.message);
  final String message;

  @override
  String toString() => 'UserScriptImportException: $message';
}

class UserScriptImporter {
  UserScriptImporter({
    required this.catalog,
    required this.httpGet,
    this.httpGetBytes,
    this.resourceStore,
    this.timeout = const Duration(seconds: 20),
    this.idGenerator,
    this.now,
  });

  final UserScriptCatalog catalog;
  final UserScriptHttpGet httpGet;
  final UserScriptHttpGetBytes? httpGetBytes;
  final GmResourceStore? resourceStore;
  final Duration timeout;
  final String Function()? idGenerator;
  final DateTime Function()? now;

  Future<InstalledUserScript> importFromUrl(String rawUrl) async {
    final uri = _validateUrl(rawUrl);
    late final String raw;
    try {
      raw = await httpGet(uri, timeout: timeout);
    } on UserScriptImportException {
      rethrow;
    } catch (e) {
      throw UserScriptImportException('Download failed: $uri ($e)');
    }
    if (raw.trim().isEmpty) {
      throw UserScriptImportException('Downloaded userscript is empty');
    }

    late final ParsedUserScript parsed;
    try {
      parsed = UserScriptParser.parse(raw);
    } on UserScriptParseException catch (e) {
      throw UserScriptImportException(e.message);
    }

    final requiredSources = <String>[];
    for (final requireUrl in parsed.requires) {
      final requireUri = Uri.tryParse(requireUrl);
      if (requireUri == null ||
          (requireUri.scheme != 'http' && requireUri.scheme != 'https')) {
        throw UserScriptImportException('Invalid @require URL: $requireUrl');
      }
      try {
        requiredSources.add(await httpGet(requireUri, timeout: timeout));
      } on UserScriptImportException {
        rethrow;
      } catch (e) {
        throw UserScriptImportException(
          'Download failed for @require $requireUrl ($e)',
        );
      }
    }

    final scriptId = idGenerator?.call() ?? _defaultId(uri);
    final resourceEntries = await _downloadResources(parsed.headers, scriptId);

    final source = parsed.buildInjectableSource(requiredSources: requiredSources);
    final script = InstalledUserScript(
      id: scriptId,
      sourceUrl: uri.toString(),
      name: parsed.name,
      version: parsed.version,
      description: parsed.description,
      enabled: true,
      source: source,
      headers: parsed.headers,
      installedAt: now?.call() ?? DateTime.now().toUtc(),
      runAt: parsed.runAt,
      forMainFrameOnly: parsed.forMainFrameOnly,
    );

    try {
      final added = await catalog.add(script);
      if (resourceStore != null && resourceEntries.isNotEmpty) {
        await resourceStore!.setAll(scriptId, resourceEntries);
      }
      return added;
    } on UserScriptCatalogException catch (e) {
      throw UserScriptImportException(e.message);
    }
  }

  Future<Map<String, GmResourceEntry>> _downloadResources(
    Map<String, List<String>> headers,
    String scriptId,
  ) async {
    final fetchBytes = httpGetBytes;
    final store = resourceStore;
    if (fetchBytes == null || store == null) return {};

    final specs = UserScriptResourceParser.parseHeaders(headers['resource'] ?? const []);
    if (specs.isEmpty) return {};

    final result = <String, GmResourceEntry>{};
    for (final entry in specs.entries) {
      final resourceUri = Uri.tryParse(entry.value);
      if (resourceUri == null ||
          (resourceUri.scheme != 'http' && resourceUri.scheme != 'https')) {
        throw UserScriptImportException('Invalid @resource URL: ${entry.value}');
      }
      try {
        final bytes = await fetchBytes(resourceUri, timeout: timeout);
        if (bytes.length > GmConnectPolicy.maxResourceBytes) {
          throw UserScriptImportException(
            'Resource "${entry.key}" exceeds ${GmConnectPolicy.maxResourceBytes} bytes',
          );
        }
        result[entry.key] = GmResourceEntry(
          mimeType: 'application/octet-stream',
          base64: GmResourceStore.encodeBytes(bytes),
        );
      } on UserScriptImportException {
        rethrow;
      } catch (e) {
        throw UserScriptImportException(
          'Download failed for @resource ${entry.key} (${entry.value}): $e',
        );
      }
    }
    return result;
  }

  Uri _validateUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw UserScriptImportException('Invalid URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw UserScriptImportException('URL must be http or https');
    }
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.user.js')) {
      throw UserScriptImportException('URL path must end with .user.js');
    }
    return uri;
  }

  String _defaultId(Uri uri) {
    final stamp = (now?.call() ?? DateTime.now().toUtc())
        .microsecondsSinceEpoch
        .toRadixString(16);
    final hash = uri.toString().hashCode.toRadixString(16);
    return 'us_$stamp$hash';
  }
}
