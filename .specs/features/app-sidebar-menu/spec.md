# App Sidebar Menu Specification

## Problem Statement

O único controle nativo do app hoje é um `FloatingActionButton` que vive dentro de `DebugOverlay`, posicionado manualmente num `Stack`, e que alterna diretamente o painel de depuração. Não existe nenhum ponto de entrada nativo componentizado: qualquer funcionalidade futura da UI Flutter (fora do WebView) não tem onde morar, e o único controle existente está fisicamente acoplado ao componente de debug. Isso bloqueia a evolução do app sem reescrever o `DebugOverlay` a cada nova função.

## Goals

- [x] O FAB abre um sidebar (Drawer) componentizado, desacoplado do painel de debug
- [x] O painel de debug vira um item selecionável dentro do sidebar, visível apenas em builds de debug
- [x] Adicionar um novo item ao sidebar no futuro exige apenas uma entrada em uma lista — nenhuma mudança estrutural em widgets existentes

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
| ------- | ------ |
| Itens adicionais no sidebar (Configurações, Sobre, etc.) | Usuário pediu apenas o item Debug agora; itens futuros usam a mesma extensão sem exigir nova spec |
| Navegação/roteamento (`Navigator`/rotas nomeadas) | Não existe router no app; o sidebar abre um painel controlado, não uma tela nova |
| `NavigationDrawer` (Material 3) com seleção persistente | Itens do menu são ações one-shot, não destinos mutuamente exclusivos |
| Internacionalização (i18n) | Repo não tem i18n; strings de UI seguem hardcoded em inglês, como hoje |
| Correção do vazamento de `StreamSubscription` em `DebugOverlay.initState` | Débito pré-existente, não introduzido por esta feature — apenas documentado |

---

## Assumptions & Open Questions

Every ambiguity is resolved or recorded here — nothing is left silently unclear.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | --------------- | --------- | ---------- |
| Gatilho do sidebar | FAB abre o sidebar; o debug abre a partir do item dentro dele | Pedido explícito do usuário | y |
| Gesto de arrastar da borda do Drawer | Desabilitado (`drawerEnableOpenDragGesture: false`) | Conflita com gestos horizontais do WebView (DBG-01) | y |
| Visibilidade do item Debug | Somente em `kDebugMode` | Pedido explícito do usuário | y |
| Itens adicionais agora | Nenhum — sem placeholders falsos | Pedido explícito do usuário ("golden rule" de componentização sem itens fictícios) | y |
| Sidebar vazio em release (`kDebugMode == false`) | FAB continua sempre visível; sidebar abre mostrando estado vazio "No options available." | Escolha explícita do usuário ao ser questionado sobre o trade-off | y |
| Idioma dos textos da UI do sidebar | Inglês | Pedido explícito do usuário; consistente com strings hardcoded existentes em `debug_overlay.dart` | y |
| `AppMenuItem.onTap` recebe `BuildContext`? | Não — apenas `VoidCallback` | O drawer se fecha antes do callback disparar; o context estaria a caminho da desmontagem | n (agent) |
| Callback do item Debug alterna (`toggle`) ou apenas abre o painel? | Apenas abre (`visible = true`); fecha via botão dedicado no próprio painel | Ação de menu one-shot é mais simples; o menu não fica visível enquanto o painel está aberto | n (agent) |

**Open questions:** none — all resolved or logged above (required before the spec is confirmed).

---

## User Stories

### P1: Sidebar componentizado acionado pelo FAB ⭐ MVP

**User Story**: As a developer using the app shell, I want the FAB to open a componentized sidebar so that native app controls have a scalable, single entry point instead of living inside ad-hoc widgets.

**Why P1**: Sem o sidebar não há onde hospedar o item de debug nem qualquer item futuro; é a base estrutural da feature.

**Acceptance Criteria**:

1. WHEN the app is running in any build mode THEN the system SHALL render a `FloatingActionButton` docked at the Scaffold's floating-action-button slot (not hand-positioned inside another widget).
2. WHEN the user taps the FAB THEN the system SHALL open a `Drawer`-based sidebar listing the currently registered menu items.
3. WHEN the sidebar is open and the user drags from the left edge of the WebView area THEN the system SHALL NOT interpret that drag as a request to open or close the drawer (`drawerEnableOpenDragGesture: false`), so horizontal gestures reach the game page.
4. WHEN the sidebar is open and the user taps outside it or presses the Android back button THEN the system SHALL close the sidebar without affecting WebView navigation history.

**Independent Test**: Widget test mounting only the shell widget (FAB + Drawer host) with a fake item list — no `InAppPopmundoRuntime` required; assert the FAB opens the drawer and that `drawerEnableOpenDragGesture` is `false`.

---

### P1: Item de menu extensível via registro único

**User Story**: As the developer maintaining this app, I want adding a new sidebar entry to require only one list element in a single file so that the sidebar stays componentized and scalable as I add features.

**Why P1**: É a "regra de ouro" explícita do pedido — sem essa propriedade a feature não resolve o problema real (acoplamento e falta de escalabilidade).

**Acceptance Criteria**:

1. WHEN a new menu entry is added to the item-registry function THEN the system SHALL render it in the sidebar without any change to the sidebar widget, the shell widget, or any existing menu item's code.
2. WHEN the registry is called THEN the system SHALL return an ordered, immutable list of menu-item value objects (id, icon, label, optional subtitle, tap callback) — no entry may carry a `BuildContext` or mutable state.
3. WHEN the sidebar is built THEN the system SHALL derive the entire visible item list from that single registry call — no item may be hardcoded directly inside the sidebar widget.

**Independent Test**: Pure Dart unit test on the registry function asserting item count, ids, labels and that each item's `onTap` invokes the injected callback — no widget pumping required.

---

### P1: Painel de debug como item gated por build mode

**User Story**: As a developer, I want the existing debug panel to open from a "Debug panel" sidebar item that only exists in debug builds so that end users in release builds never see or reach developer tooling.

**Why P1**: É o requisito funcional central pedido pelo usuário — mover o debug para dentro do sidebar mantendo o gating por build.

**Acceptance Criteria**:

1. WHEN the app runs with `kDebugMode == true` THEN the system SHALL include a "Debug panel" item in the sidebar's item list.
2. WHEN the app runs with `kDebugMode == false` THEN the system SHALL NOT include a "Debug panel" item (nor any other item) in the sidebar's item list.
3. WHEN the user taps the "Debug panel" item THEN the system SHALL close the sidebar and reveal the existing debug panel (host, network, console, JS eval, cookie names) with no loss of its current behavior.
4. WHEN the debug panel is open and the user taps its own close control THEN the system SHALL hide the panel and restore full-screen pointer pass-through to the WebView, matching the current collapsed-overlay behavior (DBG-01 in `popmundo-wrapper/spec.md`).
5. WHEN the debug panel is hidden (collapsed) THEN the system SHALL NOT render any debug-specific control over the WebView — the FAB that used to belong to `DebugOverlay` no longer exists there; the only shell-level control over the WebView is the sidebar's own FAB (covered by story 1).

**Independent Test**: Existing `DebugOverlay` widget tests, adapted to a controlled `visible`/`onClose` API, mounted in isolation (no runtime dependency) — assert panel visibility follows `visible`, `onClose` fires on the close control, and every current assertion (host, cookies never showing raw values, network/console events, eval, clear) still passes.

---

### P2: Sidebar vazio em release permanece utilizável

**User Story**: As a player using a release build, I want the app's FAB and sidebar to behave predictably even with no items so that the shell never looks broken.

**Why P2**: Não é o caminho principal (a maioria dos usuários finais nunca abre o sidebar), mas precisa de um comportamento definido e testado para não regredir a experiência em produção.

**Acceptance Criteria**:

1. WHEN the app runs with `kDebugMode == false` (or any build with an empty item registry) THEN the system SHALL still render the FAB.
2. WHEN the user taps the FAB with an empty item list THEN the system SHALL open the sidebar showing an explicit empty-state message ("No options available.") instead of a blank or crashing drawer.

**Independent Test**: Widget test rendering the shell/sidebar with an empty item list; assert the FAB is present and the empty-state text/key appears after opening the drawer.

---

## Edge Cases

- WHEN the debug panel is open and the user reopens the sidebar THEN the system SHALL keep the debug panel visible underneath/behind the sidebar overlay without losing buffered network/console events (the `DebugOverlay` widget stays mounted; only its `visible` flag and the sidebar's own open state change independently).
- WHEN the item registry receives `includeDebugItem: false` explicitly (test seam) THEN the system SHALL return an empty list, proving the filtering rule without depending on the `kDebugMode` compile-time constant.
- WHEN cookies are present THEN the debug panel SHALL continue to render only `name@domain` pairs, never cookie values, regardless of how the panel is opened (sidebar item vs. the old FAB).
- WHEN the sidebar item list changes size (item added/removed) THEN the system SHALL NOT require any change to `AppShell` or `AppSidebar` — both size themselves and their empty/non-empty behavior from `items.isEmpty` alone.

---

## Implicit-requirement dimensions

| Dimension | Requirement or N/A |
| --------- | ------------------- |
| Input validation & bounds | N/A because menu items are static Dart value objects constructed at compile/build time by the app itself, not from external or user input |
| Failure / partial-failure states | N/A because the sidebar has no async operations of its own; it only renders a synchronous list and forwards taps to callbacks already covered by `popmundo-wrapper` (DBG-01..04) |
| Idempotency / retry / duplicate handling | N/A because opening/closing the sidebar and the debug panel are pure local UI state toggles with no network or persistence side effects |
| Auth boundaries & rate limits | N/A because the sidebar and its items are process-local UI, not an API surface |
| Concurrency / ordering | N/A because all state transitions (`_debugPanelVisible`, drawer open/close) happen on the UI isolate via `setState`, single-threaded by Flutter's framework |
| Data lifecycle / expiry | N/A because no new persisted data is introduced; menu items are rebuilt fresh on every `build()` |
| Observability | N/A beyond what already exists — no new logging requirement was requested |
| External-dependency failure | N/A because the sidebar depends on no external service, only in-process Flutter widgets |
| State-transition integrity | MENU-04, MENU-05 below — the debug panel's visible/hidden transition must remain a strict two-state toggle driven only by the sidebar item tap and the panel's own close control, with no third code path able to open it |

---

## Requirement Traceability

Each requirement gets a unique ID for tracking across design, tasks, and validation.

| Requirement ID | Story | Phase | Status |
| --------------- | ----------- | ------ | ------- |
| MENU-01 | P1: Sidebar componentizado acionado pelo FAB | Execute | Verified |
| MENU-02 | P1: Sidebar componentizado acionado pelo FAB | Execute | Verified |
| MENU-03 | P1: Sidebar componentizado acionado pelo FAB | Execute | Verified |
| MENU-04 | P1: Item de menu extensível via registro único | Execute | Verified |
| MENU-05 | P1: Item de menu extensível via registro único | Execute | Verified |
| MENU-06 | P1: Painel de debug como item gated por build mode | Execute | Verified |
| MENU-07 | P1: Painel de debug como item gated por build mode | Execute | Verified |
| MENU-08 | P1: Painel de debug como item gated por build mode | Execute | Verified |
| MENU-09 | P2: Sidebar vazio em release permanece utilizável | Execute | Verified |

**ID format:** `MENU-NN`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 9 total, 9 mapped to tasks, 0 unmapped

---

## Success Criteria

How we know the feature is successful:

- [x] O FAB abre o sidebar em qualquer build; o painel de debug nunca é acionado diretamente por ele
- [x] `flutter analyze` e `flutter test` (em `apps/popmundo_app`) passam com zero issues e zero testes removidos/pulados
- [x] Adicionar um item de teste ao registro (manualmente, para validar) exige editar apenas `app_menu_registry.dart`
- [ ] Em build de release manual (`flutter run --release`), o item Debug não aparece e o painel de debug é inalcançável
