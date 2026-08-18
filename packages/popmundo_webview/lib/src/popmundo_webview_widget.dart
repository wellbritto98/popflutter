import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'in_app_runtime.dart';
import 'user_scripts.dart';
import 'web_settings.dart';

class PopmundoWebView extends StatefulWidget {
  const PopmundoWebView({
    super.key,
    required this.runtime,
    this.initialUrl = HostTracker.defaultOrigin,
    this.launchExternal,
  });

  final InAppPopmundoRuntime runtime;
  final String initialUrl;
  final Future<void> Function(Uri uri)? launchExternal;

  @override
  State<PopmundoWebView> createState() => _PopmundoWebViewState();
}

class _PopmundoWebViewState extends State<PopmundoWebView> {
  UnmodifiableListView<UserScript>? _scripts;

  @override
  void initState() {
    super.initState();
    PopmundoUserScripts.load().then((scripts) {
      if (mounted) setState(() => _scripts = scripts);
    });
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
