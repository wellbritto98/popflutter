# GM Host APIs Specification

## Problem Statement

O polyfill GM "Core" (`GM_getValue`, `GM.info`, etc.) já existe, mas scripts Greasemonkey/Tampermonkey reais dependem de APIs "host" (`GM.xmlHttpRequest`, `GM.openInTab`, …) que o parser ainda rejeita no import. Sem elas, a maioria dos `.user.js` de terceiros continua irimportável.

## Goals

- [ ] Aceitar `@grant` host (formas `GM_*` e `GM.*`) e headers `@resource` / `@connect`
- [ ] Implementar as 6 APIs host: `getResourceUrl`, `notification`, `openInTab`, `registerMenuCommand`, `setClipboard`, `xmlHttpRequest`
- [ ] Manter AD-003 (observe-only) e AD-002 (`popmundo_utils` Flutter-free)

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| `GM.getResourceText` | Diferido (GM4 TODO upstream) |
| XHR `abort()`, upload progress, `ftp:` | v1 simplificada |
| `accessKey` em menu commands | Mobile sem atalho de teclado |
| Re-import / auto-update de resources | Fora do userscript-manager MVP |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| `GM.openInTab` | Navegador do sistema via `url_launcher` | WebView único | y |
| `GM.xmlHttpRequest` Popmundo | `TimedFetch` in-page | Cookies + throttle AD-006 | y |
| `GM.xmlHttpRequest` terceiros | `HttpClient` nativo sem cookies do jogo | Escapa CORS | y |
| `@connect` | Allowlist runtime; import ok sem match → `onerror` | GM semantics | y |
| `GM.notification` | Banner in-app sobre o WebView | Não compete com FGS AD-012 | y |
| `GM.registerMenuCommand` | Seção dinâmica no sidebar; limpa a cada navegação | AD-009 | y |
| Resource size cap | 1 MiB por `@resource`; import falha se exceder | Evita blob gigante | y (agent) |

**Open questions:** none.

## User Stories

### P1: Importar scripts com grants host ⭐ MVP

**Acceptance Criteria**:

1. WHEN um `.user.js` declara `@grant GM.xmlHttpRequest` (ou equivalente moderno) THEN o import SHALL succeed.
2. WHEN `@resource name url` está presente THEN o importer SHALL baixar e persistir bytes (≤ 1 MiB).
3. WHEN `@connect host` está presente THEN o header SHALL ser aceito no parse.

### P1: GM host APIs funcionais

**Acceptance Criteria**:

1. WHEN `GM.setClipboard(text)` é chamado THEN o texto SHALL aparecer no clipboard nativo.
2. WHEN `GM.openInTab(url)` é chamado THEN o SO SHALL abrir a URL no navegador externo.
3. WHEN `GM.registerMenuCommand(caption, fn)` é chamado THEN o caption SHALL aparecer no sidebar até a próxima navegação.
4. WHEN `GM.notification({text, onclick})` é exibida e o usuário toca THEN `onclick` SHALL executar no JS da página.
5. WHEN `GM.getResourceUrl(name)` é chamado THEN SHALL resolver para um object URL/data URL do resource persistido.
6. WHEN `GM.xmlHttpRequest` alcança `*.popmundo.com` THEN SHALL usar TimedFetch; terceiros permitidos por `@connect` usam HTTP nativo.

6. WHEN `GM.setValue`/`GM.deleteValue` mutates storage THEN registered `GM_addValueChangeListener` callbacks SHALL fire with `(key, oldValue, newValue, remote=false)`.

## Requirement Traceability

| ID | Story | Status |
| ---- | ----- | ------ |
| GMH-01 | P1 import grants | Pending |
| GMH-02 | P1 setClipboard | Pending |
| GMH-03 | P1 openInTab | Pending |
| GMH-04 | P1 registerMenuCommand | Pending |
| GMH-05 | P1 notification | Pending |
| GMH-06 | P1 getResourceUrl | Pending |
| GMH-07 | P1 xmlHttpRequest | Pending |
| GMH-08 | P1 value change listeners | Pending |
