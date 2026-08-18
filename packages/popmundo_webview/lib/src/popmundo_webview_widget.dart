import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'in_app_runtime.dart';
import 'user_scripts.dart';
import 'userscript_injector.dart';
import 'web_settings.dart';

class PopmundoWebView extends StatefulWidget {
  const PopmundoWebView({
    super.key,
    required this.runtime,
    this.initialUrl = HostTracker.defaultOrigin,
    this.launchExternal,
    this.enabledUserScripts = const [],
  });

  final InAppPopmundoRuntime runtime;
  final String initialUrl;
  final Future<void> Function(Uri uri)? launchExternal;

  /// Catalog entries with `enabled == true` merged into [initialUserScripts].
  final List<InstalledUserScript> enabledUserScripts;

  @override
  State<PopmundoWebView> createState() => _PopmundoWebViewState();
}

class _PopmundoWebViewState extends State<PopmundoWebView> {
  UnmodifiableListView<UserScript>? _scripts;

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
    final merged = UserScriptInjector.mergeInitial(
      builtin: builtin,
      enabled: widget.enabledUserScripts,
    );
    if (!mounted) return;
    setState(() => _scripts = merged);
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

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: PopmundoWebSettings.defaults(),
      initialUserScripts: scripts,
      onWebViewCreated: widget.runtime.attach,
      onLoadStart: (controller, url) {
        if (url != null) widget.runtime.onNativeNavigation(url);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) widget.runtime.onNativeNavigation(url);
      },
      onReceivedError: (controller, request, error) {},
      shouldOverrideUrlLoading: (controller, action) async {
        final uri = action.request.url;
        if (uri == null) return NavigationActionPolicy.ALLOW;
        if (ObservePolicy.decideNavigation(uri) == NavDecision.openExternal) {
          await _openExternal(uri);
          return NavigationActionPolicy.CANCEL;
        }
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
    );
  }
}
