import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'app_shell.dart';
import 'autologin/auto_login_messages.dart';
import 'autologin/auto_login_notifications.dart';
import 'autologin/auto_login_screen.dart';
import 'autologin/secure_secret_store.dart';
import 'background/background_keepalive.dart';
import 'background/background_status.dart';
import 'debug_overlay.dart';
import 'gm/gm_host_handler.dart';
import 'gm/gm_menu_registry.dart';
import 'gm/gm_notification_overlay.dart';
import 'language/language_selector.dart';
import 'menu/app_menu_registry.dart';
import 'menu/gm_menu_command_item.dart';
import 'notifications/menu_notifications_bridge.dart';
import 'notifications/notification_service.dart';
import 'userscripts/userscript_http.dart';
import 'userscripts/userscripts_screen.dart';

class PopmundoApp extends StatelessWidget {
  const PopmundoApp({
    super.key,
    required this.runtime,
    required this.store,
    this.secretStore,
    this.keepalive,
    this.notificationService,
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;
  final SecretStore? secretStore;
  final BackgroundKeepalive? keepalive;
  final NotificationService? notificationService;

  /// Lets the auto-login listener show snackbars from above the [Scaffold].
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app.title'.tr(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: PopmundoHome(
        runtime: runtime,
        store: store,
        secretStore: secretStore ?? FlutterSecureSecretStore(),
        keepalive: keepalive,
        notificationService: notificationService,
      ),
    );
  }
}

class PopmundoHome extends StatefulWidget {
  const PopmundoHome({
    super.key,
    required this.runtime,
    required this.store,
    required this.secretStore,
    this.keepalive,
    this.notificationService,
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;
  final SecretStore secretStore;
  final BackgroundKeepalive? keepalive;
  final NotificationService? notificationService;

  @override
  State<PopmundoHome> createState() => _PopmundoHomeState();
}

class _PopmundoHomeState extends State<PopmundoHome>
    with WidgetsBindingObserver {
  var _cookies = const <CookieSummary>[];
  var _debugPanelVisible = false;
  var _bootstrapReady = false;
  var _enabledUserScripts = <InstalledUserScript>[];
  var _allUserScripts = <InstalledUserScript>[];
  var _previouslyEnabledIds = <String>{};
  BackgroundStatus? _backgroundStatus;

  late final storage = StorageService(widget.store);
  late final catalog = UserScriptCatalog(widget.store);
  late final gmValueStore = GmValueStore(widget.store);
  late final gmResourceStore = GmResourceStore(widget.store);
  late final gmMenuRegistry = GmMenuRegistry();
  late final gmNotificationController = GmNotificationController();
  late final settingsStore = AutoLoginSettingsStore(widget.store);
  late final timedFetch = TimedFetch(widget.runtime);
  late final importer = UserScriptImporter(
    catalog: catalog,
    httpGet: fetchUserScriptUrl,
    httpGetBytes: fetchUserScriptBytes,
    resourceStore: gmResourceStore,
  );
  late final gmHostHandler = GmHostHandler(
    runtime: widget.runtime,
    timedFetch: timedFetch,
    resourceStore: gmResourceStore,
    menuRegistry: gmMenuRegistry,
    notificationController: gmNotificationController,
    connectHeadersFor: _connectHeadersFor,
  );
  late final cookieJar = InAppCookieSink();
  late final autoLogin = AutoLoginController(
    runtime: widget.runtime,
    settingsStore: settingsStore,
    secretStore: widget.secretStore,
    // The native handshake authenticates over dart:io; without this the
    // WebView's own jar never learns about it and stays logged out.
    cookieSink: cookieJar,
    cookieSource: cookieJar,
    userAgentProvider: InAppWebViewController.getDefaultUserAgent,
  );
  late final menuNotificationsService = MenuNotificationsService(
    widget.runtime,
    timedFetch,
  );
  late final menuNotificationsStateStore = MenuNotificationStateStore(
    widget.store,
  );
  late final menuNotificationsWatcher = MenuNotificationsWatcher(
    runtime: widget.runtime,
    service: menuNotificationsService,
    stateStore: menuNotificationsStateStore,
  );
  late final menuNotificationsBridge = widget.notificationService == null
      ? null
      : MenuNotificationsBridge(
          watcher: menuNotificationsWatcher,
          utils: Utils(widget.runtime, timedFetch),
          notificationService: widget.notificationService!,
        );

  StreamSubscription<NavigationEvent>? _navSub;
  StreamSubscription<GmCallEvent>? _gmCallSub;
  StreamSubscription<AutoLoginStatus>? _autoLoginSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navSub = widget.runtime.events.navigation.listen(_onNavigation);
    widget.runtime.events.gmValue.listen((e) => gmValueStore.applyEvent(e));
    _gmCallSub = widget.runtime.events.gmCall.listen((e) {
      unawaited(gmHostHandler.handle(e));
    });
    _autoLoginSub = autoLogin.status.listen(_onAutoLoginStatus);
    gmMenuRegistry.addListener(_onGmMenuChanged);
    _refreshCookies();
    autoLogin.start();
    menuNotificationsWatcher.start();
    menuNotificationsBridge?.start();
    _bootstrap();
    final keepalive = widget.keepalive;
    if (keepalive != null) {
      _backgroundStatus = keepalive.status.value;
      keepalive.status.addListener(_onKeepaliveStatus);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(keepalive.bootstrap());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.keepalive?.status.removeListener(_onKeepaliveStatus);
    _navSub?.cancel();
    _gmCallSub?.cancel();
    _autoLoginSub?.cancel();
    gmMenuRegistry.removeListener(_onGmMenuChanged);
    unawaited(autoLogin.dispose());
    unawaited(menuNotificationsWatcher.dispose());
    unawaited(menuNotificationsBridge?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.keepalive?.onLifecycle(state);
  }

  void _onKeepaliveStatus() {
    final keepalive = widget.keepalive;
    if (keepalive == null || !mounted) return;
    setState(() => _backgroundStatus = keepalive.status.value);
  }

  Future<void> _onNavigation(NavigationEvent event) async {
    gmMenuRegistry.clear();
    await _refreshCookies();
  }

  void _onGmMenuChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> _connectHeadersFor(String scriptId) {
    for (final script in _allUserScripts) {
      if (script.id == scriptId) {
        return script.headers['connect'] ?? const [];
      }
    }
    return const [];
  }

  List<GmMenuCommandItem> get _gmMenuItems {
    return [
      for (final cmd in gmMenuRegistry.commands)
        GmMenuCommandItem(
          scriptId: cmd.scriptId,
          commandId: cmd.commandId,
          caption: cmd.caption,
        ),
    ];
  }

  Future<void> _bootstrap() async {
    final all = await catalog.list();
    final enabled = all.where((s) => s.enabled).toList();
    if (!mounted) return;
    setState(() {
      _allUserScripts = all;
      _enabledUserScripts = enabled;
      _previouslyEnabledIds = {for (final s in enabled) s.id};
      _bootstrapReady = true;
    });
  }

  Future<void> _refreshCookies() async {
    try {
      final url = WebUri(widget.runtime.host.currentOrigin.toString());
      final cookies = await CookieManager.instance().getCookies(url: url);
      if (!mounted) return;
      setState(() {
        _cookies = [
          for (final cookie in cookies)
            CookieSummary(name: cookie.name, domain: cookie.domain ?? url.host),
        ];
      });
    } catch (_) {
      // CookieManager is unavailable in some test/desktop bindings.
    }
  }

  Future<void> _applyUserScripts(List<InstalledUserScript> next) async {
    try {
      await widget.runtime.syncUserScripts(
        previouslyEnabledIds: _previouslyEnabledIds,
        nextCatalog: next,
        valueStore: gmValueStore,
      );
    } on PopmundoRuntimeException {
      // WebView may not be attached yet (e.g. still loading builtins).
    }
    final enabled = next.where((s) => s.enabled).toList();
    if (!mounted) return;
    setState(() {
      _allUserScripts = next;
      _enabledUserScripts = enabled;
      _previouslyEnabledIds = {for (final s in enabled) s.id};
    });
  }

  void _openUserScripts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserScriptsScreen(
          catalog: catalog,
          importer: importer,
          onApply: _applyUserScripts,
          onScriptDeleted: (scriptId) async {
            await gmValueStore.clearForScript(scriptId);
            await gmResourceStore.clearForScript(scriptId);
          },
        ),
      ),
    );
  }

  void _openAutoLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AutoLoginScreen(
          settingsStore: settingsStore,
          secretStore: widget.secretStore,
        ),
      ),
    );
  }

  void _onAutoLoginStatus(AutoLoginStatus status) {
    unawaited(notifyAutoLoginResult(
      status: status,
      lifecycle:
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      notificationService: widget.notificationService,
    ));
    final messenger = PopmundoApp.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final message = autoLoginStatusMessage(status);
    if (message == null) return;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: Key('autologin-status-${status.phase.name}'),
          content: Text(message),
          backgroundColor: status.phase == AutoLoginPhase.failed
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  void _openLanguage() {
    unawaited(showLanguageDialog(context));
  }

  @override
  Widget build(BuildContext context) {
    return PopmundoScope(
      runtime: widget.runtime,
      storage: storage,
      child: AppShell(
        items: buildAppMenuItems(
          onOpenDebugPanel: () => setState(() => _debugPanelVisible = true),
          onOpenUserScripts: _openUserScripts,
          onOpenAutoLogin: _openAutoLogin,
          onOpenLanguage: _openLanguage,
        ),
        gmMenuCommands: _gmMenuItems,
        onGmMenuCommand: (cmd) {
          unawaited(gmHostHandler.onMenuCommandTapped(
            GmMenuCommand(
              scriptId: cmd.scriptId,
              commandId: cmd.commandId,
              caption: cmd.caption,
            ),
          ));
        },
        body: SafeArea(
          child: !_bootstrapReady
              ? const Center(child: CircularProgressIndicator())
              : GmNotificationOverlay(
                  controller: gmNotificationController,
                  onTap: (n) => unawaited(gmHostHandler.onNotificationTapped(n)),
                  child: DebugOverlay(
                    host: widget.runtime.host,
                    events: widget.runtime.events,
                    evaluate: widget.runtime.evaluate,
                    cookies: _cookies,
                    backgroundStatus: _backgroundStatus,
                    notificationService: widget.notificationService,
                    visible: _debugPanelVisible,
                    onClose: () => setState(() => _debugPanelVisible = false),
                    child: PopmundoWebView(
                      runtime: widget.runtime,
                      gmValueStore: gmValueStore,
                      enabledUserScripts: _enabledUserScripts,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class PopmundoScope extends InheritedWidget {
  const PopmundoScope({
    super.key,
    required this.runtime,
    required this.storage,
    required super.child,
  });

  final InAppPopmundoRuntime runtime;
  final StorageService storage;

  static PopmundoScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PopmundoScope>();
    if (scope == null) {
      throw StateError('PopmundoScope not found');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(PopmundoScope oldWidget) {
    return runtime != oldWidget.runtime || storage != oldWidget.storage;
  }
}
