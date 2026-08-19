# GM Host APIs Context

**Gathered:** 2026-08-19
**Spec:** `.specs/features/gm-host-apis/spec.md`
**Status:** Ready for implementation

## Feature Boundary

Completar o polyfill Greasemonkey 4 com as 6 APIs host faltantes, mantendo o Core existente intacto.

## Implementation Decisions

### Canal JS↔Dart

- Novo `type: 'gm'` no handler `popmundo`; respostas via `window.__popmundo.gmReply(payload)`.
- Callbacks por `callId` em mapas globais (`__gmCallbacks`, `__gmMenuCommands`, `__gmNotifCallbacks`).

### openInTab

- Sempre `LaunchMode.externalApplication` — nunca navega a WebView.

### xmlHttpRequest

- Sanitizer no JS (como GM4): funções → flag, sem `context`, URL absoluta.
- Popmundo → TimedFetch; terceiros → HttpClient; `@connect` allowlist via `GmConnectPolicy`.

### registerMenuCommand

- Itens dinâmicos abaixo dos estáticos no drawer; `GmMenuRegistry` limpo em cada `NavigationEvent`.

### notification

- `MaterialBanner` / overlay in-app acima do WebView; tap dispara `onclick` via `gmReply`.

### getResourceUrl

- Bytes persistidos no import; runtime devolve data URL; `GM_info.script.resources` mapeia name→url original.

### Agent's Discretion

- Split do gerador JS host em arquivo auxiliar se `userscript_gm_shim.dart` passar de 300 linhas.

## Deferred Ideas

- `GM.getResourceText`
- XHR abort/progress
