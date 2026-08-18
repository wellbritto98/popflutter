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

### AD-010
- **Decision**: UserScripts instalados pelo jogador vivem num catálogo persistido em `KeyValueStore` (`userscripts.v1`) e são injetados apenas via API `UserScript` do InAppWebView, cada um com `groupName: 'userscript:<id>'`. Add/remove em runtime usa `addUserScript` / `removeUserScriptsByGroupName` seguido de `reload()`. Esta feature NUNCA chama `removeAllUserScripts` (preserva `hooks.js`/`helpers.js`). Download de `.user.js` / `@require` usa fetcher HTTP injetado — não `TimedFetch`. O item de menu "Userscripts" é sempre visível (debug e release), então o sidebar em release deixa de ficar vazio (amendment pontual ao empty-state de AD-009; o item Debug continua gated por `kDebugMode`).
- **Reason**: Isolar scripts do usuário dos internos (AD-003); docs oficiais exigem reload após mudança em runtime; TimedFetch é throttle same-origin do jogo (AD-006).
- **Trade-off**: Reload interrompe a página após cada import/toggle/delete; sem polyfill GM.
- **Scope**: `popmundo_utils` (parser/catalog/importer), `popmundo_webview` (injector), `popmundo_app` (UI/HTTP)
- **Date**: 2026-08-17
- **Status**: active

### AD-011
- **Decision**: Auto Login autentica via TimedFetch in-page (`useCache: false`, `redirect: 'manual'` no POST) e trata o 302 de sucesso com `PopmundoRuntime.loadUrl(Location)` (navegação de documento). Senha vive só em `SecretStore` (app: `flutter_secure_storage`); settings não-secretos e last URL elegível em `KeyValueStore` (`autologin.v1`, `session.last_url.v1`). Observe-only (AD-003) permanece: nenhum intercept reescreve request/response. Host sticky continua só via navegação real (AD-007).
- **Reason**: Fetch sozinho não atualiza HostTracker nem aplica o hop `www`→`N` como o form submit; Location não existia no contrato; senha em SharedPreferences é inaceitável.
- **Trade-off**: Extensão do contrato `PopmundoRuntime` (`loadUrl` + headers em `InPageFetchResult`); plugin Flutter novo no app.
- **Scope**: `popmundo_utils` (controller/stores/TimedFetch), `popmundo_webview` (hooks.js / loadUrl), `popmundo_app` (UI / secure storage)
- **Date**: 2026-08-18
- **Status**: active

### AD-012
- **Decision**: Keepalive de sessão em segundo plano vive no app shell via `flutter_foreground_task` (Foreground Service `dataSync` + notificação + isenção de bateria no Android; pedido de notificação no iOS). O isolate do FGS só emite heartbeat — não executa TimedFetch nem toca o WebView. Cookies/sessão continuam AD-004; intercept observe-only AD-003.
- **Reason**: Utils permanece Flutter-free (AD-002); um plugin cobre permissões + FGS + prova de vida no debug; iOS não oferece JS contínuo em background.
- **Trade-off**: Notificação persistente obrigatória no Android; teto `dataSync` no Android 15+; iOS suspende a página (debug deve ser honesto).
- **Scope**: `apps/popmundo_app` (background facade, manifest, Info.plist, DebugOverlay)
- **Date**: 2026-08-18
- **Status**: active

### AD-013

- **Decision**: `stopWithTask` for the Android FGS (both `AndroidManifest.xml` `<service>` and `FlutterForegroundTaskPlatform.initService`'s `ForegroundTaskOptions`) is `false`, not `true`.
- **Reason**: User-reported bug — the persistent notification disappeared as soon as the app left the foreground/Recents. Root cause: T4 (`ccbc15d`) shipped both settings as `stopWithTask: true` / `android:stopWithTask="true"`, which per `flutter_foreground_task` docs ("optionally set to true if the service should only run while the application is active") tells Android to kill the FGS the moment the task is removed — the exact opposite of AD-012's goal (survive backgrounding). No test asserted this value, so it shipped unnoticed through Verifier PASS.
- **Trade-off**: None — this is a straight correction to match the stated P1 goal; no behavior is intentionally given up.
- **Scope**: `apps/popmundo_app/android/app/src/main/AndroidManifest.xml`, `apps/popmundo_app/lib/background/flutter_foreground_task_platform.dart`
- **Date**: 2026-08-18
- **Status**: active

## Handoff

- **Feature**: background-keepalive / `.specs/features/background-keepalive`
- **Phase / Task**: Execute done; **Verifier PASS** (see `validation.md`); post-verify bug fix applied (AD-013)
- **Completed**: spec.md, context.md, design.md, tasks.md, AD-012, T1–T7 (T8 gate via Verifier), validation.md, AD-013 `stopWithTask` fix + regression test in `platform_config_test.dart`
- **In-progress**: none
- **Next step**: Device UAT — open app, grant notif/battery, background the app (both home-press AND swipe-from-Recents) and confirm the FGS notification survives; iOS confirm notif prompt + honest suspend
- **Blockers**: none
- **Uncommitted files**: AndroidManifest.xml, flutter_foreground_task_platform.dart, platform_config_test.dart, STATE.md (pending commit)
- **Branch**: master
