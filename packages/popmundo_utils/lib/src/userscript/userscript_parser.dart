/// Parsed Greasemonkey/Tampermonkey metadata + body for InAppWebView injection.
library;

enum UserScriptRunAt { documentStart, documentEnd }

class UserScriptParseException implements Exception {
  UserScriptParseException(this.message, {this.unsupportedHeaders = const []});

  final String message;
  final List<String> unsupportedHeaders;

  @override
  String toString() => 'UserScriptParseException: $message';
}

class ParsedUserScript {
  ParsedUserScript({
    required this.name,
    required this.body,
    required this.headers,
    required this.runAt,
    required this.forMainFrameOnly,
    required this.matches,
    required this.includes,
    required this.excludes,
    required this.excludeMatches,
    required this.requires,
    required this.grants,
    this.namespace,
    this.version,
    this.description,
    this.author,
  });

  final String name;
  final String body;
  final Map<String, List<String>> headers;
  final UserScriptRunAt runAt;
  final bool forMainFrameOnly;
  final List<String> matches;
  final List<String> includes;
  final List<String> excludes;
  final List<String> excludeMatches;
  final List<String> requires;
  final List<String> grants;
  final String? namespace;
  final String? version;
  final String? description;
  final String? author;

  /// Builds the JS source that will be passed to InAppWebView `UserScript.source`.
  ///
  /// [requiredSources] are already-downloaded `@require` bodies, concatenated
  /// in order before the userscript body. Match/include/exclude guards wrap
  /// the body because native `allowedOriginRules` only filters origins, not paths.
  String buildInjectableSource({required List<String> requiredSources}) {
    final preamble = requiredSources.where((s) => s.trim().isNotEmpty).join('\n');
    final guardedBody = _wrapWithUrlGuards(
      body,
      matches: matches,
      includes: includes,
      excludes: excludes,
      excludeMatches: excludeMatches,
    );
    if (preamble.isEmpty) return guardedBody;
    return '$preamble\n$guardedBody';
  }
}

class UserScriptParser {
  static final _blockRe = RegExp(
    r'//\s*==UserScript==([\s\S]*?)//\s*==/UserScript==',
    multiLine: true,
  );
  static final _headerRe = RegExp(r'^//\s*@(\S+)(?:\s+(.*))?$');

  static const _allowedGrants = {
    'none', 'unsafewindow', 'unwrap',
    // GM "Core" polyfill — legacy sync form.
    'gm_getvalue', 'gm_setvalue', 'gm_deletevalue', 'gm_listvalues',
    'gm_addvaluechangelistener', 'gm_removevaluechangelistener',
    'gm_addstyle', 'gm_log', 'gm_info',
    // GM "Core" polyfill — modern namespaced/Promise form.
    'gm.getvalue', 'gm.setvalue', 'gm.deletevalue', 'gm.listvalues', 'gm.info',
    'gm.addvaluechangelistener', 'gm.removevaluechangelistener',
    // GM "Host" polyfill — legacy form.
    'gm_getresourceurl', 'gm_notification', 'gm_openintab',
    'gm_registermenucommand', 'gm_setclipboard', 'gm_xmlhttprequest',
    // GM "Host" polyfill — modern namespaced/Promise form.
    'gm.getresourceurl', 'gm.notification', 'gm.openintab',
    'gm.registermenucommand', 'gm.setclipboard', 'gm.xmlhttprequest',
  };
  static const _allowedRunAt = {'document-start', 'document-end', 'document-idle'};

  static ParsedUserScript parse(String raw) {
    final blockMatch = _blockRe.firstMatch(raw);
    if (blockMatch == null) {
      throw UserScriptParseException(
        'Missing // ==UserScript== … // ==/UserScript== metadata block',
      );
    }

    final headerBlock = blockMatch.group(1)!;
    final body = raw.substring(blockMatch.end).trimLeft();
    final headers = <String, List<String>>{};
    final unsupported = <String>[];

    for (final line in headerBlock.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final hm = _headerRe.firstMatch(trimmed);
      if (hm == null) continue;
      final key = hm.group(1)!.toLowerCase();
      final value = (hm.group(2) ?? '').trim();
      headers.putIfAbsent(key, () => []).add(value);
    }

    final names = headers['name'];
    if (names == null || names.isEmpty || names.first.trim().isEmpty) {
      throw UserScriptParseException('Missing required @name header');
    }

    for (final grant in headers['grant'] ?? const <String>[]) {
      if (!_allowedGrants.contains(grant.toLowerCase())) {
        unsupported.add('@grant $grant');
      }
    }

    final runAtValues = headers['run-at'] ?? const <String>[];
    for (final v in runAtValues) {
      if (!_allowedRunAt.contains(v.toLowerCase())) {
        unsupported.add('@run-at $v');
      }
    }

    for (final v in headers['sandbox'] ?? const <String>[]) {
      // Only "page"-equivalent worlds are acceptable; Tampermonkey "raw" etc. rejected.
      final lower = v.toLowerCase();
      if (lower.isNotEmpty && lower != 'page' && lower != 'dom') {
        unsupported.add('@sandbox $v');
      }
    }
    for (final v in headers['inject-into'] ?? const <String>[]) {
      final lower = v.toLowerCase();
      if (lower.isNotEmpty &&
          lower != 'page' &&
          lower != 'content' &&
          lower != 'auto') {
        unsupported.add('@inject-into $v');
      }
    }

    // Unknown @keys that are not in the honor matrix and not handled above:
    // treat as unsupported only if they are known-dangerous; otherwise ignore
    // unknown meta. Spec lists honored + rejected; anything else that is not
    // in either set is ignored as metadata (safe default per agent discretion
    // for obscure headers). Icon* already covered via prefix check below.

    if (unsupported.isNotEmpty) {
      final unique = unsupported.toSet().toList()..sort();
      throw UserScriptParseException(
        'Unsupported headers: ${unique.join(', ')}',
        unsupportedHeaders: unique,
      );
    }

    UserScriptRunAt runAt = UserScriptRunAt.documentEnd;
    if (runAtValues.isNotEmpty) {
      final v = runAtValues.last.toLowerCase();
      if (v == 'document-start') {
        runAt = UserScriptRunAt.documentStart;
      } else {
        runAt = UserScriptRunAt.documentEnd;
      }
    }

    final forMainFrameOnly = headers.containsKey('noframes');

    // Strip body-affecting / meta into structured fields; keep full headers map.
    final filteredHeaders = Map<String, List<String>>.from(headers);

    return ParsedUserScript(
      name: names.first.trim(),
      body: body,
      headers: filteredHeaders,
      runAt: runAt,
      forMainFrameOnly: forMainFrameOnly,
      matches: List.unmodifiable(headers['match'] ?? const []),
      includes: List.unmodifiable(headers['include'] ?? const []),
      excludes: List.unmodifiable(headers['exclude'] ?? const []),
      excludeMatches: List.unmodifiable(headers['exclude-match'] ?? const []),
      requires: List.unmodifiable(headers['require'] ?? const []),
      grants: List.unmodifiable(headers['grant'] ?? const []),
      namespace: _first(headers, 'namespace'),
      version: _first(headers, 'version'),
      description: _first(headers, 'description'),
      author: _first(headers, 'author'),
    );
  }

  static String? _first(Map<String, List<String>> headers, String key) {
    final list = headers[key];
    if (list == null || list.isEmpty) return null;
    final v = list.first.trim();
    return v.isEmpty ? null : v;
  }
}

String _wrapWithUrlGuards(
  String body, {
  required List<String> matches,
  required List<String> includes,
  required List<String> excludes,
  required List<String> excludeMatches,
}) {
  final hasIncludeRules = matches.isNotEmpty || includes.isNotEmpty;
  final hasExcludeRules = excludes.isNotEmpty || excludeMatches.isNotEmpty;
  if (!hasIncludeRules && !hasExcludeRules) {
    return body;
  }

  String lit(String s) =>
      "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  final matchLits = [...matches, ...includes].map(lit).join(', ');
  final excludeLits = [...excludes, ...excludeMatches].map(lit).join(', ');

  return '''
(function() {
  var href = String(location.href);
  function usmGlobToRegExp(pattern) {
    if (pattern.length >= 2 && pattern.charAt(0) === '/' && pattern.charAt(pattern.length - 1) === '/') {
      try { return new RegExp(pattern.slice(1, -1)); } catch (e) { return null; }
    }
    var escaped = pattern.replace(/[.+^\\\${}()|[\\]\\\\]/g, '\\\\\$&');
    escaped = escaped.replace(/\\*/g, '.*').replace(/\\?/g, '.');
    try { return new RegExp('^' + escaped + '\$'); } catch (e) { return null; }
  }
  function usmMatchesAny(patterns) {
    for (var i = 0; i < patterns.length; i++) {
      var re = usmGlobToRegExp(patterns[i]);
      if (re && re.test(href)) return true;
    }
    return false;
  }
  var includePatterns = [$matchLits];
  var excludePatterns = [$excludeLits];
  if (includePatterns.length > 0 && !usmMatchesAny(includePatterns)) return;
  if (excludePatterns.length > 0 && usmMatchesAny(excludePatterns)) return;
$body
})();
''';
}
