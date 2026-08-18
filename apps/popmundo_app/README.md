# popmundo_app

> Gerado por análise do código-fonte real deste app. Ver também `docs/ARQUITETURA.md` e `docs/OBJETIVO.md` na raiz do repositório para a visão de sistema completa.

## Objetivo do módulo

Shell Flutter (Android + iOS) que compõe `popmundo_utils` + `popmundo_webview` em um app instalável: tela cheia com o jogo Popmundo em WebView, sessão persistente e um overlay de debug para desenvolvedores.

## Responsabilidade principal

**Composition root** do sistema — é o único lugar que instancia implementações concretas (`InAppPopmundoRuntime`, `SharedPreferencesStore`) e as injeta nos widgets de `popmundo_webview`/`popmundo_utils`. Também hospeda a UI de debug (`DebugOverlay`) e o `MaterialApp`.

## Funcionalidades existentes

| Arquivo | Funcionalidade |
| ------- | --------------- |
| `lib/main.dart` | `main()` — inicializa `SharedPreferences`, cria `InAppPopmundoRuntime()` e `SharedPreferencesStore(prefs)`, chama `runApp(PopmundoApp(...))` |
| `lib/app.dart` | `PopmundoApp` (`MaterialApp`, tema Material 3, seed `Colors.deepPurple`); `PopmundoHome` (`StatefulWidget` que monta `AppShell` com o registro de itens do menu e o `DebugOverlay` controlado, escuta navegação para atualizar lista de cookies via `CookieManager`, guarda `_debugPanelVisible` e o alterna via os callbacks `onOpenDebugPanel`/`onClose`); `PopmundoScope` (`InheritedWidget` expondo `runtime`/`storage` para a árvore, sem novos call sites) |
| `lib/app_shell.dart` | `AppShell` — `Scaffold` do app, agnóstico de runtime (recebe apenas `items`/`body`); hospeda `AppSidebar` como `drawer` (com `drawerEnableOpenDragGesture: false`) e o único FAB nativo do shell (`menu-toggle`), que abre o drawer |
| `lib/menu/app_menu_item.dart` | `AppMenuItem` — value object imutável de uma entrada do sidebar (`id`, `icon`, `label`, `subtitle?`, `onTap`), sem `BuildContext` |
| `lib/menu/app_menu_registry.dart` | `buildAppMenuItems` — única função de registro do sidebar; hoje devolve um item "Debug panel" gated por `includeDebugItem` (default `kDebugMode`); ponto de extensão para novos itens |
| `lib/menu/app_sidebar.dart` | `AppSidebar` — `Drawer` que renderiza a lista de `AppMenuItem` vinda do registro; fecha a si mesmo ao tocar um item; mostra estado vazio ("No options available.") quando a lista está vazia |
| `lib/debug_overlay.dart` | `DebugOverlay` — agora um widget controlado (`visible`/`onClose`, sem FAB próprio); painel com host atual, lista de `NetworkEvent`/`ConsoleEvent` ao vivo, chips de cookies (`name@domain`, sem valor), campo de `evaluateJavascript` ad-hoc com botão "run" e exibição de resultado/erro, botões "clear" e "close" (`debug-close`) |
| `lib/prefs_store.dart` | `SharedPreferencesStore` — implementação de `KeyValueStore` (contrato de `popmundo_utils`) sobre `shared_preferences`, serializando valores com `jsonEncode`/`jsonDecode` |

## Dependências internas e externas

- **Internas**: `popmundo_utils` e `popmundo_webview` (via `path:` relativo em `pubspec.yaml`).
- **Externas (pub.dev)**: `shared_preferences: ^2.5.3` (persistência de `KeyValueStore`), `flutter_inappwebview: ^6.1.5` (usado diretamente em `app.dart` para `CookieManager`/`WebUri`, não só via `popmundo_webview`), `cupertino_icons: ^1.0.8`.

## Módulos relacionados

- `packages/popmundo_webview` — fornece `InAppPopmundoRuntime` e `PopmundoWebView`, consumidos diretamente por `app.dart`.
- `packages/popmundo_utils` — fornece `KeyValueStore`, `StorageService`, `PopmundoEventBus`, `HostTracker`, `NetworkEvent`/`ConsoleEvent`, todos usados por `debug_overlay.dart`/`app.dart`.

## Pontos de entrada

- `lib/main.dart:main()` — entry point do binário Flutter (Android/iOS).
- `android/app/src/main/AndroidManifest.xml` — declara `INTERNET` permission, `MainActivity`, sem outras permissões nativas.
- `ios/Runner/Info.plist` — `NSAppTransportSecurity` com exceção para o domínio `popmundo.com` (e subdomínios), permitindo conexões que não atendam ATS padrão nesse domínio especificamente.

## Fluxos importantes

- **Boot**: `main()` aguarda `SharedPreferences.getInstance()` antes de `runApp`, garantindo que `SharedPreferencesStore` já tenha um `SharedPreferences` válido no primeiro frame.
- **Atualização de cookies no overlay**: `PopmundoHome` escuta `runtime.events.navigation` e, a cada navegação, chama `CookieManager.instance().getCookies(url: ...)` contra o host atual (`runtime.host.currentOrigin`), populando apenas `name`+`domain` — nunca o valor do cookie — em `_cookies`. Falhas de `CookieManager` (ex.: bindings de teste/desktop) são engolidas silenciosamente (`try { ... } catch (_) {}`).
- **Sidebar → painel de debug**: o único FAB nativo do app agora vive em `AppShell` (`menu-toggle`) e abre `AppSidebar`, populado por `buildAppMenuItems`. Em builds de debug, o item "Debug panel" chama `onOpenDebugPanel`, que faz `_PopmundoHomeState` setar `_debugPanelVisible = true`; o item fecha o drawer antes de disparar o callback. `DebugOverlay` empilha o `child` (o `PopmundoWebView`) por baixo e só renderiza o painel de 320px quando `visible == true` — quando `false`, não existe nenhum controle de debug sobre o WebView (pass-through total, DBG-01), diferente do FAB antigo que ficava sempre visível sobre o jogo. O botão `debug-close` do próprio painel chama `onClose`, que volta `_debugPanelVisible` para `false`.

## Arquivos críticos

- `lib/main.dart` — único composition root; qualquer novo serviço/dependência do app inteiro passa a ser instanciado aqui.
- `lib/app.dart` — ponto onde `flutter_inappwebview` é importado diretamente fora de `popmundo_webview` (ver observação abaixo); mudanças aqui afetam tema, ciclo de vida do `PopmundoScope` e atualização de cookies.
- `lib/menu/app_menu_registry.dart` — único ponto de extensão do sidebar: adicionar um item novo ao app exige apenas uma entrada na lista devolvida por `buildAppMenuItems`, sem tocar `AppSidebar`/`AppShell`.
- `lib/debug_overlay.dart` — única superfície de inspeção em runtime sem ferramentas externas; usado nos testes de widget (`test/debug_overlay_test.dart`, `test/app_sidebar_test.dart`, `test/app_shell_test.dart`) via `Key`s: `debug-panel`, `debug-host`, `debug-clear`, `debug-close`, `debug-eval-input`, `debug-eval-run`, `debug-eval-result` (o antigo `debug-toggle` foi removido — o `FloatingActionButton` próprio do overlay não existe mais), `app-sidebar`, `menu-toggle`, `menu-item-<id>`, `menu-empty`.

## Observações técnicas e débitos identificados

- `app.dart` importa `flutter_inappwebview` diretamente (`CookieManager`, `WebUri`) em vez de expor essa funcionalidade através de `popmundo_webview`/`InAppPopmundoRuntime` — quebra parcialmente a separação de responsabilidades descrita em `docs/ARQUITETURA.md` (seção 5/8). Não é um bug, mas é um acoplamento a documentar caso o adapter de WebView seja trocado no futuro.
- README original deste projeto era o boilerplate padrão gerado por `flutter create` (substituído por este documento); não havia documentação de produto neste arquivo antes.
- `NSAppTransportSecurity` no `Info.plist` cria exceção específica para `popmundo.com` — qualquer novo host externo acessado pelo WebView (fora de `*.popmundo.com`) pode precisar de configuração ATS adicional, algo não coberto hoje.
- Testes existentes: `test/debug_overlay_test.dart`, `test/app_menu_registry_test.dart`, `test/app_sidebar_test.dart`, `test/app_shell_test.dart` (widget/unit tests do menu e do overlay) e `test/platform_config_test.dart` (config de plataforma) — não há teste de integração que exercite o app fim-a-fim contra um WebView real (fora de escopo por decisão de spec, ver `docs/OBJETIVO.md`).
- Sem i18n: os textos do sidebar (`Popmundo`, `Debug panel`, `No options available.`) seguem hardcoded em inglês, como o restante da UI nativa do app.
- Em build de release (`kDebugMode == false`), o registro de menu devolve lista vazia — o FAB (`menu-toggle`) continua sempre visível e o sidebar abre mostrando o estado vazio "No options available." em vez de esconder o único controle nativo do shell (decisão explícita do usuário, ver `.specs/features/app-sidebar-menu/spec.md`, MENU-09).
- `drawerEnableOpenDragGesture: false` em `AppShell` não é uma escolha de estilo — é um requisito de DBG-01: o gesto de abrir o drawer arrastando da borda esquerda entraria em conflito com gestos horizontais do WebView.
- Débito pré-existente, não introduzido por esta feature: `DebugOverlay.initState` assina `widget.events.network`/`widget.events.console` sem guardar as `StreamSubscription`s para cancelar em `dispose()` — apenas documentado, correção fora de escopo (ver `.specs/features/app-sidebar-menu/spec.md`, Out of Scope).
- `PopmundoScope` continua sem nenhum call site no app (nem `AppShell` nem `AppSidebar` o leem) — decisão de design deliberada para manter o menu agnóstico do runtime concreto.
