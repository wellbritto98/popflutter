import 'userscript_catalog.dart';
import 'userscript_parser.dart';

typedef UserScriptHttpGet = Future<String> Function(
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
    this.timeout = const Duration(seconds: 20),
    this.idGenerator,
    this.now,
  });

  final UserScriptCatalog catalog;
  final UserScriptHttpGet httpGet;
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

    final source = parsed.buildInjectableSource(requiredSources: requiredSources);
    final script = InstalledUserScript(
      id: idGenerator?.call() ?? _defaultId(uri),
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
      return await catalog.add(script);
    } on UserScriptCatalogException catch (e) {
      throw UserScriptImportException(e.message);
    }
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
