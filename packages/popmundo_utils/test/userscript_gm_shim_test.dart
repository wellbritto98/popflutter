import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

InstalledUserScript _script({
  String id = 'abc',
  List<String> grants = const [],
  Map<String, List<String>> extraHeaders = const {},
  String? version,
  String? description,
}) {
  return InstalledUserScript(
    id: id,
    sourceUrl: 'https://example.com/$id.user.js',
    name: 'Test Script',
    version: version,
    description: description,
    enabled: true,
    source: '1;',
    headers: {
      'name': ['Test Script'],
      if (grants.isNotEmpty) 'grant': grants,
      ...extraHeaders,
    },
    installedAt: DateTime.utc(2026, 8, 17),
    runAt: UserScriptRunAt.documentEnd,
    forMainFrameOnly: false,
  );
}

void main() {
  group('UserScriptGmShim', () {
    test('hasValueGrant is true for any legacy or modern value grant', () {
      expect(UserScriptGmShim.hasValueGrant(_script(grants: ['GM_getValue'])), isTrue);
      expect(UserScriptGmShim.hasValueGrant(_script(grants: ['GM.setValue'])), isTrue);
      expect(UserScriptGmShim.hasValueGrant(_script(grants: ['GM_addStyle'])), isFalse);
      expect(UserScriptGmShim.hasValueGrant(_script(grants: ['GM_info'])), isFalse);
      expect(UserScriptGmShim.hasValueGrant(_script()), isFalse);
    });

    test('returns null when no grant is present', () {
      expect(UserScriptGmShim.build(script: _script(), initialValues: const {}), isNull);
    });

    test('returns null for @grant none', () {
      expect(
        UserScriptGmShim.build(script: _script(grants: ['none']), initialValues: const {}),
        isNull,
      );
    });

    test('GM_getValue-only shim exposes exactly that binding', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_getValue']),
        initialValues: {'x': 1},
      );
      expect(shim, isNotNull);
      expect(shim, contains('var GM_getValue = __gmGetValue;'));
      expect(shim, isNot(contains('GM_setValue')));
      expect(shim, isNot(contains('GM_deleteValue')));
      expect(shim, isNot(contains('GM_listValues')));
      expect(shim, isNot(contains('GM_addStyle')));
      expect(shim, isNot(contains('GM_log')));
      expect(shim, isNot(contains('unsafeWindow')));
    });

    test('__gmValues literal round-trips the initial values map', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_getValue', 'GM_setValue']),
        initialValues: {'count': 3, 'label': 'hi'},
      );
      final match = RegExp(r'var __gmValues = (\{.*?\});').firstMatch(shim!);
      expect(match, isNotNull);
      expect(jsonDecode(match!.group(1)!), {'count': 3, 'label': 'hi'});
    });

    test('modern GM.* grants build a GM namespace delegating to sync impls', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM.setValue', 'GM.getValue']),
        initialValues: const {},
      );
      expect(shim, contains('var GM = {};'));
      expect(shim, contains('GM.getValue = function'));
      expect(shim, contains('GM.setValue = function'));
      expect(shim, isNot(contains('var GM_getValue')));
      expect(shim, isNot(contains('var GM_setValue')));
    });

    test('GM_addStyle and GM_log are emitted independently of value grants', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_addStyle', 'GM_log']),
        initialValues: const {},
      );
      expect(shim, contains('var GM_addStyle = function(css)'));
      expect(shim, contains('var GM_log = function()'));
      expect(shim, isNot(contains('__gmValues')));
    });

    test('unsafeWindow alone activates the shim', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['unsafeWindow']),
        initialValues: const {},
      );
      expect(shim, isNotNull);
      expect(shim, contains('var unsafeWindow = window;'));
    });

    test('GM_info reflects script metadata with empty resources', () {
      final shim = UserScriptGmShim.build(
        script: _script(
          grants: ['GM_info'],
          version: '2.1',
          description: 'desc',
          extraHeaders: {
            'match': ['https://www.popmundo.com/*'],
          },
        ),
        initialValues: const {},
      );
      final match = RegExp(r'var __gmInfo = (\{.*?\});').firstMatch(shim!);
      final info = jsonDecode(match!.group(1)!) as Map<String, dynamic>;
      final script = info['script'] as Map<String, dynamic>;
      expect(script['name'], 'Test Script');
      expect(script['version'], '2.1');
      expect(script['description'], 'desc');
      expect(script['matches'], ['https://www.popmundo.com/*']);
      expect(script['resources'], isEmpty);
      expect(shim, contains('var GM_info = __gmInfo;'));
    });

    test('GM_info reflects @resource URLs in script.resources', () {
      final shim = UserScriptGmShim.build(
        script: _script(
          grants: ['GM_info'],
          extraHeaders: {
            'resource': ['icon https://example.com/i.png'],
          },
        ),
        initialValues: const {},
      );
      final match = RegExp(r'var __gmInfo = (\{.*?\});').firstMatch(shim!);
      final info = jsonDecode(match!.group(1)!) as Map<String, dynamic>;
      final script = info['script'] as Map<String, dynamic>;
      expect(script['resources'], {'icon': 'https://example.com/i.png'});
    });

    test('GM_xmlhttpRequest grant emits xhr binding only', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_xmlhttpRequest']),
        initialValues: const {},
      );
      expect(shim, contains('var GM_xmlhttpRequest = function'));
      expect(shim, contains("__gmPost('xmlHttpRequest'"));
      expect(shim, isNot(contains('GM_getValue')));
    });

    test('GM.setClipboard grant emits modern binding', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM.setClipboard']),
        initialValues: const {},
      );
      expect(shim, contains('GM.setClipboard = function'));
      expect(shim, contains("__gmPost('setClipboard'"));
    });

    test('value grants auto-bundle legacy change listeners', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_setValue']),
        initialValues: const {},
      );
      expect(shim, contains('var GM_addValueChangeListener = __gmAddValueChangeListener;'));
      expect(shim, contains('var GM_removeValueChangeListener = __gmRemoveValueChangeListener;'));
      expect(shim, contains('__gmNotifyValueChangeListeners(key, oldVal, value, false);'));
    });

    test('modern value grants auto-bundle GM.addValueChangeListener', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM.setValue']),
        initialValues: const {},
      );
      expect(shim, contains('GM.addValueChangeListener = function'));
      expect(shim, contains('GM.removeValueChangeListener = function'));
    });

    test('explicit listener grant without value grant still activates shim', () {
      final shim = UserScriptGmShim.build(
        script: _script(grants: ['GM_addValueChangeListener']),
        initialValues: const {},
      );
      expect(shim, isNotNull);
      expect(shim, contains('__gmValueListeners = []'));
      expect(shim, contains('var GM_addValueChangeListener = __gmAddValueChangeListener;'));
      expect(shim, isNot(contains('var GM_setValue')));
    });
  });
}
