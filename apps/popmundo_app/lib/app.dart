import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'app_shell.dart';
import 'debug_overlay.dart';
import 'menu/app_menu_registry.dart';
import 'userscripts/userscript_http.dart';
import 'userscripts/userscripts_screen.dart';

class PopmundoApp extends StatelessWidget {
  const PopmundoApp({
    super.key,
    required this.runtime,
    required this.store,
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popmundo',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: PopmundoHome(runtime: runtime, store: store),
    );
  }
}

class PopmundoHome extends StatefulWidget {
  const PopmundoHome({
    super.key,
    required this.runtime,
    required this.store,
  });

  final InAppPopmundoRuntime runtime;
  final KeyValueStore store;

  @override
  State<PopmundoHome> createState() => _PopmundoHomeState();
}

class _PopmundoHomeState extends State<PopmundoHome> {
  var _cookies = const <CookieSummary>[];
  var _debugPanelVisible = false;
  var _catalogReady = false;
  var _enabledUserScripts = <InstalledUserScript>[];
  var _previouslyEnabledIds = <String>{};

  late final storage = StorageService(widget.store);
  late final catalog = UserScriptCatalog(widget.store);
  late final importer = UserScriptImporter(
    catalog: catalog,
    httpGet: fetchUserScriptUrl,
  );
  late final gmValueStore = GmValueStore(widget.store);

  @override
  void initState() {
    super.initState();
    widget.runtime.events.navigation.listen((_) => _refreshCookies());
    widget.runtime.events.gmValue.listen((e) => gmValueStore.applyEvent(e));
    _refreshCookies();
    _bootstrapUserScripts();
  }

  Future<void> _bootstrapUserScripts() async {
    final all = await catalog.list();
    final enabled = all.where((s) => s.enabled).toList();
    if (!mounted) return;
    setState(() {
      _enabledUserScripts = enabled;
      _previouslyEnabledIds = {for (final s in enabled) s.id};
      _catalogReady = true;
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

  @override
  Widget build(BuildContext context) {
    return PopmundoScope(
      runtime: widget.runtime,
      storage: storage,
      child: AppShell(
        items: buildAppMenuItems(
          onOpenDebugPanel: () => setState(() => _debugPanelVisible = true),
          onOpenUserScripts: _openUserScripts,
        ),
        body: SafeArea(
          child: !_catalogReady
              ? const Center(child: CircularProgressIndicator())
              : DebugOverlay(
                  host: widget.runtime.host,
                  events: widget.runtime.events,
                  evaluate: widget.runtime.evaluate,
                  cookies: _cookies,
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
