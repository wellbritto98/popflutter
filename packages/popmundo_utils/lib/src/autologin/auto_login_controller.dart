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
    try {
      await _runLoginCycle(
        loginPath: path == '/Default.aspx' ? '/Default.aspx' : '/',
      );
    } finally {
      if (!_awaitingChooseCharacter) {
        _inFlight = false;
      }
    }
  }

  Future<void> _runLoginCycle({required String loginPath}) async {
    final settings = await settingsStore.load();
    if (!settings.enabled) return;
    if (settings.username.trim().isEmpty) return;
    if (settings.characterName.trim().isEmpty) return;
    final password =
        await secretStore.read(AutoLoginSettingsStore.passwordSecretKey);
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

      final response = await timedFetch.fetchResponse(
        loginPath,
        options: {
          'method': 'POST',
          'redirect': 'manual',
          'headers': {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          'body': _encodeForm(body),
        },
        useCache: false,
        acceptRedirect: true,
      );

      final status = response.status;
      if (status >= 200 && status < 300) {
        // Failed login stays on form.
        return;
      }
      if (status < 300 || status >= 400) return;

      final locationRaw = response.locationHeader;
      if (locationRaw == null || locationRaw.isEmpty) return;
      final location = _resolveLocation(locationRaw, response.url);
      if (location == null) return;
      if (!HostTracker.isPopmundoUri(location)) return;
      if (!location.path.toLowerCase().contains('login.aspx')) return;

      _awaitingChooseCharacter = true;
      await runtime.loadUrl(location);
    } on TimedFetchException {
      _awaitingChooseCharacter = false;
    } catch (_) {
      _awaitingChooseCharacter = false;
    }
  }

  Future<void> _runChooseCharacter() async {
    if (!_inFlight || !_awaitingChooseCharacter) return;
    _awaitingChooseCharacter = false;
    try {
      final settings = await settingsStore.load();
      const path = '/World/Popmundo.aspx/ChooseCharacter';
      final html = await timedFetch.fetch(path, useCache: false);
      final tokens = AspNetForm.extractLoginTokens(html);
      if (tokens.isEmpty) return;

      final buttons = AspNetForm.findCharacterButtons(html);
      final button =
          AspNetForm.matchCharacter(buttons, settings.characterName);
      if (button == null) return;

      final body = <String, String>{
        '__EVENTTARGET': AspNetForm.extractHidden(html, '__EVENTTARGET') ?? '',
        '__EVENTARGUMENT':
            AspNetForm.extractHidden(html, '__EVENTARGUMENT') ?? '',
        ...tokens,
        button.name: button.value,
      };

      await timedFetch.fetchResponse(
        path,
        options: {
          'method': 'POST',
          'headers': {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          'body': _encodeForm(body),
        },
        useCache: false,
      );

      final last = await lastUrlStore.read();
      if (last != null) {
        await runtime.loadUrl(Uri.parse(last));
      } else {
        final origin = runtime.host.currentOrigin;
        await runtime.loadUrl(
          origin.replace(path: '/World/Popmundo.aspx'),
        );
      }
    } on TimedFetchException {
      // stay on ChooseCharacter
    } catch (_) {
      // stay on ChooseCharacter
    } finally {
      _inFlight = false;
    }
  }

  Uri? _resolveLocation(String locationRaw, String? responseUrl) {
    final parsed = Uri.tryParse(locationRaw);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      // Fix accidental double-slash path from server: //Login.aspx
      if (parsed.path.startsWith('//')) {
        return parsed.replace(path: parsed.path.substring(1));
      }
      return parsed;
    }
    final base = responseUrl != null
        ? Uri.tryParse(responseUrl)
        : runtime.host.currentOrigin;
    if (base == null) return null;
    return base.resolve(locationRaw);
  }

  static String _encodeForm(Map<String, String> fields) {
    return fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
  }
}

/// JSON helper kept for potential debug dumps — secrets must never go here.
String encodeSettingsWithoutSecrets(AutoLoginSettings settings) =>
    jsonEncode(settings.toJson());
