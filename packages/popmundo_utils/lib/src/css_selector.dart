import 'dart:convert';

import 'popmundo_runtime.dart';

class CssSelectorHelper {
  CssSelectorHelper(this.runtime, this.selector);

  final PopmundoRuntime runtime;
  final String selector;

  Future<Map<String, dynamic>?> getSingle() async {
    final raw = await runtime.evaluate(
      'window.__popmundo.querySingle(${jsonEncode(selector)})',
    );
    return _decodeNode(raw);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final raw = await runtime.evaluate(
      'window.__popmundo.queryAll(${jsonEncode(selector)})',
    );
    if (raw == null || raw == 'null' || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _decodeNode(String? raw) {
    if (raw == null || raw == 'null' || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}

class XPathHelper {
  XPathHelper(this.runtime, this.expression);

  final PopmundoRuntime runtime;
  final String expression;

  Future<Map<String, dynamic>?> getSingle() async {
    final raw = await runtime.evaluate(
      'window.__popmundo.xpathSingle(${jsonEncode(expression)})',
    );
    if (raw == null || raw == 'null' || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}
