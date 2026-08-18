import 'dart:async';
import 'dart:convert';

import '../events.dart';
import '../host_tracker.dart';
import '../popmundo_runtime.dart';
import '../secret_store.dart';
import '../timed_fetch.dart';
import 'aspnet_form.dart';
import 'auto_login_settings.dart';
import 'last_url_store.dart';

/// Detects login pages and runs TimedFetch login + ChooseCharacter + restore.
class AutoLoginController {
  AutoLoginController({
    required this.runtime,
    required this.timedFetch,
    required this.settingsStore,
    required this.secretStore,
    required this.lastUrlStore,
  });

  final PopmundoRuntime runtime;
  final TimedFetch timedFetch;
  final AutoLoginSettingsStore settingsStore;
  final SecretStore secretStore;
  final LastUrlStore lastUrlStore;

  StreamSubscription<NavigationEvent>? _sub;
  var _inFlight = false;
  var _awaitingChooseCharacter = false;
  var _awaitingRestore = false;
  var _chooseSubmitInProgress = false;

  bool get inFlight => _inFlight;

  void start() {
    _sub ??= runtime.events.navigation.listen(_onNavigation);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onNavigation(NavigationEvent event) async {
    final uri = Uri.tryParse(event.url);
    if (uri == null || !HostTracker.isPopmundoUri(uri)) return;

    final path = uri.path.isEmpty ? '/' : uri.path;

    if (_awaitingRestore &&
        !AspNetForm.isLoginPath(path) &&
        !path.startsWith('/World/Popmundo.aspx/ChooseCharacter') &&
        !path.toLowerCase().contains('login.aspx')) {
      _awaitingRestore = false;
      final last = await lastUrlStore.read();
      if (last != null && last != event.url) {
        await runtime.loadUrl(Uri.parse(last));
      } else if (last == null) {
        final origin = runtime.host.currentOrigin;
        await runtime.loadUrl(
          origin.replace(path: '/World/Popmundo.aspx'),
        );
      }
      _inFlight = false;
      return;
    }

    if (_awaitingChooseCharacter &&
        path.startsWith('/World/Popmundo.aspx/ChooseCharacter')) {
      await _runChooseCharacter();
      return;
    }

    if (!AspNetForm.isLoginPath(path)) return;
    if (_inFlight) return;

    // Synchronous lock before any await (AUTH-06).
    _inFlight = true;
    _awaitingChooseCharacter = false;
    _awaitingRestore = false;
    try {
      await _runLoginCycle(
        loginPath: path == '/Default.aspx' ? '/Default.aspx' : '/',
      );
    } finally {
      if (!_awaitingChooseCharacter && !_awaitingRestore) {
        _inFlight = false;
      }
    }
  }

  Future<void> _runLoginCycle({required String loginPath}) async {
    final settings = await settingsStore.load();
    final password =
        await secretStore.read(AutoLoginSettingsStore.passwordSecretKey);
    if (!settings.enabled) return;
    if (settings.username.trim().isEmpty) return;
    if (settings.characterName.trim().isEmpty) return;
    if (password == null || password.isEmpty) return;

    try {
      final html = await timedFetch.fetch(loginPath, useCache: false);
      final tokens = AspNetForm.extractLoginTokens(html);
      if (tokens.isEmpty) return;

      final body = <String, String>{
        ...tokens,
        r'ctl00$cphRightColumn$ucLogin$txtUsername': settings.username.trim(),
        r'ctl00$cphRightColumn$ucLogin$txtPassword': password,
        r'ctl00$cphRightColumn$ucLogin$ddlStatus': '${settings.status}',
        r'ctl00$cphRightColumn$ucLogin$btnLogin': 'OK!',
      };

      // Browser fetch with redirect:'manual' returns opaqueredirect (status 0)
      // and strips Location. Document form POST navigates the WebView through
      // the 302 hop (cookies + HostTracker update).
      _awaitingChooseCharacter = true;
      await _submitFormNavigation(loginPath, body);
    } on TimedFetchException {
      _awaitingChooseCharacter = false;
    } catch (_) {
      _awaitingChooseCharacter = false;
    }
  }

  /// POSTs as a real document navigation (form.submit), not in-page fetch.
  Future<void> _submitFormNavigation(
    String actionPath,
    Map<String, String> fields,
  ) async {
    final js = '''
(function(){
  var form=document.createElement('form');
  form.method='POST';
  form.action=${jsonEncode(actionPath)};
  var fields=${jsonEncode(fields)};
  Object.keys(fields).forEach(function(name){
    var input=document.createElement('input');
    input.type='hidden';
    input.name=name;
    input.value=fields[name];
    form.appendChild(input);
  });
  document.body.appendChild(form);
  form.submit();
  return 'ok';
})()
''';
    await runtime.evaluate(js);
  }

  Future<void> _runChooseCharacter() async {
    if (!_inFlight || !_awaitingChooseCharacter) return;
    if (_chooseSubmitInProgress) return;

    try {
      // Live DOM — TimedFetch can hit too early / wrong host with incomplete HTML.
      final raw =
          await runtime.evaluate('document.documentElement.outerHTML');
      final html = raw ?? '';
      final tokens = AspNetForm.extractLoginTokens(html);
      final buttons = AspNetForm.findCharacterButtons(html);
      final settings = await settingsStore.load();
      final button =
          AspNetForm.matchCharacter(buttons, settings.characterName);

      if (buttons.isEmpty || tokens.isEmpty) {
        // Page not ready yet — keep awaiting; onLoadStop / later nav retries.
        return;
      }
      if (button == null) {
        _awaitingChooseCharacter = false;
        _inFlight = false;
        return;
      }

      final body = <String, String>{
        '__EVENTTARGET': AspNetForm.extractHidden(html, '__EVENTTARGET') ?? '',
        '__EVENTARGUMENT':
            AspNetForm.extractHidden(html, '__EVENTARGUMENT') ?? '',
        ...tokens,
        button.name: button.value,
      };

      _chooseSubmitInProgress = true;
      _awaitingChooseCharacter = false;
      _awaitingRestore = true;
      await _submitFormNavigation(
        '/World/Popmundo.aspx/ChooseCharacter',
        body,
      );
    } on TimedFetchException {
      _awaitingChooseCharacter = false;
      _awaitingRestore = false;
      _inFlight = false;
    } catch (_) {
      _awaitingChooseCharacter = false;
      _awaitingRestore = false;
      _inFlight = false;
    } finally {
      _chooseSubmitInProgress = false;
    }
  }
}

/// JSON helper kept for potential debug dumps — secrets must never go here.
String encodeSettingsWithoutSecrets(AutoLoginSettings settings) =>
    jsonEncode(settings.toJson());
