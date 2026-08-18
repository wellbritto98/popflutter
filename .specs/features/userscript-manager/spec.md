# UserScript Manager Specification

## Problem Statement

O app já observa e injeta scripts internos (`hooks.js` / `helpers.js`) via InAppWebView `UserScript`, e o sidebar (`AD-009`) é o ponto de entrada nativo extensível. Falta um gerenciador para o jogador importar, ativar/desativar e remover UserScripts `.user.js` de terceiros — sem isso, qualquer customização de página exige rebuild do app.

## Goals

- [ ] O usuário importa um UserScript válido a partir de uma URL `.user.js`, com feedback visual
- [ ] O usuário lista, ativa/desativa e remove scripts persistidos
- [ ] Scripts habilitados são injetados via API `UserScript` do InAppWebView 6.x e aplicam-se após reload automático

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Editor de source / colar JS cru | Escopo é import por URL |
| Auto-update via `@updateURL` | Diferido; metadado pode ser guardado mas não usado |
| Polyfill Tampermonkey/Greasemonkey (`GM_*`, menu commands) | Headers `@grant` não-suportados rejeitam o import |
| i18n | Strings em inglês, como sidebar/debug |
| `removeAllUserScripts` | Apagaria scripts internos (AD-003) |
| Tema / paleta / tipografia custom | Usar `ThemeData` existente do app |
| Restrição extra a `*.popmundo.com` | Usuário assume o risco; sem sandbox de origem |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Entrada no sidebar | Item sempre visível (debug e release) | Pedido explícito | y |
| Tema | Material 3 existente (`colorSchemeSeed: Colors.deepPurple`) | Pedido explícito: tema padrão do sistema, sem modificar | y |
| Idioma da UI | Inglês | Consistente com sidebar/debug | y |
| Validação de headers | Honrar o que InAppWebView aplica; rejeitar headers/valores não honrados listando-os | Pedido explícito | y |
| Segurança / allowlist de hosts | Nenhuma — risco do usuário | Pedido explícito | y |
| Aplicação após mudança | Reload automático do WebView | Docs: add/remove só vale no próximo load; usuário escolheu auto-reload | y |
| Download HTTP | Fetcher Dart injetado (não TimedFetch) | AD-006 é throttle same-origin do jogo | y (agent) |
| Navegação para a tela | `Navigator.push` (WebView permanece na árvore) | Evita destruir o WebView | y (agent) |
| Dedup | Mesma `sourceUrl` → erro, não duplica | Implícito em catálogo estável | y (agent) |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Importar UserScript por URL ⭐ MVP

**User Story**: As a player, I want to paste a `.user.js` URL and import it so that page customizations apply without rebuilding the app.

**Why P1**: Sem import não há scripts gerenciáveis.

**Acceptance Criteria**:

1. WHEN the user opens the UserScripts screen from the sidebar THEN the system SHALL show a list of installed scripts (or an empty state with a clear add affordance).
2. WHEN the user submits an `http`/`https` URL whose path ends in `.user.js` THEN the system SHALL download the file, validate it, persist it enabled, inject it via `UserScript`, reload the WebView, and show a success SnackBar including the script `@name`.
3. WHEN the downloaded file lacks a `// ==UserScript==` … `// ==/UserScript==` block or lacks `@name` THEN the system SHALL reject the import, leave the catalog unchanged, and show an error SnackBar.
4. WHEN the file contains a header/value the app cannot honor (unsupported `@grant`, `@resource`, `@connect`, `@run-at context-menu`, unsupported `@sandbox`/`@inject-into`) THEN the system SHALL reject the import, leave the catalog unchanged, and show an error SnackBar listing the unsupported headers.
5. WHEN download fails (network/timeout/non-2xx) or any `@require` URL fails THEN the system SHALL reject the import with zero catalog writes and show an error SnackBar.
6. WHEN a script with the same `sourceUrl` is already installed THEN the system SHALL reject the import and show an error SnackBar (no duplicate).

**Independent Test**: Unit tests on parser + importer with fake HTTP; widget test on add dialog + SnackBar wiring with fake catalog.

---

### P1: Listar, ativar/desativar e remover

**User Story**: As a player, I want to toggle and delete installed userscripts so that I control what runs in the WebView.

**Why P1**: Gerenciar o ciclo de vida é o restante do MVP.

**Acceptance Criteria**:

1. WHEN installed scripts exist THEN the system SHALL render them in a `ListView` showing at least the script name and an enabled `Switch`/`SwitchListTile`.
2. WHEN the user toggles a script THEN the system SHALL persist the new `enabled` state, sync injection (add or remove by `groupName`), reload the WebView, and keep the list in sync.
3. WHEN the user taps delete THEN the system SHALL show a confirmation `AlertDialog`; only on confirm SHALL it remove the script from storage, remove its `UserScript` group, reload the WebView, and update the list.
4. WHEN the user cancels the delete dialog THEN the system SHALL leave the catalog and injection unchanged.

**Independent Test**: Catalog unit tests for toggle/delete; widget tests for Switch and confirm/cancel dialog.

---

### P1: Injeção via InAppWebView UserScript API

**User Story**: As the app, I need user scripts injected through the official `UserScript` API alongside built-in hooks/helpers without wiping internal scripts.

**Why P1**: Sem injeção correta o import não tem efeito na página.

**Acceptance Criteria**:

1. WHEN the WebView is first created THEN `initialUserScripts` SHALL include built-in scripts plus every catalog entry with `enabled == true`.
2. WHEN a user script is added or re-enabled at runtime THEN the system SHALL call `addUserScript` with `groupName` of the form `userscript:<id>` and then reload.
3. WHEN a user script is disabled or deleted at runtime THEN the system SHALL call `removeUserScriptsByGroupName` for that group and then reload — and SHALL NEVER call `removeAllUserScripts`.
4. WHEN mapping headers THEN `@run-at document-start` SHALL map to `AT_DOCUMENT_START`; `document-end` and `document-idle` SHALL map to `AT_DOCUMENT_END`; presence of `@noframes` SHALL set `forMainFrameOnly: true`, absence SHALL set `forMainFrameOnly: false`; supported grants SHALL use `ContentWorld.PAGE`.

**Independent Test**: Unit/widget tests on injector mapping and merge; assert `removeAllUserScripts` is never invoked by the injector API surface.

---

## Edge Cases

- WHEN URL scheme is not `http`/`https` OR path does not end with `.user.js` THEN system SHALL reject before download
- WHEN response body is empty THEN system SHALL reject as invalid
- WHEN `@match`/`@include`/`@exclude`/`@exclude-match` are present THEN system SHALL wrap the source in a JS guard (native API only filters origin, not path)
- WHEN `@require` lists multiple URLs THEN system SHALL fetch in order and concatenate before the user source; any failure aborts
- WHEN import is in progress THEN the add action SHALL be disabled (one import at a time)
- WHEN catalog is empty THEN empty state copy SHALL be "No userscripts yet" with an add affordance

---

## Header honor matrix

**Honored (import proceeds):**

| Header | Behavior |
| ------ | -------- |
| Block + `@name` | Required |
| `@namespace`, `@version`, `@author`, `@description`, `@license`, `@copyright`, `@homepage`/`@homepageURL`/`@website`/`@source`, `@supportURL`, `@downloadURL`, `@updateURL`, `@icon*` | Stored as UI metadata only |
| `@match`, `@include`, `@exclude`, `@exclude-match` | JS guard around source |
| `@run-at document-start\|document-end\|document-idle` | Injection time mapping above |
| `@noframes` | `forMainFrameOnly: true` |
| `@grant none\|unsafeWindow\|unwrap` or absent | `ContentWorld.PAGE` |
| `@require` | Fetch + concat before source |

**Rejected (import fails, list in SnackBar):**

| Header / value | Reason |
| -------------- | ------ |
| `@grant` other than none/unsafeWindow/unwrap | No GM polyfill |
| `@resource`, `@connect` | Not implemented |
| `@run-at` outside start/end/idle (e.g. `context-menu`) | Not mappable |
| `@sandbox` / `@inject-into` when not page world | Not mappable to `ContentWorld.PAGE` |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| USM-01 | P1: Import — open screen / list / empty | Design | Pending |
| USM-02 | P1: Import — happy path URL | Design | Pending |
| USM-03 | P1: Import — missing block/`@name` | Design | Pending |
| USM-04 | P1: Import — unsupported headers | Design | Pending |
| USM-05 | P1: Import — network/`@require` failure | Design | Pending |
| USM-06 | P1: Import — duplicate `sourceUrl` | Design | Pending |
| USM-07 | P1: List shows name + switch | Design | Pending |
| USM-08 | P1: Toggle + reload | Design | Pending |
| USM-09 | P1: Delete confirm + reload | Design | Pending |
| USM-10 | P1: Delete cancel no-op | Design | Pending |
| USM-11 | P1: initialUserScripts merge | Design | Pending |
| USM-12 | P1: addUserScript + groupName + reload | Design | Pending |
| USM-13 | P1: remove by groupName; never removeAll | Design | Pending |
| USM-14 | P1: header → UserScript field mapping | Design | Pending |
| USM-15 | P1: Sidebar entry always present | Design | Pending |

**Coverage:** 15 total, 0 mapped to tasks yet, 15 unmapped

---

## Success Criteria

- [ ] Player can import a valid `.user.js`, see it in the list, and have it run after reload
- [ ] Invalid/unsupported scripts never enter the catalog
- [ ] Toggle and delete update persistence and injection without touching built-in scripts
- [ ] App theme tokens are unchanged
