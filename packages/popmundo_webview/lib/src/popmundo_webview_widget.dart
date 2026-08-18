import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'in_app_runtime.dart';
import 'user_scripts.dart';
import 'userscript_injector.dart';
import 'web_settings.dart';
import 'webview_back_navigation.dart';

class PopmundoWebView extends StatefulWidget {
  const PopmundoWebView({
    super.key,
    required this.runtime,
    required this.gmValueStore,
    this.initialUrl = HostTracker.defaultOrigin,
    this.launchExternal,
    this.enabledUserScripts = const [],
  });

  final InAppPopmundoRuntime runtime;
  final String initialUrl;
  final Future<void> Function(Uri uri)? launchExternal;

  /// Backs `GM_getValue`/`GM_setValue` preloading for [enabledUserScripts].
  final GmValueStore gmValueStore;

  /// Catalog entries with `enabled == true` merged into [initialUserScripts].
  final List<InstalledUserScript> enabledUserScripts;

  @override
  State<PopmundoWebView> createState() => _PopmundoWebViewState();
}

class _PopmundoWebViewState extends State<PopmundoWebView> {
  UnmodifiableListView<UserScript>? _scripts;
  var _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  @override
  void didUpdateWidget(covariant PopmundoWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEnabled(oldWidget.enabledUserScripts, widget.enabledUserScripts)) {
      // initialUserScripts only apply on create; runtime sync is owned by the
      // host via UserScriptInjector.sync. Rebuild list only if WebView not yet
      // created (still loading builtins).
      if (_scripts == null) {
        _loadScripts();
      }
    }
  }

  bool _sameEnabled(List<InstalledUserScript> a, List<InstalledUserScript> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].source != b[i].source) return false;
    }
    return true;
  }

  Future<void> _loadScripts() async {
    final builtin = await PopmundoUserScripts.load();
    final merged = await UserScriptInjector.mergeInitial(
      builtin: builtin,
      enabled: widget.enabledUserScripts,
      valueStore: widget.gmValueStore,
    );
    if (!mounted) return;
    setState(() => _scripts = merged);
  }

  Future<void> _syncHistory() async {
    final c = widget.runtime.controller;
    final next = c != null && await c.canGoBack();
    if (!mounted || next == _canGoBack) return;
    setState(() => _canGoBack = next);
  }

  Future<void> _onSystemBack() async {
    final c = widget.runtime.controller;
    final decision = await WebViewBackHandler.handle(
      c == null ? null : InAppWebViewHistoryPort(c),
    );
    if (!mounted) return;
    if (decision == SystemBackDecision.navigateBack) {
      await _syncHistory();
      return;
    }
    await SystemNavigator.pop();
  }

  Future<void> _openExternal(Uri uri) async {
    final launcher = widget.launchExternal;
    if (launcher != null) {
      await launcher(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scripts = _scripts;
    if (scripts == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope<void>(
      canPop: WebViewBackHandler.allowRoutePop(webViewCanGoBack: _canGoBack),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onSystemBack();
      },
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
        initialSettings: PopmundoWebSettings.defaults(),
        initialUserScripts: scripts,
        onWebViewCreated: (controller) {
          widget.runtime.attach(controller);
          _syncHistory();
        },
        onLoadStart: (controller, url) {
          if (url != null) widget.runtime.onNativeNavigation(url);
          _syncHistory();
        },
        onLoadStop: (controller, url) {
          // Auto-login (and similar) need a nav signal when the document is
          // actually ready — onLoadStart alone can see an empty/partial DOM.
          if (url != null) widget.runtime.onNativeNavigation(url);
          _syncHistory();
        },
        onUpdateVisitedHistory: (controller, url, isReload) {
          if (url != null) widget.runtime.onNativeNavigation(url);
          _syncHistory();
        },
        onReceivedError: (controller, request, error) {},
        shouldOverrideUrlLoading: (controller, action) async {
          final uri = action.request.url;
          if (uri == null) return NavigationActionPolicy.ALLOW;
          if (ObservePolicy.decideNavigation(uri) == NavDecision.openExternal) {
            await _openExternal(uri);
            return NavigationActionPolicy.CANCEL;
          }
          // Re-seed GM value snapshots before allowing navigation to proceed,
          // so the destination page's document-start/end scripts see the
          // latest persisted GM_setValue writes instead of the snapshot baked
          // in when this UserScript was first registered.
          await widget.runtime.refreshGmSnapshots(
            enabledScripts: widget.enabledUserScripts,
            valueStore: widget.gmValueStore,
          );
          widget.runtime.onNativeNavigation(uri);
          return NavigationActionPolicy.ALLOW;
        },
        shouldInterceptFetchRequest: (controller, request) async => request,
        shouldInterceptAjaxRequest: (controller, request) async => request,
        shouldInterceptRequest: (controller, request) async =>
            ObservePolicy.observeOnlyResourceResponse(),
        onConsoleMessage: (controller, message) {
          widget.runtime.onNativeConsole(message);
        },
      ),
    );
  }
}
