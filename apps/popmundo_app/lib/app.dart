import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'debug_overlay.dart';

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
  late final storage = StorageService(widget.store);

  @override
  void initState() {
    super.initState();
    widget.runtime.events.navigation.listen((_) => _refreshCookies());
    _refreshCookies();
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

  @override
  Widget build(BuildContext context) {
    return PopmundoScope(
      runtime: widget.runtime,
      storage: storage,
      child: Scaffold(
        body: SafeArea(
          child: DebugOverlay(
            host: widget.runtime.host,
            events: widget.runtime.events,
            evaluate: widget.runtime.evaluate,
            cookies: _cookies,
            child: PopmundoWebView(runtime: widget.runtime),
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
