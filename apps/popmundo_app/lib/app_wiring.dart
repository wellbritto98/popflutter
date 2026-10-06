import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'autologin/secure_secret_store.dart';
import 'background/background_keepalive.dart';
import 'background/background_status.dart';
import 'cookie_watcher.dart';
import 'gm/gm_host_handler.dart';
import 'gm/gm_menu_registry.dart';
import 'notifications/menu_notifications_bridge.dart';
import 'notifications/notification_service.dart';
import 'userscripts/userscript_http.dart';

/// The userscript catalog as the UI needs to see it, in one value.
///
/// [previouslyEnabledIds] is not display state — it is the diff input
/// `runtime.syncUserScripts` needs on the *next* apply, and it lives here so it
/// can never drift out of sync with [all]/[enabled].
@immutable
class UserscriptsState {
  const UserscriptsState({
    required this.ready,
    required this.all,
    required this.enabled,
    required this.previouslyEnabledIds,
  });

  /// Before the first `catalog.list()` resolves the shell shows a spinner.
  const UserscriptsState.loading()
    : ready = false,
      all = const [],
      enabled = const [],
      previouslyEnabledIds = const {};

  final bool ready;
  final List<InstalledUserScript> all;
  final List<InstalledUserScript> enabled;
  final Set<String> previouslyEnabledIds;
}

/// Owns every non-UI collaborator the shell needs, and their lifecycle.
///
/// Constructed once in `main.dart`; `PopmundoHome` only reads from it and calls
/// into it. Nothing here touches `BuildContext`, `State`, `Navigator` or any
/// widget — that is what makes the wiring testable without pumping a widget
/// tree, and what keeps a new feature from having to edit the composition root
/// in four separate places.
///
/// Observable state is exposed as [ValueListenable]s rather than pushed through
/// `setState`, so the shell rebuilds only the subtree that actually depends on
/// each value.
class AppWiring {
  AppWiring({
    required this.runtime,
    required this.store,
    SecretStore? secretStore,
    this.cookieSink,
    this.cookieSource,
    this.keepalive,
    this.notificationService,
  }) : secretStore = secretStore ?? FlutterSecureSecretStore();

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;
  final SecretStore secretStore;
  final BackgroundKeepalive? keepalive;
  final NotificationService? notificationService;

  /// Overrides for the WebView cookie jar. Both default to [cookieJar]; tests
  /// pass `MemoryCookieSink` because [InAppCookieSink] builds a
  /// `CookieManager` eagerly, which needs a live platform channel.
  final CookieSink? cookieSink;
  final CookieSource? cookieSource;

  // ── observable state ────────────────────────────────────────────────────
  final userscripts = ValueNotifier<UserscriptsState>(
    const UserscriptsState.loading(),
  );
  late final cookieWatcher = CookieWatcher(runtime.host);

  /// Already a [ValueListenable] on [BackgroundKeepalive] — exposed as-is so
  /// the shell listens to it directly instead of mirroring it into `setState`.
  ValueListenable<BackgroundStatus>? get backgroundStatus => keepalive?.status;

  /// The shell subscribes to this itself: its handler needs a `BuildContext`
  /// to colour the error SnackBar, so it cannot live here.
  Stream<AutoLoginStatus> get autoLoginStatus => autoLogin.status;

  // ── collaborators ───────────────────────────────────────────────────────
  late final catalog = UserScriptCatalog(store);
  late final gmValueStore = GmValueStore(store);
  late final gmResourceStore = GmResourceStore(store);
  late final gmMenuRegistry = GmMenuRegistry();
  late final gmNotificationController = GmNotificationController();
  late final settingsStore = AutoLoginSettingsStore(store);
  late final timedFetch = TimedFetch(runtime);
  late final importer = UserScriptImporter(
    catalog: catalog,
    httpGet: fetchUserScriptUrl,
    httpGetBytes: fetchUserScriptBytes,
    resourceStore: gmResourceStore,
  );
  late final gmHostHandler = GmHostHandler(
    runtime: runtime,
    timedFetch: timedFetch,
    resourceStore: gmResourceStore,
    menuRegistry: gmMenuRegistry,
    notificationController: gmNotificationController,
    connectHeadersFor: connectHeadersFor,
  );
  late final cookieJar = InAppCookieSink();
  late final autoLogin = AutoLoginController(
    runtime: runtime,
    settingsStore: settingsStore,
    secretStore: secretStore,
    // The native handshake authenticates over dart:io; without this the
    // WebView's own jar never learns about it and stays logged out.
    cookieSink: cookieSink ?? cookieJar,
    cookieSource: cookieSource ?? cookieJar,
  );
  late final menuNotificationsService = MenuNotificationsService(
    runtime,
    timedFetch,
  );
  late final menuNotificationsStateStore = MenuNotificationStateStore(store);
  late final menuNotificationsWatcher = MenuNotificationsWatcher(
    runtime: runtime,
    service: menuNotificationsService,
    stateStore: menuNotificationsStateStore,
  );
  late final menuNotificationsBridge = notificationService == null
      ? null
      : MenuNotificationsBridge(
          watcher: menuNotificationsWatcher,
          utils: Utils(runtime, timedFetch),
          notificationService: notificationService!,
        );

  bool _started = false;
  bool _disposed = false;
  StreamSubscription<NavigationEvent>? _navSub;
  StreamSubscription<GmValueEvent>? _gmValueSub;
  StreamSubscription<GmCallEvent>? _gmCallSub;

  /// Subscribes to the runtime's event streams and starts the long-lived
  /// collaborators. Safe to call more than once: extracting this out of
  /// `initState` removed Flutter's run-once guarantee, so the guard is
  /// explicit — a second call must not double-subscribe.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _navSub = runtime.events.navigation.listen(_onNavigation);
    _gmValueSub = runtime.events.gmValue.listen(gmValueStore.applyEvent);
    _gmCallSub = runtime.events.gmCall.listen(
      (e) => unawaited(gmHostHandler.handle(e)),
    );
    unawaited(cookieWatcher.refresh());
    autoLogin.start();
    menuNotificationsWatcher.start();
    menuNotificationsBridge?.start();
    unawaited(_bootstrap());
    final keepalive = this.keepalive;
    if (keepalive != null) {
      // Deferred to after the first frame so the foreground-service plugin
      // never runs against a half-built tree.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => unawaited(keepalive.bootstrap()),
      );
    }
  }

  /// Cancels everything [start] created. A no-op if [start] never ran.
  ///
  /// Safe to call while a `start()`-initiated future is still in flight:
  /// `catalog.list()` and `cookieWatcher.refresh()` are fire-and-forget, so
  /// without the [_disposed] guard their late completion would write to an
  /// already-disposed [ValueNotifier] and surface as an unhandled async error.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    await _navSub?.cancel();
    await _gmValueSub?.cancel();
    await _gmCallSub?.cancel();
    _navSub = null;
    _gmValueSub = null;
    _gmCallSub = null;
    await autoLogin.dispose();
    await menuNotificationsWatcher.dispose();
    await menuNotificationsBridge?.dispose();
    cookieWatcher.dispose();
    userscripts.dispose();
  }

  Future<void> _onNavigation(NavigationEvent event) async {
    // Menu commands are re-registered by the scripts on each page, so the
    // previous page's entries must not survive the navigation.
    gmMenuRegistry.clear();
    await cookieWatcher.refresh();
  }

  Future<void> _bootstrap() async => _publish(await catalog.list());

  /// Pushes [next] into the WebView and republishes the catalog.
  ///
  /// Reads `previouslyEnabledIds` *before* publishing, so `syncUserScripts`
  /// receives the previous enabled set as its diff base.
  Future<void> applyUserScripts(List<InstalledUserScript> next) async {
    try {
      await runtime.syncUserScripts(
        previouslyEnabledIds: userscripts.value.previouslyEnabledIds,
        nextCatalog: next,
        valueStore: gmValueStore,
      );
    } on PopmundoRuntimeException {
      // WebView may not be attached yet (e.g. still loading builtins).
    }
    _publish(next);
  }

  void _publish(List<InstalledUserScript> all) {
    if (_disposed) return;
    final enabled = all.where((s) => s.enabled).toList();
    userscripts.value = UserscriptsState(
      ready: true,
      all: all,
      enabled: enabled,
      previouslyEnabledIds: {for (final s in enabled) s.id},
    );
  }

  /// The `@connect` hosts a userscript declared, for [GmHostHandler]'s
  /// cross-origin policy. Unknown ids are not an error — a script can be
  /// deleted while one of its requests is still in flight.
  List<String> connectHeadersFor(String scriptId) {
    for (final script in userscripts.value.all) {
      if (script.id == scriptId) return script.headers['connect'] ?? const [];
    }
    return const [];
  }
}
