# popmundo_app

> Análise do código deste app. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Shell Flutter (Android + iOS) que compõe `popmundo_utils` + `popmundo_webview` num app instalável: jogo em tela cheia, sessão persistente, Auto Login, UserScripts/GM, i18n EN/PT, keepalive e overlay de debug.

## Responsabilidade principal

**Composition root** — único lugar que instancia `InAppPopmundoRuntime`, `SharedPreferencesStore`, `FlutterSecureSecretStore` e `BackgroundKeepalive`. Hospeda UI nativa; parsing/throttle ficam nos packages.

## Funcionalidades existentes

| Área | Arquivos | Função |
| ---- | -------- | ------ |
| Boot | `lib/main.dart` | `EasyLocalization`, `initCommunicationPort`, prefs, keepalive, `runApp` |
| Shell | `lib/app.dart`, `app_shell.dart` | `MaterialApp`, `PopmundoHome`, `PopmundoScope`, wiring Auto Login/GM/catalog |
| Menu | `lib/menu/` | [README](lib/menu/README.md) |
| Debug | `lib/debug_overlay.dart` | Painel controlado; cookies name@domain; status do FGS |
| Prefs | `lib/prefs_store.dart` | `KeyValueStore` via `shared_preferences` |
| Auto Login UI | `lib/autologin/` | [README](lib/autologin/README.md) |
| UserScripts UI | `lib/userscripts/` | [README](lib/userscripts/README.md) |
| GM host | `lib/gm/` | [README](lib/gm/README.md) |
| Keepalive | `lib/background/` | [README](lib/background/README.md) |
| Idioma | `lib/language/`, `lib/l10n.dart` | [README](lib/language/README.md) |
| i18n assets | `assets/translations/{en,pt}.json` | Strings de release |
| Patrol | `integration_test/` | [README](integration_test/README.md) |

## Dependências internas e externas

- **Internas:** `popmundo_utils`, `popmundo_webview` (`path:`).
- **Externas:** `easy_localization`, `shared_preferences`, `flutter_secure_storage`, `flutter_inappwebview` (cookies no overlay), `flutter_foreground_task`, `url_launcher` (`GM.openInTab`), `cupertino_icons`. Dev: `flutter_lints`, `patrol`.
- **Não depende de** um backend próprio.

## Módulos relacionados

- `popmundo_webview` — runtime, widget, cookie sink, injector.
- `popmundo_utils` — controller Auto Login, catalog, eventos, TimedFetch.

## Pontos de entrada

- `lib/main.dart` — binário Flutter.
- `android/app/src/main/AndroidManifest.xml` — INTERNET, FGS `dataSync`, `POST_NOTIFICATIONS`, battery, `stopWithTask="false"`.
- `ios/Runner/Info.plist` — ATS `popmundo.com` + subdomains; `UIBackgroundModes: fetch`; localizações `en`/`pt`.

## Fluxos importantes

- **Boot:** prefs + EasyLocalization + porta FGS antes do primeiro frame. `PopmundoHome` espera `_bootstrapReady` (lista do catálogo) antes de montar a WebView.
- **Auto Login:** `autoLogin.start()` no `initState`; snackbars via `scaffoldMessengerKey`. Heartbeat 60 s usa o mesmo `InAppCookieSink` como source.
- **UserScripts:** `syncUserScripts` após import/toggle; delete limpa GM values/resources.
- **Navegação:** atualiza cookies do overlay e `gmMenuRegistry.clear()`.
- **Lifecycle:** `didChangeAppLifecycleState` → keepalive.

## Arquivos críticos

- `lib/main.dart` — composition + FGS port (Patrol precisa recriar isso no harness).
- `lib/app.dart` — acoplamento `CookieManager`; wiring de todas as features de shell.
- `lib/menu/app_menu_registry.dart` — extensão de itens nativos.
- Manifest / Info.plist — FGS e ATS.

## Observações técnicas e débitos

- `app.dart` importa `flutter_inappwebview` direto (cookies do overlay) — exceção à regra “só o adapter fala com o plugin”.
- `url_launcher` também no app (`GmHostHandler`), não só no webview.
- `PopmundoScope.of` **não tem call sites**.
- `DebugOverlay` assina network/console sem cancelar `StreamSubscription` no `dispose` (débito já registrado no spec do sidebar).
- Overlay e exceções dos packages permanecem em inglês (AD-014).
- Testes widget/unit em `test/`. Device: `integration_test/` (nunca `PopmundoApp`).

```bash
cd apps/popmundo_app && flutter test
flutter analyze apps/popmundo_app integration_test
```
