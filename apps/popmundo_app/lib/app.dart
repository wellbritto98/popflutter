import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'app_shell.dart';
import 'autologin/auto_login_screen.dart';
import 'autologin/secure_secret_store.dart';
import 'background/background_keepalive.dart';
import 'background/background_status.dart';
import 'debug_overlay.dart';
import 'language/language_selector.dart';
import 'menu/app_menu_registry.dart';
import 'userscripts/userscript_http.dart';
import 'userscripts/userscripts_screen.dart';

class PopmundoApp extends StatelessWidget {
  const PopmundoApp({
    super.key,
    required this.runtime,
    required this.store,
    this.secretStore,
    this.keepalive,
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;
  final SecretStore? secretStore;
  final BackgroundKeepalive? keepalive;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app.title'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: PopmundoHome(
        runtime: runtime,
        store: store,
        secretStore: secretStore ?? FlutterSecureSecretStore(),
        keepalive: keepalive,
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
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;
  final SecretStore secretStore;
  final BackgroundKeepalive? keepalive;

  @override
  State<PopmundoHome> createState() => _PopmundoHomeState();
}

class _PopmundoHomeState extends State<PopmundoHome>
    with WidgetsBindingObserver {
  var _cookies = const <CookieSummary>[];
  var _debugPanelVisible = false;
  var _bootstrapReady = false;
  var _enabledUserScripts = <InstalledUserScript>[];
  var _previouslyEnabledIds = <String>{};
  String? _initialUrl;
  BackgroundStatus? _backgroundStatus;

  late final storage = StorageService(widget.store);
  late final catalog = UserScriptCatalog(widget.store);
  late final importer = UserScriptImporter(
    catalog: catalog,
    httpGet: fetchUserScriptUrl,
  );
  late final gmValueStore = GmValueStore(widget.store);
  late final settingsStore = AutoLoginSettingsStore(widget.store);
  late final lastUrlStore = LastUrlStore(widget.store);
  late final timedFetch = TimedFetch(widget.runtime);
  late final autoLogin = AutoLoginController(
    runtime: widget.runtime,
    timedFetch: timedFetch,
    settingsStore: settingsStore,
    secretStore: widget.secretStore,
    lastUrlStore: lastUrlStore,
  );

  StreamSubscription<NavigationEvent>? _navSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navSub = widget.runtime.events.navigation.listen(_onNavigation);
    widget.runtime.events.gmValue.listen((e) => gmValueStore.applyEvent(e));
    _refreshCookies();
    autoLogin.start();
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
    unawaited(autoLogin.dispose());
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
    await lastUrlStore.record(event.url);
    await _refreshCookies();
  }

  Future<void> _bootstrap() async {
    final all = await catalog.list();
    final enabled = all.where((s) => s.enabled).toList();
    final last = await lastUrlStore.read();
    if (!mounted) return;
    setState(() {
      _enabledUserScripts = enabled;
      _previouslyEnabledIds = {for (final s in enabled) s.id};
      _initialUrl = last;
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
          onScriptDeleted: gmValueStore.clearForScript,
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
        body: SafeArea(
          child: !_bootstrapReady
              ? const Center(child: CircularProgressIndicator())
              : DebugOverlay(
                  host: widget.runtime.host,
                  events: widget.runtime.events,
                  evaluate: widget.runtime.evaluate,
                  cookies: _cookies,
                  backgroundStatus: _backgroundStatus,
                  visible: _debugPanelVisible,
                  onClose: () => setState(() => _debugPanelVisible = false),
                  child: PopmundoWebView(
                    runtime: widget.runtime,
                    gmValueStore: gmValueStore,
                    enabledUserScripts: _enabledUserScripts,
                    initialUrl: LastUrlStore.resolveInitialUrl(_initialUrl),
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
