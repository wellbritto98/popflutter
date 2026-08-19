import 'dart:convert';

import 'gm_connect_policy.dart';
import 'userscript_catalog.dart';
import 'userscript_gm_host_bindings.dart';
import 'userscript_gm_value_bindings.dart';
import 'userscript_parser.dart';

/// Builds a per-script Greasemonkey/Tampermonkey (`GM_*`/`GM.*`) JS prelude
/// for the "Core" and "Host" grant sets, honoring only the tokens the script
/// actually requested via `@grant`.
///
/// Every userscript runs in the same `ContentWorld.PAGE` global scope, so the
/// generated prelude opens its own closure — callers must append the
/// script's guarded body followed by `})();` to close it (see
/// `UserScriptInjector.toUserScript`).
class UserScriptGmShim {
  /// Returns null when the script requests no Core/Host GM grant, so callers can
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

  static bool _needsHostHelpers(Set<String> grants) {
    return grants.contains('gm_setclipboard') ||
        grants.contains('gm.setclipboard') ||
        grants.contains('gm_openintab') ||
        grants.contains('gm.openintab') ||
        grants.contains('gm_notification') ||
        grants.contains('gm.notification') ||
        grants.contains('gm_registermenucommand') ||
        grants.contains('gm.registermenucommand') ||
        grants.contains('gm_getresourceurl') ||
        grants.contains('gm.getresourceurl') ||
        grants.contains('gm_xmlhttprequest') ||
        grants.contains('gm.xmlhttprequest');
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
    final hasLegacyAddListener = grants.contains('gm_addvaluechangelistener');
    final hasLegacyRemoveListener = grants.contains('gm_removevaluechangelistener');
    final hasModernAddListener = grants.contains('gm.addvaluechangelistener');
    final hasModernRemoveListener = grants.contains('gm.removevaluechangelistener');
    final hasAddStyle = grants.contains('gm_addstyle');
    final hasLog = grants.contains('gm_log');
    final hasLegacyInfo = grants.contains('gm_info');
    final hasModernInfo = grants.contains('gm.info');
    final hasUnsafeWindow = grants.contains('unsafewindow');

    final hasLegacySetClipboard = grants.contains('gm_setclipboard');
    final hasModernSetClipboard = grants.contains('gm.setclipboard');
    final hasLegacyOpenInTab = grants.contains('gm_openintab');
    final hasModernOpenInTab = grants.contains('gm.openintab');
    final hasLegacyNotification = grants.contains('gm_notification');
    final hasModernNotification = grants.contains('gm.notification');
    final hasLegacyMenu = grants.contains('gm_registermenucommand');
    final hasModernMenu = grants.contains('gm.registermenucommand');
    final hasModernResourceUrl = grants.contains('gm.getresourceurl');
    final hasLegacyXhr = grants.contains('gm_xmlhttprequest');
    final hasModernXhr = grants.contains('gm.xmlhttprequest');

    final needsValuesCache = hasValueGrant(script);
    final needsValueListeners = needsValuesCache ||
        hasLegacyAddListener ||
        hasLegacyRemoveListener ||
        hasModernAddListener ||
        hasModernRemoveListener;
    final needsHostHelpers = _needsHostHelpers(grants);
    final needsGmNamespace = hasModernGet ||
        hasModernSet ||
        hasModernDelete ||
        hasModernList ||
        hasModernInfo ||
        hasModernAddListener ||
        hasModernRemoveListener ||
        hasModernSetClipboard ||
        hasModernOpenInTab ||
        hasModernNotification ||
        hasModernMenu ||
        hasModernResourceUrl ||
        hasModernXhr;

    if (!needsValuesCache &&
        !needsValueListeners &&
        !needsHostHelpers &&
        !hasAddStyle &&
        !hasLog &&
        !hasLegacyInfo &&
        !hasModernInfo &&
        !hasUnsafeWindow &&
        !hasLegacySetClipboard &&
        !hasLegacyOpenInTab &&
        !hasLegacyNotification &&
        !hasLegacyMenu &&
        !hasLegacyXhr) {
      return null;
    }

    final buf = StringBuffer()
      ..writeln('(function() {')
      ..writeln("  'use strict';")
      ..writeln('  var __gmScriptId = ${jsonEncode(script.id)};');

    if (needsValuesCache || needsValueListeners) {
      buf
        ..writeln('  var __gmValues = ${jsonEncode(initialValues)};')
        ..writeln(UserScriptGmValueBindings.valueChangeListeners())
        ..writeln('  function __gmPostValue(action, key, value) {')
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
        ..writeln('    var oldVal = __gmGetValue(key, undefined);')
        ..writeln('    __gmValues[key] = value;')
        ..writeln("    __gmPostValue('set', key, value);")
        ..writeln('    __gmNotifyValueChangeListeners(key, oldVal, value, false);')
        ..writeln('  }')
        ..writeln('  function __gmDeleteValue(key) {')
        ..writeln('    var oldVal = __gmGetValue(key, undefined);')
        ..writeln('    delete __gmValues[key];')
        ..writeln("    __gmPostValue('delete', key, null);")
        ..writeln('    __gmNotifyValueChangeListeners(key, oldVal, undefined, false);')
        ..writeln('  }')
        ..writeln('  function __gmListValues() {')
        ..writeln('    return Object.keys(__gmValues);')
        ..writeln('  }');
    }

    if (needsHostHelpers) {
      buf.writeln(UserScriptGmHostBindings.sharedHelpers());
    }

    if (hasLegacyGet) buf.writeln('  var GM_getValue = __gmGetValue;');
    if (hasLegacySet) buf.writeln('  var GM_setValue = __gmSetValue;');
    if (hasLegacyDelete) buf.writeln('  var GM_deleteValue = __gmDeleteValue;');
    if (hasLegacyList) buf.writeln('  var GM_listValues = __gmListValues;');

    if (needsGmNamespace) buf.writeln('  var GM = {};');

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
    if (needsValueListeners && hasLegacyAddListener) {
      buf.writeln(UserScriptGmValueBindings.addListenerLegacy());
    }
    if (needsValueListeners && hasLegacyRemoveListener) {
      buf.writeln(UserScriptGmValueBindings.removeListenerLegacy());
    }
    if (needsValueListeners && hasModernAddListener) {
      buf.writeln(UserScriptGmValueBindings.addListenerModern());
    }
    if (needsValueListeners && hasModernRemoveListener) {
      buf.writeln(UserScriptGmValueBindings.removeListenerModern());
    }

    // Tampermonkey bundles listeners with value grants even without explicit
    // @grant lines — mirror that for legacy and modern namespaces separately.
    final hasLegacyValueGrant =
        hasLegacyGet || hasLegacySet || hasLegacyDelete || hasLegacyList;
    final hasModernValueGrant =
        hasModernGet || hasModernSet || hasModernDelete || hasModernList;
    if (needsValuesCache &&
        hasLegacyValueGrant &&
        !hasLegacyAddListener &&
        !hasLegacyRemoveListener) {
      buf
        ..writeln(UserScriptGmValueBindings.addListenerLegacy())
        ..writeln(UserScriptGmValueBindings.removeListenerLegacy());
    }
    if (needsValuesCache &&
        hasModernValueGrant &&
        !hasModernAddListener &&
        !hasModernRemoveListener) {
      buf
        ..writeln(UserScriptGmValueBindings.addListenerModern())
        ..writeln(UserScriptGmValueBindings.removeListenerModern());
    }

    if (hasLegacySetClipboard) {
      buf.writeln(UserScriptGmHostBindings.setClipboardLegacy());
    }
    if (hasModernSetClipboard) {
      buf.writeln(UserScriptGmHostBindings.setClipboardModern());
    }
    if (hasLegacyOpenInTab) {
      buf.writeln(UserScriptGmHostBindings.openInTabLegacy());
    }
    if (hasModernOpenInTab) {
      buf.writeln(UserScriptGmHostBindings.openInTabModern());
    }
    if (hasLegacyNotification) {
      buf.writeln(UserScriptGmHostBindings.notificationLegacy());
    }
    if (hasModernNotification) {
      buf.writeln(UserScriptGmHostBindings.notificationModern());
    }
    if (hasLegacyMenu) {
      buf.writeln(UserScriptGmHostBindings.registerMenuCommandLegacy());
    }
    if (hasModernMenu) {
      buf.writeln(UserScriptGmHostBindings.registerMenuCommandModern());
    }
    if (hasModernResourceUrl) {
      buf.writeln(UserScriptGmHostBindings.getResourceUrlModern());
    }
    if (hasLegacyXhr) {
      buf.writeln(UserScriptGmHostBindings.xmlHttpRequestLegacy());
    }
    if (hasModernXhr) {
      buf.writeln(UserScriptGmHostBindings.xmlHttpRequestModern());
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

    final resources = UserScriptResourceParser.parseHeaders(h['resource'] ?? const []);

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
        'resources': resources,
        'unwrap': h.containsKey('unwrap'),
      },
      'scriptHandler': 'Popmundo',
      'version': '1.0',
      'scriptWillUpdate': false,
    };
  }
}
