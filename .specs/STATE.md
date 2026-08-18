# STATE

## Decisions

### AD-001
- **Decision**: Monorepo Flutter com Melos: `apps/popmundo_app` + packages internos `popmundo_utils` e `popmundo_webview`.
- **Reason**: A lib de utilitários precisa ser importável e testável sem o app; o WebView é um adapter.
- **Trade-off**: Mais boilerplate inicial do que um app único.
- **Scope**: estrutura do repositório, todos os packages
- **Date**: 2026-08-17
- **Status**: active

### AD-002
- **Decision**: `popmundo_utils` define `PopmundoRuntime`; `popmundo_webview` implementa; o app só faz composition root.
- **Reason**: Permite FakePopmundoRuntime em testes unitários e evita dependência circular.
- **Trade-off**: Uma interface a mais para manter.
- **Scope**: packages `popmundo_utils`, `popmundo_webview`, `popmundo_app`
- **Date**: 2026-08-17
- **Status**: active

### AD-003
- **Decision**: Interceptação de rede é somente observação (nunca bloquear nem reescrever request/response). Fonte cross-platform: UserScripts `AT_DOCUMENT_START` + callbacks nativos complementares.
- **Reason**: `shouldInterceptRequest` nativo só existe no Android; POST body é limitado no WebView Android; iOS exige JS.
- **Trade-off**: Não cobre 100% de resources nativos (imagens/css) no iOS da mesma forma que no Android.
- **Scope**: interceptor, UserScripts, InAppWebView settings
- **Date**: 2026-08-17
- **Status**: active

### AD-004
- **Decision**: Cookies da WebView persistem entre aberturas (`CookieManager` nativo, não incognito).
- **Reason**: Login do jogo deve sobreviver ao fechar o app.
- **Trade-off**: Dispositivo compartilhado mantém sessão até logout/clear.
- **Scope**: sessão, Android/iOS WebView
- **Date**: 2026-08-17
- **Status**: active

### AD-005
- **Decision**: Packages derivados de Popmundo-Utils `common/` usam GPL-3.0-or-later com NOTICE; APIs Chrome (`chrome.storage` / `chrome.runtime`) são reimplementadas em Dart, não copiadas.
- **Reason**: Fonte original é GPL-3.0; tradução substancial é obra derivada.
- **Trade-off**: Relicenciar o app para MIT/Apache não é possível enquanto houver código derivado.
- **Scope**: licença do repositório e dos packages
- **Date**: 2026-08-17
- **Status**: active

### AD-006
- **Decision**: TimedFetch executa no contexto da página (same-origin + cookies), orquestrado em Dart com delay padrão 750 ms, fila serial e cache `METHOD:URL` em memória por sessão.
- **Reason**: O Popmundo throttla e desloga; fetches auxiliares precisam do host sticky e da sessão do jogo.
- **Trade-off**: Cache in-memory some ao matar o processo; delay aumenta latência de helpers.
- **Scope**: `TimedFetch`, notifications, qualquer fetch auxiliar
- **Date**: 2026-08-17
- **Status**: active

### AD-007
- **Decision**: Host do jogo é sticky: URL inicial `https://www.popmundo.com`; origin atual acompanha redirecionamentos `*.popmundo.com`; fetches auxiliares usam o hostname atual.
- **Reason**: Load balancing por subdomínio; `getServerLink` original usa `window.location.hostname`.
- **Trade-off**: Código não pode hardcodar `www.popmundo.com` após o primeiro load.
- **Scope**: HostTracker, TimedFetch, navegação
- **Date**: 2026-08-17
- **Status**: active

### AD-008
- **Decision**: Plataformas MVP são Android e iOS. Desktop e Flutter Web estão fora.
- **Reason**: InAppWebView 6.x com JS bridge é o caminho suportado; desktop adiciona NuGet/WebView2 sem ganho para o MVP.
- **Trade-off**: Sem wrapper Windows/macOS no MVP.
- **Scope**: `flutter create` targets, CI
- **Date**: 2026-08-17
- **Status**: active

### AD-009
- **Decision**: O ponto de entrada nativo do debug muda de um `FloatingActionButton` próprio do `DebugOverlay` para um sidebar (`Drawer`) componentizado (`AppShell`/`AppSidebar`), populado por um registro único (`buildAppMenuItems`). O item "Debug panel" só existe na lista quando `kDebugMode == true`. Em release (`kDebugMode == false`), o registro devolve lista vazia, mas o FAB do sidebar (`menu-toggle`) continua sempre visível — o sidebar abre mostrando o estado vazio "No options available." em vez de esconder o único controle nativo do shell.
- **Reason**: O FAB de debug estava fisicamente acoplado ao `DebugOverlay`, sem lugar para hospedar features nativas futuras sem reescrever esse widget a cada nova função.
- **Trade-off**: Uma camada de widget a mais (`AppShell`) entre `PopmundoHome` e o conteúdo atual; `DebugOverlay` passa a depender de props (`visible`/`onClose`) elevadas ao estado do host em vez de gerenciar seu próprio toggle.
- **Scope**: `apps/popmundo_app` (`lib/app_shell.dart`, `lib/menu/`, `lib/debug_overlay.dart`, `lib/app.dart`)
- **Date**: 2026-08-17
- **Status**: active

## Handoff

- **Feature**: app-sidebar-menu / `.specs/features/app-sidebar-menu`
- **Phase / Task**: Execute complete (T1–T7)
- **Completed**: T1–T7
- **In-progress**: none
- **Next step**: Independent Verifier pass on `app-sidebar-menu` (spec-anchored coverage + discrimination sensor); manual `flutter run --release` check that the Debug panel item is absent
- **Blockers**: none
- **Uncommitted files**: none
- **Branch**: master

Previously active feature: popmundo-wrapper / `.specs/features/popmundo-wrapper` — Execute complete; validation PASS with 1 spec-precision gap (cookie relaunch e2e; device UAT for session persistence still pending).
