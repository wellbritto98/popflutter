import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';

import 'app_shell.dart';
import 'app_wiring.dart';
import 'autologin/auto_login_menu_item.dart';
import 'autologin/auto_login_notifications.dart';
import 'autologin/auto_login_screen.dart';
import 'autologin/auto_login_status_snackbar.dart';
import 'background/background_status.dart';
import 'debug_overlay.dart';
import 'gm/gm_menu_registry.dart';
import 'gm/gm_notification_overlay.dart';
import 'language/language_menu_item.dart';
import 'language/language_selector.dart';
import 'menu/app_menu_registry.dart';
import 'menu/debug_menu_item.dart';
import 'menu/gm_menu_command_item.dart';
import 'userscripts/userscripts_menu_item.dart';
import 'userscripts/userscripts_screen.dart';

class PopmundoApp extends StatelessWidget {
  const PopmundoApp({super.key, required this.wiring});

  /// Everything non-UI, already assembled in `main.dart`.
  final AppWiring wiring;

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
      home: PopmundoHome(wiring: wiring),
    );
  }
}

/// The shell. Owns only what genuinely needs a widget: the lifecycle observer,
/// the `BuildContext`-bound reactions (SnackBar, `Navigator`, dialogs), and the
/// debug panel's visibility toggle. Every collaborator lives in [AppWiring].
class PopmundoHome extends StatefulWidget {
  const PopmundoHome({super.key, required this.wiring});

  final AppWiring wiring;

  @override
  State<PopmundoHome> createState() => _PopmundoHomeState();
}

class _PopmundoHomeState extends State<PopmundoHome>
    with WidgetsBindingObserver {
  var _debugPanelVisible = false;

  StreamSubscription<AutoLoginStatus>? _autoLoginSub;

  AppWiring get _wiring => widget.wiring;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wiring.start();
    // Stays here, not in AppWiring: the handler needs a BuildContext to colour
    // the failure SnackBar.
    _autoLoginSub = _wiring.autoLoginStatus.listen((status) {
      unawaited(notifyAutoLoginResult(
        status: status,
        lifecycle:
            WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
        notificationService: _wiring.notificationService,
      ));
      // A status can land after the shell is gone; Theme.of on a defunct
      // element would throw. The old inline handler had the same gap.
      if (!mounted) return;
      showAutoLoginStatusSnackBar(
        PopmundoApp.scaffoldMessengerKey.currentState,
        status,
        errorColor: Theme.of(context).colorScheme.error,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLoginSub?.cancel();
    unawaited(_wiring.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _wiring.keepalive?.onLifecycle(state);
  }

  void _openUserScripts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserScriptsScreen(
          catalog: _wiring.catalog,
          importer: _wiring.importer,
          onApply: _wiring.applyUserScripts,
          onScriptDeleted: (scriptId) async {
            await _wiring.gmValueStore.clearForScript(scriptId);
            await _wiring.gmResourceStore.clearForScript(scriptId);
          },
        ),
      ),
    );
  }

  void _openAutoLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AutoLoginScreen(
          settingsStore: _wiring.settingsStore,
          secretStore: _wiring.secretStore,
        ),
      ),
    );
  }

  void _openLanguage() => unawaited(showLanguageDialog(context));

  @override
  Widget build(BuildContext context) {
    // GmMenuRegistry is already a ChangeNotifier, so the drawer listens to it
    // directly; `child` keeps the body out of that rebuild.
    return ListenableBuilder(
      listenable: _wiring.gmMenuRegistry,
      builder: (context, child) => AppShell(
        items: buildAppMenuItems(
          items: [
            autoLoginMenuItem(onTap: _openAutoLogin),
            userscriptsMenuItem(onTap: _openUserScripts),
            languageMenuItem(onTap: _openLanguage),
          ],
          debugItem: debugMenuItem(
            onTap: () => setState(() => _debugPanelVisible = true),
          ),
        ),
        gmMenuCommands: [
          for (final cmd in _wiring.gmMenuRegistry.commands)
            GmMenuCommandItem(
              scriptId: cmd.scriptId,
              commandId: cmd.commandId,
              caption: cmd.caption,
            ),
        ],
        onGmMenuCommand: (cmd) => unawaited(
          _wiring.gmHostHandler.onMenuCommandTapped(
            GmMenuCommand(
              scriptId: cmd.scriptId,
              commandId: cmd.commandId,
              caption: cmd.caption,
            ),
          ),
        ),
        body: child!,
      ),
      child: SafeArea(
        child: ValueListenableBuilder<UserscriptsState>(
          valueListenable: _wiring.userscripts,
          builder: (context, scripts, _) => !scripts.ready
              ? const Center(child: CircularProgressIndicator())
              : GmNotificationOverlay(
                  controller: _wiring.gmNotificationController,
                  onTap: (n) =>
                      unawaited(_wiring.gmHostHandler.onNotificationTapped(n)),
                  child: ValueListenableBuilder<List<CookieSummary>>(
                    valueListenable: _wiring.cookieWatcher.cookies,
                    // The WebView must not rebuild just because a cookie or a
                    // background-status tick changed.
                    child: PopmundoWebView(
                      runtime: _wiring.runtime,
                      gmValueStore: _wiring.gmValueStore,
                      enabledUserScripts: scripts.enabled,
                    ),
                    builder: (context, cookies, webView) =>
                        _debugOverlay(cookies: cookies, child: webView!),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _debugOverlay({
    required List<CookieSummary> cookies,
    required Widget child,
  }) {
    DebugOverlay overlay(BackgroundStatus? status) => DebugOverlay(
      host: _wiring.runtime.host,
      events: _wiring.runtime.events,
      evaluate: _wiring.runtime.evaluate,
      cookies: cookies,
      backgroundStatus: status,
      notificationService: _wiring.notificationService,
      visible: _debugPanelVisible,
      onClose: () => setState(() => _debugPanelVisible = false),
      child: child,
    );

    // keepalive is optional; without it there is no status to listen to.
    final status = _wiring.backgroundStatus;
    if (status == null) return overlay(null);
    return ValueListenableBuilder<BackgroundStatus>(
      valueListenable: status,
      builder: (context, value, _) => overlay(value),
    );
  }
}
