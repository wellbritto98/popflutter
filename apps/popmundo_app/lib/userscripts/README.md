# userscripts (`popmundo_app`)

UI e HTTP de download de UserScripts. Catálogo/parser: `popmundo_utils`. Injector: `popmundo_webview`. AD-010.

## Objetivo

Importar `.user.js` por URL, listar, toggle, apagar, e pedir ao runtime para sincronizar grupos nativos.

## Responsabilidade principal

HTTP **não** TimedFetch (scripts podem ser origin de terceiros). Após delete, limpar `GmValueStore` / `GmResourceStore` daquele id.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `userscripts_screen.dart` | Lista, import, enable, delete |
| `userscript_http.dart` | `fetchUserScriptUrl` / `fetchUserScriptBytes`; teto `GmConnectPolicy.maxResourceBytes`; também `GmExternalHttpClient` para XHR GM de terceiros |

`PopmundoHome._applyUserScripts` chama `runtime.syncUserScripts` e trata `PopmundoRuntimeException` se a WebView ainda não attachou.

## Dependências

`UserScriptCatalog`, `UserScriptImporter`, `dart:io` HttpClient.

## Relacionados

Item `userscripts` no registry; GM host; builtins `hooks.js`/`helpers.js` nunca removidos.

## Pontos de entrada

`_openUserScripts()` em `app.dart`. Reload da página após sync (comportamento do injector).

## Observações e débitos

- Erros de import podem aparecer em inglês no snackbar (trade-off AD-014).
- Testes: `test/userscripts_screen_test.dart`. Patrol: `integration_test/userscripts_test.dart` (prefs/canal, **sem** jogo).
