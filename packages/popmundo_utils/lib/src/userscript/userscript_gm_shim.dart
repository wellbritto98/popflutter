import 'dart:convert';

import 'userscript_catalog.dart';
import 'userscript_parser.dart';

/// Builds a per-script Greasemonkey/Tampermonkey (`GM_*`/`GM.*`) JS prelude
/// for the "Core" grant set, honoring only the tokens the script actually
/// requested via `@grant`.
///
/// Every userscript runs in the same `ContentWorld.PAGE` global scope, so the
/// generated prelude opens its own closure — callers must append the
/// script's guarded body followed by `})();` to close it (see
/// `UserScriptInjector.toUserScript`).
class UserScriptGmShim {
  /// Returns null when the script requests no Core GM grant, so callers can
  /// leave `script.source` untouched (no behavior change for today's
  /// grant-less scripts).
  /// Whether [script]'s `@grant` list includes any Core GM value function
  /// (legacy `GM_getValue`/`GM_setValue`/`GM_deleteValue`/`GM_listValues` or
  /// their modern `GM.*` equivalents).
  ///
  /// Only scripts matching this need their registered native `UserScript`
  /// re-seeded with a fresh value snapshot on navigation (see
  /// `UserScriptInjector.refreshGmSnapshots`) — scripts using only
  /// `GM_addStyle`/`GM_log`/`GM_info`/`unsafeWindow` have no cache to go
  /// stale.
  static bool hasValueGrant(InstalledUserScript script) {
    final grants =
        (script.headers['grant'] ?? const <String>[]).map((g) => g.toLowerCase()).toSet();
    return grants.contains('gm_getvalue') ||
        grants.contains('gm_setvalue') ||
        grants.contains('gm_deletevalue') ||
        grants.contains('gm_listvalues') ||
        grants.contains('gm.getvalue') ||
        grants.contains('gm.setvalue') ||
        grants.contains('gm.deletevalue') ||
        grants.contains('gm.listvalues');
  }

  static String? build({
    required InstalledUserScript script,
    required Map<String, Object?> initialValues,
  }) {
    final grants =
        (script.headers['grant'] ?? const <String>[]).map((g) => g.toLowerCase()).toSet();

    final hasLegacyGet = grants.contains('gm_getvalue');
    final hasLegacySet = grants.contains('gm_setvalue');
    final hasLegacyDelete = grants.contains('gm_deletevalue');
    final hasLegacyList = grants.contains('gm_listvalues');
    final hasModernGet = grants.contains('gm.getvalue');
    final hasModernSet = grants.contains('gm.setvalue');
    final hasModernDelete = grants.contains('gm.deletevalue');
    final hasModernList = grants.contains('gm.listvalues');
    final hasAddStyle = grants.contains('gm_addstyle');
    final hasLog = grants.contains('gm_log');
    final hasLegacyInfo = grants.contains('gm_info');
    final hasModernInfo = grants.contains('gm.info');
    final hasUnsafeWindow = grants.contains('unsafewindow');

    final needsValuesCache = hasValueGrant(script);
    final needsGmNamespace =
        hasModernGet || hasModernSet || hasModernDelete || hasModernList || hasModernInfo;

    if (!needsValuesCache &&
        !hasAddStyle &&
        !hasLog &&
        !hasLegacyInfo &&
        !hasModernInfo &&
        !hasUnsafeWindow) {
      return null;
    }

    final buf = StringBuffer()
      ..writeln('(function() {')
      ..writeln("  'use strict';");

    if (needsValuesCache) {
      buf
        ..writeln('  var __gmScriptId = ${jsonEncode(script.id)};')
        ..writeln('  var __gmValues = ${jsonEncode(initialValues)};')
        ..writeln('  function __gmPost(action, key, value) {')
        ..writeln('    try {')
        ..writeln('      if (window.__popmundo && window.__popmundo.post) {')
        ..writeln('        window.__popmundo.post({')
        ..writeln("          type: 'gmValue',")
        ..writeln(
          '          payload: { scriptId: __gmScriptId, action: action, key: String(key), value: value }',
        )
        ..writeln('        });')
        ..writeln('      }')
        ..writeln('    } catch (e) {}')
        ..writeln('  }')
        ..writeln('  function __gmGetValue(key, defaultValue) {')
        ..writeln(
          '    return Object.prototype.hasOwnProperty.call(__gmValues, key) ? __gmValues[key] : defaultValue;',
        )
        ..writeln('  }')
        ..writeln('  function __gmSetValue(key, value) {')
        ..writeln('    __gmValues[key] = value;')
        ..writeln("    __gmPost('set', key, value);")
        ..writeln('  }')
        ..writeln('  function __gmDeleteValue(key) {')
        ..writeln('    delete __gmValues[key];')
        ..writeln("    __gmPost('delete', key, null);")
        ..writeln('  }')
        ..writeln('  function __gmListValues() {')
        ..writeln('    return Object.keys(__gmValues);')
        ..writeln('  }');
    }

    if (hasLegacyGet) buf.writeln('  var GM_getValue = __gmGetValue;');
    if (hasLegacySet) buf.writeln('  var GM_setValue = __gmSetValue;');
    if (hasLegacyDelete) buf.writeln('  var GM_deleteValue = __gmDeleteValue;');
    if (hasLegacyList) buf.writeln('  var GM_listValues = __gmListValues;');

    if (needsGmNamespace) {
      buf.writeln('  var GM = {};');
      if (hasModernGet) {
        buf.writeln(
          '  GM.getValue = function(key, dv) { return Promise.resolve(__gmGetValue(key, dv)); };',
        );
      }
      if (hasModernSet) {
        buf.writeln(
          '  GM.setValue = function(key, value) { return Promise.resolve(__gmSetValue(key, value)); };',
        );
      }
      if (hasModernDelete) {
        buf.writeln(
          '  GM.deleteValue = function(key) { return Promise.resolve(__gmDeleteValue(key)); };',
        );
      }
      if (hasModernList) {
        buf.writeln(
          '  GM.listValues = function() { return Promise.resolve(__gmListValues()); };',
        );
      }
    }

    if (hasAddStyle) {
      buf
        ..writeln('  var GM_addStyle = function(css) {')
        ..writeln("    var style = document.createElement('style');")
        ..writeln('    style.textContent = String(css);')
        ..writeln('    (document.head || document.documentElement).appendChild(style);')
        ..writeln('    return style;')
        ..writeln('  };');
    }

    if (hasLog) {
      buf
        ..writeln('  var GM_log = function() {')
        ..writeln('    try { console.log.apply(console, arguments); } catch (e) {}')
        ..writeln('  };');
    }

    if (hasLegacyInfo || hasModernInfo) {
      buf.writeln('  var __gmInfo = ${jsonEncode(_buildGmInfo(script))};');
      if (hasLegacyInfo) buf.writeln('  var GM_info = __gmInfo;');
      if (hasModernInfo) buf.writeln('  GM.info = __gmInfo;');
    }

    if (hasUnsafeWindow) buf.writeln('  var unsafeWindow = window;');

    return buf.toString();
  }

  static Map<String, Object?> _buildGmInfo(InstalledUserScript script) {
    final h = script.headers;
    String first(String key) {
      final list = h[key];
      if (list == null || list.isEmpty) return '';
      return list.first;
    }

    return {
      'script': {
        'name': script.name,
        'namespace': first('namespace'),
        'version': script.version ?? '',
        'description': script.description ?? '',
        'matches': h['match'] ?? const <String>[],
        'includes': h['include'] ?? const <String>[],
        'excludes': h['exclude'] ?? const <String>[],
        'run-at':
            script.runAt == UserScriptRunAt.documentStart ? 'document-start' : 'document-end',
        // @resource is unconditionally rejected at parse time — always empty.
        'resources': const <String, String>{},
        'unwrap': h.containsKey('unwrap'),
      },
      'scriptHandler': 'Popmundo',
      'version': '1.0',
      'scriptWillUpdate': false,
    };
  }
}
