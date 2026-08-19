# popmundo_webview

> Análise do código deste pacote. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Pacote Flutter que adapta `flutter_inappwebview` 6.x ao contrato `PopmundoRuntime`. Sabe **como** renderizar o jogo, injetar scripts, observar eventos e sincronizar cookies do handshake nativo.

## Responsabilidade principal

Implementar o runtime e o widget `PopmundoWebView`. Regras (host, throttle, parsing, catálogo) ficam em `popmundo_utils`.

## Funcionalidades existentes

| Arquivo | Funcionalidade |
| ------- | -------------- |
| `src/in_app_runtime.dart` | `InAppPopmundoRuntime`: `evaluate`, `fetchInPage` (`callAsyncJavaScript` + `__popmundo.fetch`), `loadUrl`, `waitUntilReady` (30 s), `attach`, `syncUserScripts`, `refreshGmSnapshots`, navegação/console nativos |
| `src/js_bridge.dart` | Roteia `ready` \| `network` \| `console` \| `gmValue` \| `gm` |
| `src/popmundo_webview_widget.dart` | `InAppWebView` + builtins/catalog merge, intercept observe-only, links externos, `PopScope` / system-back |
| `src/user_scripts.dart` | Carrega `hooks.js` (DOCUMENT_START) e `helpers.js` (DOCUMENT_END) |
| `src/userscript_injector.dart` | `UserScript` nativo `groupName: userscript:<id>`; sync add/remove + reload; **não** expõe wipe-all |
| `src/in_app_cookie_sink.dart` | `CookieSink` + `CookieSource` → `CookieManager` (write host-only; read `getCookies` → `GameCookie`) |
| `src/webview_back_navigation.dart` | `WebViewBackHandler`: back no histórico ou `allowExit` |
| `src/web_settings.dart` | `incognito: false`, JS on, intercept fetch/ajax, `isInspectable: true` |
| `assets/js/` | Ver [README JS](assets/js/README.md) |

## Dependências internas e externas

- **Internas:** `popmundo_utils` (path).
- **Externas:** `flutter_inappwebview: ^6.1.5`, `url_launcher: ^6.3.1`, Flutter SDK.
- **Consumido por:** `apps/popmundo_app`.

## Módulos relacionados

- `popmundo_utils` — porta + `CookieSink`/`CookieSource` + catalog/shim.
- `popmundo_app` — instancia o runtime, passa `gmValueStore` e scripts enabled, implementa `GmHostHandler`.

## Pontos de entrada

- `lib/popmundo_webview.dart` — barrel.
- `InAppPopmundoRuntime()` — composition root do app.
- `PopmundoWebView(runtime:, gmValueStore:, enabledUserScripts:)` — widget.
- `InAppCookieSink()` — wired no `AutoLoginController` como sink e source.

## Fluxos importantes

- **Handshake JS:** `attach` registra handler `'popmundo'`; `hooks.js` envia `{type:'ready'}` após `flutterInAppWebViewPlatformReady`.
- **Observe-only:** intercept callbacks devolvem o request original ou `null`.
- **Navegação externa:** `ObservePolicy.decideNavigation` → `url_launcher` (ou `launchExternal`).
- **UserScripts:** merge inicial builtins + enabled; mudanças em runtime via `sync` + `reload()`. Nunca `removeAllUserScripts`.
- **Back:** `PopScope.canPop` = `!webViewCanGoBack`; senão `goBack()`.

## Arquivos críticos

- `src/in_app_runtime.dart` — toda tradução plugin ↔ contrato.
- `assets/js/hooks.js` — stream de rede + `gmReply` + `__popmundo.fetch`.
- `src/web_settings.dart` — incognito/inspectable.
- `src/in_app_cookie_sink.dart` — sessão do Auto Login na WebView.
- `src/userscript_injector.dart` — isolamento vs. builtins.

## Observações técnicas e débitos

- `isInspectable: true` sem `kReleaseMode`. **Hipótese:** intencional (ferramenta de desenvolvedor).
- Fallback de path em `user_scripts.dart` mascara o erro do primeiro `loadString`.
- `evaluate`/`fetchInPage`/`loadUrl` lançam `WebView not attached` antes de `attach`.
- Testes: `test/popmundo_webview_test.dart`, `in_app_cookie_sink_test.dart`, `userscript_injector_test.dart`, `webview_back_navigation_test.dart`. Sem WebView real / site ao vivo.

```bash
cd packages/popmundo_webview && flutter test
```
