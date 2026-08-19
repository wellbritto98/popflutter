# gm (`popmundo_app`)

Lado **host** do polyfill Greasemonkey. Prelude JS: `popmundo_utils` `UserScriptGmShim`. Canal: `type: 'gm'`. AD-016.

## Objetivo

Executar as APIs GM que precisam de plataforma: clipboard, browser externo, banner, menu do sidebar, XHR, resource URL.

## Responsabilidade principal

`GmHostHandler.handle(GmCallEvent)` e estado de UI (comandos + notificações). Persistência de values/resources é nos stores de utils.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `gm_host_handler.dart` | `setClipboard`, `openInTab` (`url_launcher`), `notification`, `registerMenuCommand`, `getResourceUrl`, `xmlHttpRequest` |
| `gm_menu_registry.dart` | Lista dinâmica; `clear()` na navegação |
| `gm_notification_overlay.dart` | Banner sobre o WebView; tap → `gmReply` notificationClick |

XHR: URI Popmundo → `TimedFetch` (`useCache: false`); demais → `HttpClient` **sem** cookies do jogo; `@connect` via `GmConnectPolicy`.

## Dependências

`popmundo_utils` (TimedFetch, stores, policy), `popmundo_webview` (evaluate `gmReply`), `url_launcher`, `Clipboard`.

HTTP de userscript download: `../userscripts/userscript_http.dart` (`GmExternalHttpClient` no mesmo arquivo que o GET de import).

## Relacionados

`AppSidebar` seção GM; `hooks.js` `gmReply`.

## Pontos de entrada

`PopmundoHome` assina `runtime.events.gmCall`.

## Observações e débitos

- `openInTab` ignora falha de `launchUrl` (fire-and-forget, como upstream).
- Menu commands somem a cada navegação (re-registro cabe ao script).
- Sem `validation.md` da feature no `.specs/`.
