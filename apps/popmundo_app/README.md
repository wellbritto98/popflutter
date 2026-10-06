# popmundo_app

> Análise do código deste app. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Shell Flutter (Android + iOS) que compõe `popmundo_utils` + `popmundo_webview` num app instalável: jogo em tela cheia, sessão persistente, Auto Login, UserScripts/GM, i18n EN/PT, keepalive e overlay de debug.

## Responsabilidade principal

**Composition root** — `main.dart` monta um único `AppWiring` (único lugar que instancia `InAppPopmundoRuntime`, `SharedPreferencesStore`, `FlutterSecureSecretStore` e `BackgroundKeepalive`) e o entrega para a UI. Hospeda UI nativa; parsing/throttle ficam nos packages.

## Funcionalidades existentes

| Área | Arquivos | Função |
| ---- | -------- | ------ |
| Boot | `lib/main.dart` | `EasyLocalization`, `initCommunicationPort`, prefs, keepalive, monta `AppWiring`, `runApp` |
| Composition | `lib/app_wiring.dart` | `AppWiring` — dono dos 15 colaboradores não-UI (catalog, gmValueStore, gmResourceStore, gmMenuRegistry, gmNotificationController, settingsStore, timedFetch, importer, gmHostHandler, cookieJar, autoLogin, menuNotifications{Service,StateStore,Watcher,Bridge}) + `start()`/`dispose()`/`applyUserScripts()`/`connectHeadersFor()`, `ValueNotifier<UserscriptsState>` e `CookieWatcher` |
| Cookies (debug) | `lib/cookie_watcher.dart` | `CookieWatcher` — único import direto de `flutter_inappwebview` no app; lê `CookieManager` para o overlay |
| Shell | `lib/app.dart`, `app_shell.dart` | `MaterialApp`, `PopmundoHome` (lifecycle observer, subscription de `autoLoginStatus`, navegação/diálogos, visibilidade do painel de debug, `build`), wiring recebido via `AppWiring` |
| Menu | `lib/menu/` | [README](lib/menu/README.md) |
| Debug | `lib/debug_overlay.dart` | Painel controlado; cookies name@domain; status do FGS |
| Prefs | `lib/prefs_store.dart` | `KeyValueStore` via `shared_preferences` |
| Auto Login UI | `lib/autologin/` | [README](lib/autologin/README.md) |
| UserScripts UI | `lib/userscripts/` | [README](lib/userscripts/README.md) |
| GM host | `lib/gm/` | [README](lib/gm/README.md) |
| Keepalive | `lib/background/` | [README](lib/background/README.md) |
| Notificações | `lib/notifications/` | `NotificationService`/`LocalNotificationsService`/`FakeNotificationService` (`showNotification` genérico); botão manual `debug-send-notification` no overlay; `MenuNotificationsBridge` traduz `MenuNotificationsWatcher.newNotifications` (popmundo_utils) em notificações reais, uma por item novo do jogo, canal `popflutter_game_notifications_channel`; Auto Login em background usa notificação de resultado id 2 |
| Idioma | `lib/language/`, `lib/l10n.dart` | [README](lib/language/README.md) |
| i18n assets | `assets/translations/{en,pt}.json` | Strings de release |
| Patrol | `integration_test/` | [README](integration_test/README.md) |

## Dependências internas e externas

- **Internas:** `popmundo_utils`, `popmundo_webview` (`path:`).
- **Externas:** `easy_localization`, `shared_preferences`, `flutter_secure_storage`, `flutter_inappwebview` (cookies no overlay), `flutter_foreground_task`, `flutter_local_notifications` (só `LocalNotificationsService`), `url_launcher` (`GM.openInTab`), `cupertino_icons`. Dev: `flutter_lints`, `patrol`.
- **Não depende de** um backend próprio.

## Módulos relacionados

- `popmundo_webview` — runtime, widget, cookie sink, injector.
- `popmundo_utils` — controller Auto Login, catalog, eventos, TimedFetch.

## Pontos de entrada

- `lib/main.dart` — binário Flutter.
- `android/app/src/main/AndroidManifest.xml` — INTERNET, FGS `specialUse`, `POST_NOTIFICATIONS`, battery, `stopWithTask="false"`.
- `ios/Runner/Info.plist` — ATS `popmundo.com` + subdomains; `UIBackgroundModes: fetch`; localizações `en`/`pt`.

## Fluxos importantes

- **Boot:** prefs + EasyLocalization + porta FGS antes do primeiro frame. `AppWiring.start()` (chamado em `PopmundoHome.initState`) dispara `_bootstrap()`, que publica a lista do catálogo em `userscripts`; a WebView só monta quando `scripts.ready`.
- **Auto Login:** `AppWiring.start()` chama `autoLogin.start()`; a `_PopmundoHomeState` assina `wiring.autoLoginStatus` no `initState` e mostra os snackbars via `scaffoldMessengerKey` (precisa de `BuildContext` para colorir o erro, por isso fica no shell). Heartbeat 60 s usa o mesmo `InAppCookieSink` (`cookieJar` em `AppWiring`) como source.
- **UserScripts:** `AppWiring.applyUserScripts` chama `syncUserScripts` após import/toggle; delete limpa GM values/resources.
- **Navegação:** `AppWiring._onNavigation` limpa `gmMenuRegistry` e chama `cookieWatcher.refresh()`.
- **Lifecycle:** `didChangeAppLifecycleState` (no shell) → `wiring.keepalive?.onLifecycle`.
- **Notificação de teste:** `LocalNotificationsService().initialize()` roda antes do `runApp`; botão `debug-send-notification` pede permissão e mostra uma notificação fixa (id/canal fixos, negação/erro nunca derrubam o painel).
- **Notificações do jogo:** `main.dart` chama `requestPermission()` logo após `initialize()` (não depende mais do painel de debug); `AppWiring.start()`/`dispose()` iniciam e finalizam `menuNotificationsWatcher`/`menuNotificationsBridge`. Cada lote novo de `MenuNotificationsWatcher` resolve `Utils.getMyName()` uma vez e chama `showNotification` por item (id = hash do `UID`, `Url` guardado como `payload` para uso futuro — tap ainda não navega).

## Arquivos críticos

- `lib/main.dart` — composition + FGS port (Patrol precisa recriar isso no harness).
- `lib/app_wiring.dart` — dono de todos os colaboradores não-UI e seu lifecycle (`start`/`dispose`); mudar aqui afeta toda feature da shell.
- `lib/cookie_watcher.dart` — acoplamento `CookieManager`/`WebUri`.
- `lib/app.dart` — `PopmundoApp`/`PopmundoHome`; monta o `items:` da sidebar a partir dos `AppMenuItem` de cada feature.
- `lib/menu/app_menu_registry.dart` — ordenação + gate do item de debug.
- Manifest / Info.plist — FGS e ATS.

## Observações técnicas e débitos

- `cookie_watcher.dart` importa `flutter_inappwebview` direto (cookies do overlay) — exceção à regra “só o adapter fala com o plugin”; é o único arquivo do app com esse import.
- `url_launcher` também no app (`GmHostHandler`), não só no webview.
- `DebugOverlay` assina network/console sem cancelar `StreamSubscription` no `dispose` (débito já registrado no spec do sidebar).
- Overlay e exceções dos packages permanecem em inglês (AD-014).
- Testes widget/unit em `test/`. Device: `integration_test/` (nunca `PopmundoApp`).

```bash
cd apps/popmundo_app && flutter test
flutter analyze apps/popmundo_app integration_test
```


Manutenção contínua de sessão Android usa FGS specialUse com subtype declarado (AD-020). Force-stop, reboot e morte do processo encerram manutenção; distribuição Play exige revisão do caso de uso.
