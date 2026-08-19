# userscript (`popmundo_utils`)

Parser, catálogo persistido e polyfill GM (Core + Host bindings JS). Specs: `userscript-manager`, `gm-host-apis`. AD-010, AD-016.

## Objetivo

Tornar `.user.js` instaláveis e executáveis com o subconjunto GM que o parser aceita, sem Flutter.

## Responsabilidade principal

Validar headers, persistir catálogo/`GM_setValue`/`@resource`, gerar o prelude JS. Injeção nativa e APIs host (clipboard, XHR real) ficam no webview/app.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `userscript_parser.dart` | Bloco `==UserScript==`; grants allowlist Core+Host; `@resource`/`@connect` não rejeitam import |
| `userscript_catalog.dart` | `userscripts.v1`; `groupName: userscript:<id>` |
| `userscript_importer.dart` | Download source/`@require`/`@resource` via HTTP injetado (não TimedFetch) |
| `userscript_gm_shim.dart` | Closure por script; `hasValueGrant` para refresh de snapshot |
| `userscript_gm_value_bindings.dart` | `GM_getValue` síncrono a partir do snapshot |
| `userscript_gm_host_bindings.dart` | Stubs que `post({type:'gm',...})` e esperam `gmReply` |
| `gm_value_store.dart` | `userscript:<id>:gmvalues` |
| `gm_resource_store.dart` | `userscript:<id>:gmresources` |
| `gm_connect_policy.dart` | Allowlist `@connect` em runtime; teto de bytes de resource |

## Dependências

- Internas: `KeyValueStore`, `events` (`GmValueEvent`).
- Relacionados: `UserScriptInjector` (webview); `GmHostHandler` (app); HTTP em `userscript_http.dart`.

## Pontos de entrada

`UserScriptParser.parse`, `UserScriptCatalog`, `UserScriptImporter`, `UserScriptGmShim.build`.

## Fluxos

Import → parse (grant desconhecido = erro) → persist catalog → injector envolve shim + source → página chama GM → `gmValue`/`gm` no bridge.

`@connect` que não casa **não** bloqueia import; XHR falha em runtime (`Connect denied`).

## Arquivos críticos

`userscript_parser.dart` (`_allowedGrants`), `userscript_gm_shim.dart`, `gm_connect_policy.dart`.

## Observações e débitos

- Grants fora da allowlist impedem o import (não há polyfill genérico).
- `GM.getResourceText`, abort/progress de XHR: fora de escopo do spec host.
- Feature `gm-host-apis` sem `validation.md` no `.specs/`.
- Todos os scripts compartilham `ContentWorld.PAGE`; o shim isola por closure.
