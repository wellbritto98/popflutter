# popmundo_webview

> Gerado por análise do código-fonte real deste pacote. Ver também `docs/ARQUITETURA.md` e `docs/OBJETIVO.md` na raiz do repositório para a visão de sistema completa.

## Objetivo do módulo

Pacote Flutter que adapta `flutter_inappwebview` 6.x ao contrato `PopmundoRuntime` de `popmundo_utils`. É a camada que sabe **como** renderizar o jogo em WebView, injetar scripts, interceptar eventos (somente-observação) e trocar mensagens com a página via JS bridge.

## Responsabilidade principal

Implementar `PopmundoRuntime` (`InAppPopmundoRuntime`) e expor o widget `PopmundoWebView`, mantendo toda regra de negócio delegada a `popmundo_utils` — este pacote não decide host sticky, cache ou parsing, apenas transporta dados entre a página web e o contrato Dart.

## Funcionalidades existentes

| Arquivo | Funcionalidade |
| ------- | --------------- |
| `src/in_app_runtime.dart` | `InAppPopmundoRuntime` — implementa `PopmundoRuntime`: `evaluate`, `fetchInPage` (via `callAsyncJavaScript` chamando `window.__popmundo.fetch`), `waitUntilReady` (timeout 30 s), `attach(controller)` (registra o handler JS), `onNativeNavigation`, `onNativeConsole` |
| `src/js_bridge.dart` | `PopmundoJsBridge` — roteia mensagens `{type, payload}` recebidas do handler `'popmundo'`: `ready` (completa prontidão), `network` (emite `NetworkEvent`), `console` (emite `ConsoleEvent`) |
| `src/popmundo_webview_widget.dart` | `PopmundoWebView` — `StatefulWidget` que monta o `InAppWebView`: carrega `UserScripts`, aplica settings, liga callbacks de navegação/console/interceptação, abre links externos via `url_launcher` (ou `launchExternal` customizado) |
| `src/user_scripts.dart` | `PopmundoUserScripts.load()` — carrega `hooks.js` (AT_DOCUMENT_START) e `helpers.js` (AT_DOCUMENT_END) dos assets do pacote, com fallback de path |
| `src/web_settings.dart` | `PopmundoWebSettings.defaults()` — `incognito: false`, `javaScriptEnabled: true`, `useShouldOverrideUrlLoading/InterceptAjax/InterceptFetch: true`, `isInspectable: true` |
| `assets/js/hooks.js` | Intercepta `fetch`/`XMLHttpRequest`/`console.*` na página, captura corpo (truncado em 32 KiB, binário omitido), enfileira mensagens até o bridge Flutter estar pronto, expõe `window.__popmundo.fetch` |
| `assets/js/helpers.js` | Define `window.__popmundo.{getMyID, getMyName, createNotification, querySingle, queryAll, xpathSingle, applyScoringNumbers, applyBarPercentage}` |
| `popmundo_webview.dart` | Barrel file |

## Dependências internas e externas

- **Internas**: `popmundo_utils` (path) — usa `PopmundoRuntime`, `HostTracker`, `PopmundoEventBus`, `NetworkEvent`, `ConsoleEvent`, `NavigationEvent`, `ObservePolicy`, `NavDecision`, `InPageFetchResult`, `PopmundoRuntimeException`.
- **Externas (pub.dev)**: `flutter_inappwebview: ^6.1.5` (WebView, cookies, UserScripts, JS handler), `url_launcher: ^6.3.1` (links externos), `flutter` SDK.
- **Consumido por**: `apps/popmundo_app` (via `path:`).

## Módulos relacionados

- `packages/popmundo_utils` — porta que este pacote implementa; qualquer novo campo em `PopmundoRuntime` precisa de implementação aqui.
- `apps/popmundo_app` — instancia `InAppPopmundoRuntime()` no composition root (`main.dart`) e usa `PopmundoWebView` dentro do shell.

## Pontos de entrada

- `lib/popmundo_webview.dart` — export público.
- `InAppPopmundoRuntime()` — construtor usado pelo app para criar o runtime concreto.
- `PopmundoWebView(runtime: ...)` — widget consumido pelo app.

## Fluxos importantes

- **Handshake do bridge**: `attach(controller)` registra `addJavaScriptHandler('popmundo', bridge.handleArguments)`; do lado JS, `hooks.js` enfileira mensagens até `flutterInAppWebViewPlatformReady`, depois drena a fila e envia `{type: 'ready'}`, que completa o `Completer<void> _ready` interno.
- **Interceptação observe-only**: `shouldInterceptFetchRequest`/`shouldInterceptAjaxRequest` sempre devolvem o `request` recebido; `shouldInterceptRequest` sempre devolve `ObservePolicy.observeOnlyResourceResponse()` (`null`) — nenhum desses callbacks deve começar a devolver um objeto substituto.
- **Navegação externa**: `shouldOverrideUrlLoading` consulta `ObservePolicy.decideNavigation(uri)`; se `openExternal`, cancela a navegação no WebView e abre via `url_launcher` (ou callback customizado `launchExternal`), sem nunca deixar a URL externa substituir a sessão do jogo.
- **fetchInPage**: usa `callAsyncJavaScript` (não `evaluateJavascript`) para poder `await` um `fetch` assíncrono na página e devolver `{ok, status, text}` já decodificado.

## Arquivos críticos

- `src/in_app_runtime.dart` — ponto único de tradução entre `flutter_inappwebview` e o contrato `PopmundoRuntime`; bug aqui quebra toda chamada Dart→página e página→Dart.
- `assets/js/hooks.js` — se o hook de `fetch`/`XHR` regredir, o stream de rede do overlay e qualquer helper que dependa de `window.__popmundo.fetch` param de funcionar; também é o único lugar que trunca/oculta corpo binário antes de mandar para Dart.
- `src/web_settings.dart` — muda o comportamento de segurança/cache/incognito de toda sessão; qualquer alteração aqui é sensível (ex.: ligar `incognito` quebraria a persistência de sessão exigida pelo produto).

## Observações técnicas e débitos identificados

- `isInspectable: true` está fixo em `PopmundoWebSettings.defaults()` sem diferenciar debug/release (`web_settings.dart:12`) — WebView fica inspecionável via DevTools também em builds de release. **Hipótese**: pode ser intencional, já que o app é descrito como ferramenta de desenvolvedor em `.specs/features/popmundo-wrapper/context.md`, mas não há confirmação explícita disso no spec para builds de produção.
- `PopmundoUserScripts._load` tenta `rootBundle.loadString('packages/popmundo_webview/$relative')` e, em caso de erro, cai para `rootBundle.loadString(relative)` sem log do motivo da primeira falha (`user_scripts.dart:10-16`) — comportamento correto (permite rodar dentro do próprio pacote em testes), mas mascara silenciosamente qualquer outro erro de asset.
- `InAppPopmundoRuntime.evaluate`/`fetchInPage` lançam `PopmundoRuntimeException('WebView not attached')` se chamados antes de `attach` — não há guard/estado explícito de "não inicializado" exposto fora da exceção.
- Este pacote não tem testes de app real além de `test/popmundo_webview_test.dart`; cobertura de fluxo completo depende dos testes de widget do overlay em `apps/popmundo_app/test/`.
