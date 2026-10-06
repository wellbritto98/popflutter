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
- **Status**: superseded by AD-017

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

### AD-014
- **Decision**: A i18n da shell nativa usa `easy_localization` (^3.0.8) com catálogos JSON em `apps/popmundo_app/assets/translations/{en,pt}.json` (`useOnlyLangCode`, `fallbackLocale: en`, `useFallbackTranslations`). Locale inicial segue o dispositivo; escolha manual EN/PT persistida. Toda nova string de UI visível em release no `apps/popmundo_app` DEVE passar pelos catálogos (`.tr()`). `popmundo_utils`/`popmundo_webview` permanecem sem locale (mensagens de exceção seguem detalhes técnicos em inglês); o DebugOverlay permanece em inglês.
- **Reason**: Escolha do usuário (Easy Localization); modelo JSON por asset sem codegen para uma shell de 2 idiomas; packages precisam continuar Flutter-free (AD-002).
- **Trade-off**: Dependência runtime adicional (easy_logger/intl via lib); erros de import de userscripts exibidos em inglês nos snackbars.
- **Scope**: `apps/popmundo_app` (lib, assets, testes); todas as futuras strings nativas da shell
- **Date**: 2026-08-18
- **Status**: active

### AD-015

- **Decision**: O repositório passa a ter **dois tiers de teste**. O tier rápido (`apps/popmundo_app/test/`, `flutter test`, fakes) continua sendo o padrão. Um tier **device-real** vive em `apps/popmundo_app/integration_test/`, roda com **Patrol** (`patrol test`) em Android físico ou emulador, e cobre exclusivamente a superfície mobile que **não toca o popmundo.com**: foreground service, Keystore, canal do SharedPreferences e sockets loopback. Regras não-negociáveis do tier: (a) nenhum teste constrói `PopmundoApp`/`InAppPopmundoRuntime` — usa harness mínimo; (b) **exatamente um `patrolTest` por arquivo**; (c) `flutter analyze integration_test` obrigatório antes de qualquer execução em device.
- **Reason**: O AD-013 (`stopWithTask="true"`) passou por 54 testes verdes e um Verifier PASS porque todo teste do app substitui a plataforma por fake — o tier era estruturalmente cego a comportamento de runtime. O tier device-real agora detecta esse bug automaticamente (prova de mutação registrada em `validation.md`). A restrição do popmundo.com do `CLAUDE.md` é satisfeita **por construção**: sob `integration_test` o entrypoint Dart é o arquivo de teste, então `lib/main.dart` nunca roda.
- **Trade-off**: `patrol_cli` vira pré-requisito global; execuções levam ~1 min contra ~7s do tier rápido; um `patrolTest` por arquivo é limitação upstream aberta ([2005](https://github.com/leancodepl/patrol/issues/2005), [2380](https://github.com/leancodepl/patrol/issues/2380)), então critérios relacionados se agrupam num teste sequencial; como `lib/main.dart` não roda, o que ele inicializa (ex. `initCommunicationPort()`) precisa ser reproduzido em `integration_test/support/harness.dart`.
- **Scope**: `apps/popmundo_app` (`integration_test/`, `android/app/build.gradle.kts`, `android/app/src/androidTest/`, `pubspec.yaml`), `CLAUDE.md`
- **Date**: 2026-08-19
- **Status**: active

### AD-016

- **Decision**: O polyfill GM cobre **Core + Host**: value/info/style/log/unsafeWindow (já existente) mais `GM.getResourceUrl`, `GM.notification`, `GM.openInTab`, `GM.registerMenuCommand`, `GM.setClipboard`, `GM.xmlHttpRequest` (formas `GM_*` e `GM.*`). `@resource`/`@connect` deixam de rejeitar o import; resources persistem em `GmResourceStore`; XHR Popmundo usa `TimedFetch`, terceiros usam `HttpClient` nativo sem cookies do jogo; `GM.openInTab` abre no navegador do SO; menu commands aparecem no sidebar (limpos a cada navegação); notificações GM são banner in-app. Canal único `popmundo` ganha `type: 'gm'` + `gmReply`. AD-003 inalterado.
- **Reason**: Scripts Tampermonkey/Greasemonkey reais dependem das APIs host; trade-off "sem polyfill GM" do AD-010 era pré-implementação Core.
- **Trade-off**: Superfície de ataque maior (XHR nativo + clipboard + abas externas); `@connect` não bloqueia import — nega em runtime.
- **Scope**: `popmundo_utils` (parser/shim/stores/policy), `popmundo_webview` (bridge/hooks), `popmundo_app` (GmHostHandler, sidebar, overlay)
- **Date**: 2026-08-19
- **Status**: active

### AD-017

- **Decision**: O ciclo do Auto Login passa a ser **silencioso e request-based**, com quatro mudanças em relação ao AD-011:
  1. **Sem `redirect: 'manual'`.** O fetch do browser devolve resposta opaca (status 0, sem `Location`) nesse modo, então o POST de login usa o `redirect: 'follow'` padrão e o destino sai de `InPageFetchResult.url` (URL final após os redirects). O `loadUrl(Location)` do AD-011 nunca foi implementável.
  2. **Fallback de navegação.** Quando o fetch de login lança — tipicamente o hop `www` → `N.popmundo.com`, que o CORS bloqueia porque o cookie de auth `popmundo.com=` é host-only (sem `domain=`) — o ciclo injeta um `<form>` e chama `form.submit()`, deixando a WebView atravessar o hop nativamente. Esse caminho já havia sido implementado sem registro; agora é explicitamente o fallback, não o caminho principal.
  3. **Corpo do POST = `#aspnetForm` inteiro + overrides.** `AspNetFormData` serializa todo controle *successful* do form (regras de submissão HTML: sem `disabled`, sem submit/button/reset/image/file, só checkbox/radio marcados, `option` selecionada dos selects) e expõe `set()` com semântica de `FormData.set`. Substitui o cherry-pick de `__VIEWSTATE`/`__VIEWSTATEGENERATOR`/`__EVENTVALIDATION`, que descartava silenciosamente `ddlLanguage` e qualquer estado oculto extra. Porte direto do dialeto de `Popmundo-Utils` `features/mass-item-sender.js:224-243`.
  4. **Personagem por nome completo.** `parseCharacterChoices` lê uma candidata por `div.box` usando o texto do `<h2>` (o `value` do submit só tem o primeiro nome e colide entre personagens) e o `name=` do submit da mesma box. Match exato, case/whitespace-insensitive; nome duplicado devolve `ambiguous` e aborta em vez de chutar. Usa `package:html` — primeira dependência do `popmundo_utils`, Dart puro, então AD-002 continua válido.
  Além disso: o veredito do POST de escolha vem de `Notifications.getPageNotifications()` (padrão de `mass-item-sender.js:272`), o ciclo termina sempre em `{origin}/World/Popmundo.aspx` no host em que realmente aterrissou, e `LastUrlStore` foi removido (o app volta a abrir em `HostTracker.defaultOrigin`). Estado do controller cai de quatro flags para `_inFlight` + `_awaitingChooseCharacter`. AD-003 (observe-only), AD-006 (throttle 750 ms) e AD-007 (host sticky só por navegação real) permanecem.
- **Reason**: O match por primeiro nome escolhia o personagem errado quando a conta tinha dois com o mesmo primeiro nome — a `div.box` do `<h2>` é o único identificador confiável na página. O resto veio junto porque o AD-011 descrevia um fluxo que o browser não permite (`redirect: 'manual'`) e um corpo de POST que diverge do dialeto validado no projeto de referência.
- **Trade-off**: Dois caminhos de login para manter (silencioso + fallback de navegação); uma dependência nova no pacote antes zero-deps; sem restauração da última URL — depois do relog o jogador sempre cai na home do mundo.
- **Scope**: `popmundo_utils` (`autologin/`, exports, pubspec), `popmundo_app` (`app.dart`, `autologin/auto_login_messages.dart`, catálogos EN/PT)
- **Date**: 2026-08-19
- **Status**: superseded by AD-018 (transporte do handshake; fallback de navegação removido)

### AD-018

- **Decision**: O handshake de Auto Login (GET do form, POST de login, handover de host e POST de escolha de personagem) roda em **HTTP nativo `dart:io`** via `AuthSession`, fora da WebView. Os cookies coletados em todos os hops são copiados para o jar da WebView por um port `CookieSink`, implementado em `popmundo_webview` como `InAppCookieSink` sobre `CookieManager.setCookie`. Redirects são seguidos **à mão** (`followRedirects = false`), um hop por vez, porque o cookie de auth só é emitido no último hop, pelo host numerado. O `User-Agent` é lido da própria WebView (`navigator.userAgent`) para o jogo ver um cliente só. O cooldown de 750 ms do AD-006 vale também aqui. Cookies host-only (sem `domain=`) são gravados sem `domain`, preservando o escopo. O submit de `<form>` na WebView e o polling de DOM do AD-017 foram **removidos**: existe um caminho só.
- **Reason**: Comprovado em device: o POST de login em `www.popmundo.com` responde 302 para `N.popmundo.com//Login.aspx?t=…`, e o fetch in-page morre com *"No 'Access-Control-Allow-Origin' header"*. Esse hop cross-origin é estrutural — o cookie `popmundo.com` é host-only, então o jogo precisa do token na URL para transferir a sessão. `dart:io` não tem CORS, então o ciclo inteiro acontece fora da tela; o jogador só vê a home do mundo carregar. O host é atribuído por balanceamento a cada login (runs consecutivos caíram em `74.` e `75.`), então tudo depois do login resolve contra `finalUrl.host`, nunca contra um origin guardado.
- **Trade-off**: Sem fallback visível — se o jogo recusar o cliente nativo, o Auto Login falha em vez de degradar para navegação (escolha do usuário, para manter um caminho só). A autenticação deixa de passar pelo contexto da página, então o TimedFetch in-page (AD-006) não cobre mais essa parte — o throttle foi reimplementado no `AuthSession`. Sync de cookie é código novo com falha sutil (sessão "quase" válida); mitigado por testes contra os `Set-Cookie` reais e 6 mutações. Um cliente HTTP fora do browser é mais distinguível para o servidor do que a própria WebView — decisão consciente do usuário após a alternativa headless ser apresentada.
- **Scope**: `popmundo_utils` (`autologin/auth_http.dart`, `auth_http_io.dart`, `game_cookie.dart`, `cookie_sink.dart`, controller), `popmundo_webview` (`in_app_cookie_sink.dart`), `popmundo_app` (`app.dart`)
- **Date**: 2026-08-19
- **Status**: active

### AD-019

- **Decision**: Detecção de sessão expirada em idle/background é um GET nativo (`AuthSession.probe`) a cada 60 s em `{HostTracker.currentOrigin}/World/Popmundo.aspx/Character`, **sem** seguir redirects. Cookies vêm da WebView via porta `CookieSource` (`CookieManager.getCookies` → `GameCookie`) semeados no jar do `AuthSession`. 302 cuja `Location` resolvida é path de login dispara o handshake AD-018 no **mesmo** origin sticky. Host `www.popmundo.com` não é probed. O timer vive no isolate do `AutoLoginController`; o isolate do FGS permanece só keepalive (AD-012). Erro de rede/5xx/200 não é logout.
- **Reason**: A WebView pode não navegar quando a sessão ASP.NET cai (app em keepalive). Fetch in-page congela em background. Seguir o 302 baixaria `Default.aspx` à toa. Cookies de sessão são host-only no `N.` atribuído no login (AD-007).
- **Trade-off**: Um GET/minuto ao jogo mesmo idle; mitigado por um hop, skip `www`, e não seguir redirect. `CookieManager.getCookies` no Android pode omitir atributos sem `GET_COOKIE_INFO` — name+value bastam para o header `Cookie`.
- **Scope**: `popmundo_utils` (`CookieSource`, `AuthSession.probe`/`seed`, `AutoLoginController.checkSession`), `popmundo_webview` (`InAppCookieSink.read`), `popmundo_app` (wiring)
- **Date**: 2026-08-19
- **Status**: active

### AD-020

- **Decision**: Manutenção contínua de sessão Android usa FGS specialUse, permissão FOREGROUND_SERVICE_SPECIAL_USE e PROPERTY_SPECIAL_USE_FGS_SUBTYPE explicando o uso; substitui o tipo dataSync do AD-012. Isolate FGS continua heartbeat-only. Auto Login cacheia User-Agent nativo com espera limitada; probes HTTP nativos não dependem de JS pronto e navegação final não bloqueia conclusão. Origin autenticado pendente guia HTTP e cookies até navegação nativa confirmar o host, sem mutar HostTracker. Resultados done/failed fora de resumed geram notificação local EN/PT com id fixo 2; foreground conserva Snackbar.
- **Reason**: Usuário exige funcionamento contínuo, inclusive noite inteira. dataSync limita-se a seis horas no Android 15+; o código esperava JS suspenso sem timeout e só mostrava feedback dentro da tela.
- **Trade-off**: Google Play revisa o caso de uso specialUse. Processo morto, force-stop e reboot continuam limites; sem auto-boot. UA padrão existente é fallback se primeira leitura não responder em 2 s. iOS não ganha execução contínua.
- **Scope**: AutoLoginController, shell/autologin, adapter FGS, Android manifest e testes device-real.
- **Date**: 2026-10-04
- **Status**: active; supersedes AD-012 service type and amends AD-018/019 renderer dependency.

### AD-021

- **Decision**: Agendamentos de serviços locais executam no isolate do FGS specialUse existente; domínio/calendário/coordenador são Dart puro em popmundo_utils. Um escritor serializado no FGS persiste service_scheduler.v1; UI usa comandos/respostas, nunca grava o snapshot. Boot/package-replacement auto-start só habilitado enquanto existirem regras ativas. MVP executa apenas notificação local com ID negativo estável e descarta ocorrências perdidas.
- **Reason**: Usuário aprovou agendamentos em segundos/intervalos/dias da semana, com execução ao fechar o app e após reboot, sem recuperação de perdidas.
- **Trade-off**: Serviço contínuo e consumo de bateria; entrega em segundos é melhor esforço. At-most-once attempt permite perder uma ação se morrer após claim. Android force-stop continua exceção; iOS não ganha este scheduler contínuo.
- **Scope**: popmundo_utils scheduler, app shell/background/notifications, sidebar/i18n, Android lifecycle/device tests.
- **Date**: 2026-10-04
- **Status**: active; amends heartbeat-only restriction of AD-012/019/020 and scheduler reboot restriction of AD-020. WebView, JS, auth and game HTTP remain outside FGS isolate.

### AD-022

- **Decision**: O composition root do `popmundo_app` é um objeto simples, `AppWiring` (`lib/app_wiring.dart`), construído em `main.dart` e passado inteiro para `PopmundoApp`/`PopmundoHome` (um único parâmetro `wiring`). `AppWiring` detém os colaboradores e o ciclo `start()`/`dispose()`, não referencia `BuildContext`/`State`/`Navigator`/widget algum, e expõe estado observável como `ValueListenable` (`userscripts`, `cookieWatcher.cookies`) em vez de campos `setState`. `_PopmundoHomeState` fica só com o que é genuinamente widget: `WidgetsBindingObserver`, a assinatura de `autoLoginStatus` (precisa de `Theme.of(context)`), os `Navigator.push`/dialog, `_debugPanelVisible` e `build`. O `MaterialApp` permanece **textualmente** em `lib/app.dart`. Junto: (a) `buildAppMenuItems` deixa de conhecer as features — recebe a lista pronta e só preserva a ordem do chamador e anexa o item de debug por último quando o gate permite; cada feature possui o seu `AppMenuItem` na própria pasta; (b) `packages/popmundo_utils/lib/src` passa a ter zero arquivos soltos, em `core/` + `facades/` além das slices existentes; (c) o `PopmundoScope` morto e a instância órfã de `StorageService` no app são removidos. Numerado AD-022 porque AD-020 já era a manutenção de sessão e AD-021 é o service-scheduler. O scheduler entra nesse contrato: `SchedulerApi` vive em `AppWiring` e o item de menu é `schedulesMenuItem` na pasta da feature.
- **Reason**: `app.dart` tinha 402 LOC (15% do `lib/` do app) e aparecia em praticamente todo commit de feature (19 de 136). Adicionar uma feature exigia edições em 7 pontos espalhados e obrigava um agente a carregar ~650 LOC só para descobrir onde plugar — custo que crescia O(n features). O gargalo era pontual: **não** faltava camada. A arquitetura macro (3 pacotes, ports & adapters, slices feature-first, DI manual, README por pasta) já é o que as convenções atuais recomendam, e a "domain layer" já existe como `popmundo_utils`. Efeito colateral relevante: a lógica de bootstrap/sync de userscripts/cookies estava presa dentro de um `State` e **não tinha teste unitário nenhum**; extraí-la a tornou testável (`test/app_wiring_test.dart`).
- **Trade-off**: `build()` ficou mais verboso — três wrappers `ValueListenableBuilder`/`ListenableBuilder` mais o ramo de `keepalive` nulo custam ~55 linhas que a versão `setState` ganhava de graça lendo campos direto; por isso `app.dart` parou em 216 LOC e não nos ≤180 estimados (registrado como falha em `spec.md`, não retroajustado). Em troca, os rebuilds passaram a ser escopados — a WebView é passada como `child` de builder e não é mais reconstruída a cada cookie ou tick de background, o que o `setState` global fazia. Duas garantias que o `initState` dava de graça viraram explícitas em `AppWiring`: `start()` idempotente (`_started`) e recusa de escrita pós-`dispose` (`_disposed`). Os ports de cookie viraram injetáveis (default inalterado) porque `InAppCookieSink` constrói um `CookieManager` avidamente e impedia construir `AppWiring` sob `flutter test`. A ordem concreta do menu (`auto-login, userscripts, schedules, language`) deixou de ser testável sem montar a shell — delta aceito e registrado no `spec.md`.
- **Supersedes**: a nota "PopmundoScope mantido por decisão / zero call sites" em `.specs/features/app-sidebar-menu/design.md` e a linha correspondente na tabela de código morto do `docs/ARQUITETURA.md`. Aqueles arquivos de execução histórica não são editados; o `spec.md` daquela feature nunca citou `PopmundoScope`, então não há `SPEC_DEVIATION` a marcar.
- **Scope**: `popmundo_utils` (`lib/src/core/`, `lib/src/facades/`, barrel), `popmundo_app` (`main.dart`, `app.dart`, `app_wiring.dart`, `cookie_watcher.dart`, `menu/`, `autologin/`, `userscripts/`, `language/`, `scheduler/`, `notifications/README.md`)
- **Date**: 2026-08-20
- **Status**: active

## Handoff

- **Feature**: service-scheduler / .specs/features/service-scheduler.
- **Phase / Task**: Complete; user approved design on 2026-10-04; independent review PASS on 2026-10-05. Merged onto master together with composition-root-scaling (AD-022): `SchedulerApi` is held by `AppWiring`, and the sidebar entry is `schedulesMenuItem`.
- **Completed**: approved plan and AD-021; T1 dcd7781 (239 core tests), T2 c5e2782 (248), T3 77288a2 (273), analyzers clean; root spec/quality review passed for core and T4 runtime; T4 9467250 (116 app tests), T5 4f1c2e1 (132 app tests); native screen spec/quality review passed; startup recovery fix 3131a8f (136 app tests); background permission fix c56844c (137 app tests), native GMT alias fix d83414f (138 app tests), analyzers clean. T6 fac723d: all native lifecycle, reboot skip, weekly GMT and native suppression evidence passed; temporary configuration restored.
- **In-progress**: none. T7 751bd77 maintenance and production release complete; independent validation PASS over 5ca0d99..ac79b13, 448 tests (core277/WebView31/app140), analyzers and normal build clean. Five independent behavior faults detected and discarded. Test-only Unicode repairs 2aec530/ac79b13 close F2; retained-log hygiene 74b9500 closes F1. Production data preserved and installed source unchanged.
- **Next step**: Use sidebar Agendamentos to manage local notification rules. Physical-handset and overnight observation remain outside the recorded emulator evidence; no additional implementation or verifier fix remains. Full report: .specs/features/service-scheduler/validation.md.
- **Blockers**: none. Keep test package/build changes temporary and preserve installed production data.
- **Prior feature**: background-session-reliability Verifier PASS; overnight coverage was not observed. composition-root-scaling also merged (AD-022; Verifier PASS, commits `1ebf55b`…`8984376`).
- **Branch**: master
