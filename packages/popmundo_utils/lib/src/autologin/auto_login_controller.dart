import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../events.dart';
import '../host_tracker.dart';
import '../popmundo_runtime.dart';
import '../secret_store.dart';
import '../timed_fetch.dart' show ClockNow;
import 'aspnet_form.dart';
import 'aspnet_form_data.dart';
import 'auth_http.dart';
import 'auth_http_io.dart';
import 'auto_login_requests.dart';
import 'auto_login_settings.dart';
import 'auto_login_status.dart';
import 'auto_login_trace.dart';
import 'cookie_sink.dart';
import 'game_cookie.dart';

/// Detects the login page and signs the player back in without showing it.
///
/// The whole handshake — login form, credentials POST, the host handover and
/// the character choice — runs over **native HTTP** ([AuthSession]), outside
/// the WebView. It has to: logging in on `www.popmundo.com` answers `302` to a
/// load-balanced `N.popmundo.com`, and an in-page fetch cannot follow that hop
/// because the browser blocks the cross-origin redirect with CORS. `dart:io`
/// has no such restriction.
///
/// Nothing in the handshake touches the WebView, so it is still logged out when
/// the handshake ends; [CookieSink] copies the session cookies into its jar,
/// and the single navigation to the world home page is the only thing the
/// player sees (AD-018).
class AutoLoginController {
  AutoLoginController({
    required this.runtime,
    required this.settingsStore,
    required this.secretStore,
    this.cookieSink,
    this.cookieSource,
    AutoLoginTrace? trace,
    Future<void> Function(Duration)? sleep,
    ClockNow? now,
    this.authSend,
    this.userAgentProvider,
    this.heartbeatInterval = const Duration(seconds: 60),
    this.webViewTimeout = const Duration(seconds: 2),
  })  : _trace = trace ?? defaultAutoLoginTrace,
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  static const chooseCharacterPath = '/World/Popmundo.aspx/ChooseCharacter';
  static const worldHomePath = '/World/Popmundo.aspx';
  static const characterPath = '/World/Popmundo.aspx/Character';

  final PopmundoRuntime runtime;
  final AutoLoginSettingsStore settingsStore;
  final SecretStore secretStore;

  /// Copies the handshake's cookies into the WebView. Without it the native
  /// login authenticates nobody — the WebView has a jar of its own.
  final CookieSink? cookieSink;

  /// Live WebView cookies, seeded into [AuthSession] before each heartbeat.
  final CookieSource? cookieSource;

  /// Native transport. Injected so tests drive the handshake without sockets.
  final AuthHttpSend? authSend;

  /// Optional native UA lookup, independent of WebView attachment/rendering.
  /// Without it, the first lookup uses the page bridge with a bounded wait.
  final Future<String> Function()? userAgentProvider;

  /// How often [checkSession] runs after the initial bounded UA lookup.
  final Duration heartbeatInterval;

  /// Bounds the initial UA lookup and final navigation acknowledgement.
  final Duration webViewTimeout;

  final AutoLoginTrace _trace;
  final Future<void> Function(Duration) _sleep;
  final ClockNow _now;
  IoAuthHttpSender? _ioSender;
  Future<String>? _userAgent;

  AuthHttpSend get _send {
    final injected = authSend;
    if (injected != null) return injected;
    return (_ioSender ??= IoAuthHttpSender()).call;
  }

  final _status = StreamController<AutoLoginStatus>.broadcast();

  StreamSubscription<NavigationEvent>? _sub;
  Timer? _heartbeatTimer;
  var _inFlight = false;
  var _running = false;

  bool get inFlight => _inFlight;

  /// Progress of the current cycle, for shell-level feedback.
  Stream<AutoLoginStatus> get status => _status.stream;

  void start() {
    if (_sub != null) return;
    _running = true;
    _trace('listening for navigations (host=${runtime.host.currentOrigin})');
    _sub = runtime.events.navigation.listen(_onNavigation);
    unawaited(_armHeartbeat());
  }

  Future<void> _armHeartbeat() async {
    // Capture the real UA while the page is active. A paused renderer must not
    // gate native HTTP forever, including when the app starts in background.
    await _readUserAgent();
    if (!_running) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      unawaited(checkSession());
    });
    await checkSession();
  }

  Future<void> dispose() async {
    _running = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    _ioSender?.close();
    _ioSender = null;
    await _status.close();
  }

  void _emit(AutoLoginStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  /// Clears the cycle and reports why it stopped.
  void _abort(
    AutoLoginFailure failure, {
    String? characterName,
    String? serverMessage,
  }) {
    _trace('ABORT ${failure.name}'
        '${characterName == null ? '' : ' character="$characterName"'}'
        '${serverMessage == null ? '' : ' server="$serverMessage"'}');
    _inFlight = false;
    _emit(AutoLoginStatus.failed(
      failure,
      characterName: characterName,
      serverMessage: serverMessage,
    ));
  }

  Future<void> _onNavigation(NavigationEvent event) async {
    final uri = Uri.tryParse(event.url);
    if (uri == null || !HostTracker.isPopmundoUri(uri)) {
      _trace('nav ignored (not a Popmundo URL): ${event.url}');
      return;
    }

    final path = uri.path.isEmpty ? '/' : uri.path;
    _trace('nav ${event.url} (path=$path, inFlight=$_inFlight, '
        'host=${runtime.host.currentOrigin})');

    if (!AspNetForm.isLoginPath(path)) {
      _trace('not a login path — nothing to do');
      return;
    }
    if (_inFlight) {
      _trace('login path seen but a cycle is already in flight — ignoring');
      return;
    }

    // Synchronous lock before any await.
    _inFlight = true;
    try {
      await _runLoginCycle(
        loginPath: path == '/Default.aspx' ? '/Default.aspx' : '/',
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Probes `{stickyHost}/World/Popmundo.aspx/Character` (AD-019).
  ///
  /// A 302 to a login path starts the silent handshake. 200 / network errors
  /// / `www` are no-ops. Safe to call from tests; the timer also calls this.
  Future<void> checkSession() async {
    if (!_running || _inFlight) return;

    final origin = runtime.host.currentOrigin;
    final host = origin.host.toLowerCase();
    if (!HostTracker.isPopmundoHost(host) || host == 'www.popmundo.com') {
      _trace('heartbeat skip: host=$host');
      return;
    }
    final source = cookieSource;
    if (source == null) {
      _trace('heartbeat skip: no CookieSource');
      return;
    }

    // Lock before settings/cookie reads: navigation and timer ticks share this
    // native operation even when the renderer is suspended.
    _inFlight = true;
    try {
      final settings = await settingsStore.load();
      final password = await secretStore.read(
        AutoLoginSettingsStore.passwordSecretKey,
      );
      if (!settings.enabled ||
          settings.username.trim().isEmpty ||
          settings.characterName.trim().isEmpty ||
          password == null ||
          password.isEmpty) {
        _trace('heartbeat skip: auto-login not armed');
        return;
      }

      List<GameCookie> jar;
      try {
        jar = await source.read(origin);
      } catch (e) {
        _trace('heartbeat skip: cookie read failed ($e)');
        return;
      }
      if (!_running) return;

      final url = origin.replace(path: characterPath);
      _trace('heartbeat GET $url');
      final session = AuthSession(
        send: _send,
        userAgent: await _readUserAgent(),
        sleep: _sleep,
        now: _now,
      );
      if (!_running) return;
      session.seed(jar);
      final response = await session.probe(url);
      _trace(
        'heartbeat ${response.status} location=${response.location}',
      );
      if (response.status == 200) return;
      if (!_isLogoutRedirect(url, response)) return;
      _trace('heartbeat: logged out — starting cycle');
      await _runLoginCycle(loginPath: '/Default.aspx', session: session);
    } on AuthHttpException catch (e) {
      _trace('heartbeat network error: $e');
    } finally {
      _inFlight = false;
    }
  }

  static bool _isLogoutRedirect(Uri from, AuthHttpResponse response) {
    if (!response.isRedirect || response.location == null) return false;
    final next = AuthSession.resolveLocation(from, response.location!);
    if (next == null) return false;
    final path = next.path.isEmpty ? '/' : next.path;
    return AspNetForm.isLoginPath(path);
  }

  Future<void> _runLoginCycle({
    required String loginPath,
    AuthSession? session,
  }) async {
    final settings = await settingsStore.load();
    final password =
        await secretStore.read(AutoLoginSettingsStore.passwordSecretKey);
    _trace('cycle start: loginPath=$loginPath enabled=${settings.enabled} '
        'username=${settings.username.trim().isEmpty ? '<empty>' : settings.username.trim()} '
        'character="${visibleName(settings.characterName)}" '
        'status=${settings.status} '
        'password=${password == null || password.isEmpty ? '<missing>' : '<${password.length} chars>'}');
    if (!settings.enabled) {
      _trace('skip: Auto Login disabled');
      return;
    }
    if (settings.username.trim().isEmpty) {
      _trace('skip: no username configured');
      return;
    }
    if (settings.characterName.trim().isEmpty) {
      _trace('skip: no character name configured');
      return;
    }
    if (password == null || password.isEmpty) {
      _trace('skip: no password stored');
      return;
    }

    _emit(const AutoLoginStatus(AutoLoginPhase.detected));

    try {
      await _runNativeHandshake(
        loginPath: loginPath,
        settings: settings,
        password: password,
        session: session,
      );
    } on AuthHttpException catch (e) {
      _trace('native handshake failed: $e');
      _abort(AutoLoginFailure.networkError);
    }
  }

  /// Login, host handover and character choice, entirely over native HTTP.
  Future<void> _runNativeHandshake({
    required String loginPath,
    required AutoLoginSettings settings,
    required String password,
    AuthSession? session,
  }) async {
    final loginUrl = runtime.host.currentOrigin.replace(path: loginPath);
    final userAgent = session?.userAgent ?? await _readUserAgent();
    _trace('native handshake from $loginUrl (ua=$userAgent)');

    session ??= AuthSession(
      send: _send,
      userAgent: userAgent,
      sleep: _sleep,
      now: _now,
    );

    _emit(const AutoLoginStatus(AutoLoginPhase.authenticating));

    final page = await session.get(loginUrl);
    _trace('GET login page: status=${page.status} ${page.body.length} chars');
    final form = AutoLoginRequests.loginBody(
      html_parser.parse(page.body),
      username: settings.username,
      password: password,
      status: settings.status,
    );
    if (form.isEmpty) {
      traceChunked(_trace, 'login-page-html', page.body, secrets: [password]);
      _abort(AutoLoginFailure.missingForm);
      return;
    }
    _trace('login body: ${describeFields(form.entries)}');

    final landed = await session.postForm(loginUrl, form.encode());
    _trace('login chain: ${landed.hops.join(' -> ')} '
        '(status=${landed.status}, ${landed.body.length} chars)');

    final landedPath = landed.finalUrl.path.isEmpty ? '/' : landed.finalUrl.path;
    if (AspNetForm.isLoginPath(landedPath) ||
        AspNetForm.looksLikeLoginForm(landed.body)) {
      _trace('login response is still the login page');
      traceChunked(_trace, 'login-response-html', landed.body,
          secrets: [password]);
      _abort(AutoLoginFailure.invalidCredentials);
      return;
    }

    // The game assigns the host at login, so everything after this point is
    // resolved against where the chain actually ended, never a stored origin.
    final gameOrigin = Uri(scheme: 'https', host: landed.finalUrl.host);
    _trace('logged in on ${gameOrigin.host}');

    final doc = html_parser.parse(landed.body);
    final plan = _planChoice(
      doc: doc,
      html: landed.body,
      settings: settings,
      secrets: [password],
    );
    if (plan == null) return;

    final chooseUrl = gameOrigin.replace(path: chooseCharacterPath);
    _trace('POST $chooseUrl');
    final chosen = await session.postForm(chooseUrl, plan.body);
    _trace(
        'choose chain: ${chosen.hops.join(' -> ')} (status=${chosen.status})');

    final chosenPath = chosen.finalUrl.path.isEmpty ? '/' : chosen.finalUrl.path;
    if (chosenPath.startsWith(chooseCharacterPath)) {
      _trace('still on ChooseCharacter after the POST — choice rejected');
      _abort(
        AutoLoginFailure.serverRejected,
        characterName: plan.choice.fullName,
      );
      return;
    }

    // Nothing above touched the WebView, so it is still logged out. This is
    // what actually signs it in.
    final jar = session.cookies;
    _trace('syncing ${jar.length} cookie(s) into the WebView: '
        '${jar.map((c) => '${c.name}@${c.host}').join(', ')}');
    final sink = cookieSink;
    if (sink == null) {
      _trace('no CookieSink wired — the WebView will NOT be logged in');
    } else {
      await sink.write(jar);
    }

    _emit(AutoLoginStatus(
      AutoLoginPhase.done,
      characterName: plan.choice.fullName,
    ));
    final home = gameOrigin.replace(path: worldHomePath);
    _trace('DONE — navigating to $home');
    try {
      await runtime.loadUrl(home).timeout(webViewTimeout);
    } on TimeoutException {
      _trace('world navigation pending: WebView paused; session renewed');
    } catch (e) {
      _trace(
        'world navigation unavailable after session renewal ($e)',
      );
    }
  }

  /// Reads the WebView's user agent so the native client is the same client to
  /// the game, not a second one.
  Future<String> _readUserAgent() => _userAgent ??= _readWebViewUserAgent();

  Future<String?> _captureUserAgent() async {
    final provider = userAgentProvider;
    if (provider != null) return provider();
    // start() precedes WebView attachment in the app shell. Only this initial
    // lookup waits for the bridge; all later probes use the cached result.
    await runtime.waitUntilReady(timeout: webViewTimeout);
    return runtime.evaluate('navigator.userAgent');
  }

  Future<String> _readWebViewUserAgent() async {
    try {
      final raw = await _captureUserAgent().timeout(webViewTimeout);
      final text = (raw ?? '').trim();
      final unquoted =
          text.length >= 2 && text.startsWith('"') && text.endsWith('"')
              ? text.substring(1, text.length - 1)
              : text;
      if (unquoted.isNotEmpty) return unquoted;
    } on TimeoutException {
      _trace(
        'could not read the WebView user agent (renderer paused) — using a default',
      );
    } catch (e) {
      _trace('could not read the WebView user agent ($e) — using a default');
    }
    return 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36';
  }

  /// Finds the configured character on a ChooseCharacter page and builds the
  /// POST body for it.
  ///
  /// Returns null and reports the failure when the page cannot be used.
  _ChoicePlan? _planChoice({
    required Document doc,
    required String html,
    required AutoLoginSettings settings,
    Iterable<String> secrets = const [],
  }) {
    _trace('choose: parsing ${html.length} chars '
        'looking for "${visibleName(settings.characterName)}"');

    final choices = AspNetForm.parseCharacterChoices(doc);
    _trace('choose: ${choices.length} candidate(s) found');
    for (final c in choices) {
      _trace('  candidate "${visibleName(c.fullName)}" '
          '-> name="${c.buttonName}" value="${visibleName(c.buttonValue)}"');
    }

    if (choices.isEmpty) {
      _dumpPage(doc, html, 'no candidates parsed', secrets: secrets);
      _abort(AutoLoginFailure.noCharacters);
      return null;
    }

    final match =
        AspNetForm.matchCharacterChoice(choices, settings.characterName);
    switch (match.outcome) {
      case CharacterMatchOutcome.notFound:
        _trace('choose: NO MATCH. '
            'wanted="${visibleName(AspNetForm.normalizeName(settings.characterName).toLowerCase())}" '
            'available=${choices.map((c) => '"${visibleName(c.fullName.toLowerCase())}"').toList()}');
        _dumpPage(doc, html, 'character not found', secrets: secrets);
        _abort(
          AutoLoginFailure.characterNotFound,
          characterName: settings.characterName,
        );
        return null;
      case CharacterMatchOutcome.ambiguous:
        _trace('choose: AMBIGUOUS — more than one box named '
            '"${visibleName(settings.characterName)}"');
        _abort(
          AutoLoginFailure.characterAmbiguous,
          characterName: settings.characterName,
        );
        return null;
      case CharacterMatchOutcome.matched:
        break;
    }

    final choice = match.choice!;
    _trace('choose: matched "${visibleName(choice.fullName)}" '
        '-> ${choice.buttonName}');

    final form = AutoLoginRequests.chooseCharacterBody(doc, choice);
    if (form.isEmpty) {
      _abort(AutoLoginFailure.missingForm);
      return null;
    }

    _emit(AutoLoginStatus(
      AutoLoginPhase.choosingCharacter,
      characterName: choice.fullName,
    ));
    return _ChoicePlan(choice: choice, form: form);
  }

  /// Dumps everything needed to diagnose a parsing failure from a log: what the
  /// page looks like structurally, then the raw HTML.
  void _dumpPage(
    Document doc,
    String html,
    String reason, {
    Iterable<String> secrets = const [],
  }) {
    _trace('--- page dump: $reason ---');
    for (final line in AspNetForm.describeDocument(doc)) {
      _trace('  $line');
    }
    traceChunked(_trace, 'page-html', html, secrets: secrets);
    _trace('--- end page dump ---');
  }
}

/// A resolved character choice plus the body that submits it.
class _ChoicePlan {
  const _ChoicePlan({required this.choice, required this.form});

  final CharacterChoice choice;
  final AspNetFormData form;

  String get body => form.encode();
}

/// JSON helper kept for potential debug dumps — secrets must never go here.
String encodeSettingsWithoutSecrets(AutoLoginSettings settings) =>
    jsonEncode(settings.toJson());
