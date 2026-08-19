# assets/js (`popmundo_webview`)

Scripts injetados em toda página Popmundo (builtins). Não são UserScripts do jogador.

## Objetivo

Observar fetch/XHR/console, expor `window.__popmundo.fetch` / helpers DOM / `gmReply`, e bufferizar mensagens até o bridge Flutter existir.

## Responsabilidade principal

Rodar **na página**. Não decide política de interceptação (observe-only é no Dart).

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `hooks.js` | Wrap `fetch`/`XMLHttpRequest`/`console.*`; fila até `flutterInAppWebViewPlatformReady`; `callHandler('popmundo')`; `__popmundo.fetch`; `__popmundo.gmReply` (menuClick, notificationClick, callbacks XHR) |
| `helpers.js` | `getMyID` (`div.idHolder`), `getMyName` (h2 char box), `createNotification` (`#notifications`), `querySingle`/`queryAll`/`xpathSingle`, `applyScoringNumbers` / `applyBarPercentage` |

`user_scripts.dart`: hooks = `AT_DOCUMENT_START`, helpers = `AT_DOCUMENT_END`.

## Dependências

Canal único `'popmundo'`. Body capturado: texto truncado 32 KiB; binário omitido (`bodyOmitted`).

## Relacionados

`PopmundoJsBridge`, facades em `popmundo_utils`, shim GM (prelude separado por script, não estes arquivos).

## Pontos de entrada

`window.__popmundo.*` após injeção. Dart não edita estes arquivos em runtime.

## Fluxos

Primeiro paint → mensagens na `queue` → evento platform ready → flush + `{type:'ready'}`.

## Arquivos críticos

`hooks.js` — se `gmReply` ou `fetch` quebrarem, TimedFetch e GM host param.

## Observações e débitos

- Seletores de `helpers.js` são acoplamento ao HTML do jogo (o time não controla).
- Comentário em `hooks.js` ainda menciona `redirect: 'manual'`; o Auto Login vigente não usa esse modo no handshake (AD-018).
