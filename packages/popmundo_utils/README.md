# popmundo_utils

> Análise do código deste pacote. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Pacote **Dart puro** (sem Flutter) com o contrato PopmundoRuntime e a lógica do wrapper: host sticky, fetch com throttle, Auto Login (orquestração + HTTP abstrato), catálogo/parser/shim de UserScripts e GM, storage, facades de personagem/notificações/seletores/scoring, política de navegação, bus de eventos e núcleo de agendamentos locais e ações de jogo HTTP isoladas. Equivale ao common/ do [Popmundo-Utils](https://github.com/ilpersi/Popmundo-Utils) (GPL-3), portado para Dart.

## Responsabilidade principal

Definir **o que** o wrapper faz, sem saber **como** o WebView renderiza. Testável com `dart test` e `FakePopmundoRuntime`. Primeira dependência pub: `html` (parse ASP.NET). `dart:io` só em `auth_http_io.dart`.

## Funcionalidades existentes

| Área | Arquivos | Função |
| ---- | -------- | ------ |
| Contrato | `src/core/popmundo_runtime.dart` | `PopmundoRuntime` (`evaluate`, `fetchInPage`, `loadUrl`, `waitUntilReady`); `InPageFetchResult` (inclui `headers`, `url`); `PopmundoRuntimeException` |
| Host | `src/core/host_tracker.dart` | Origem sticky `https://www.popmundo.com`; `isPopmundoUri`; `resolve(path)` |
| Política | `src/core/observe_policy.dart` | `allowInWebView` / `openExternal`; `observeOnlyResourceResponse()` = `null` |
| Eventos | `src/core/events.dart` | `network`, `console`, `navigation`, `gmValue`, `gmCall`; `BodyCapture` 32 KiB |
| Fetch | `src/core/timed_fetch.dart` | Fila serial, 750 ms, cache `METHOD:URL`, non-2xx → `TimedFetchException` |
| Facades | `src/facades/{utils,notifications,css_selector,scoring}.dart` | `Utils.getMyID`/`getMyName` via TimedFetch+HTML; demais DOM/`__popmundo.*`; Scoring `autoApplyOnLoad = false` |
| Menu notifications | `src/menu_notifications/` | `MenuNotificationsWatcher` observa o `NetworkEvent` de `GetMenuNotificationCount` (o jogo já poll sozinho); ao mudar, busca `GetMenuNotifications` via `TimedFetch`, faz parse em `MenuNotification` e emite só itens novos, deduplicados por `UID` e persistidos via `MenuNotificationStateStore`/`KeyValueStore` |
| Storage | `src/core/storage.dart`, `src/core/secret_store.dart` | `KeyValueStore` + `MemoryKeyValueStore`; `SecretStore` + `MemorySecretStore`; `StorageService` |
| Logger | `src/core/logger.dart` | Ring buffer 200 (`warn`/`error`) |
| Auto Login | `src/autologin/` | Ver [README do submódulo](lib/src/autologin/README.md) |
| UserScripts / GM | `src/userscript/` | Ver [README do submódulo](lib/src/userscript/README.md) |
| Agendamentos | src/scheduler/ | Modelos JSON validados, recorrência UTC/IANA e coordenador serializado com claim durável; ver [README do submódulo](lib/src/scheduler/README.md) |
| Ações de jogo | src/game_actions/ | Descoberta e execução HTTP nativa isolada por conta/personagem; usar item e bônus de equipe. Ver [README do submódulo](lib/src/game_actions/README.md) |
| Barrel | `popmundo_utils.dart` | Único export público |

## Dependências internas e externas

- **Internas:** nenhuma (folha da árvore).
- **Externas:** html ^0.15.6 (parse HTML) e timezone ^0.11.1 (calendário IANA, Dart puro). SDK ^3.13.0. Dev: lints, test.
- **Consumido por:** `popmundo_webview` e `popmundo_app` (`path:`).

## Módulos relacionados

- `popmundo_webview` — implementa `PopmundoRuntime` e `CookieSink`/`CookieSource` (`InAppCookieSink`).
- `popmundo_webview/assets/js` — `window.__popmundo.*` chamado pelas facades.
- `popmundo_app` — `SharedPreferencesStore`, `FlutterSecureSecretStore`, composition do `AutoLoginController` / catalog / GM.

## Pontos de entrada

- `lib/popmundo_utils.dart` — import público.
- Sem `main()` de produto. `example/popmundo_utils_example.dart` só imprime a origin default (boilerplate).

## Fluxos importantes

- **Host sticky:** `onNavigation` só para URI Popmundo http(s); leitores sempre usam `currentOrigin` no momento da chamada.
- **TimedFetch:** enfileira, espera `delay` desde `_lastCall`, `waitUntilReady`, `fetchInPage`. Relativos resolvem no host atual.
- **Auto Login:** ver submódulo; transporte injetável (`AuthHttpSend`), UA nativo opcional (`userAgentProvider`) com cache e timeout 2 s. Probes não dependem do renderer; `done` sucede sync de cookies, e a confirmação de navegação tem espera limitada.
- **GM values:** eventos `gmValue` aplicados em `GmValueStore` (o app assina o bus).
- **Menu notifications:** `MenuNotificationsWatcher.start()` assina `events.network`; ao ver uma contagem diferente da persistida, chama `MenuNotificationsService.fetch()` (`TimedFetch`, `useCache: false`), difere `UID`s contra `MenuNotificationState.notifiedUids` e emite só os novos em `newNotifications`; persiste `{lastCount, notifiedUids}` só em caso de sucesso (falha não corrompe o estado — a próxima contagem diferente tenta de novo).

- **Agendamentos:** SchedulerCoordinator recebe SchedulerStore, executores registrados, relógio e identificador IANA. Comandos e ticks usam uma fila; a execução persiste claim, lastAttemptUtc e próxima ocorrência antes da ação. Ao iniciar, pula ocorrências vencidas e descarta claims interrompidos. Notificações locais têm espera de cinco segundos; ações de jogo delegam a GameActionsService com deadline e cancelamento reais. O adapter fornece persistência e notificações nativas.
- **Ações de jogo:** GameActionsService usa login independente e jar vazio por transação serial, sem WebView. Regra retém conta/personagem e usa formulário fresco. PayCrewAction aceita teto positivo preservado para regras anteriores ou null para autorizar o nível configurado pelo preço futuro válido; a ausência do bônus atual não impede cadastrar uma ocorrência futura, mas impede pagamento naquela execução.

## Arquivos críticos

- `src/core/popmundo_runtime.dart` — mudar a porta quebra adapter e fakes.
- `src/core/host_tracker.dart`, `src/core/timed_fetch.dart` — host sticky e throttle (deslogin no jogo real).
- `src/core/events.dart` — forma dos eventos (webview + app).
- `src/autologin/auto_login_controller.dart` — ciclo de sessão.
- `src/userscript/userscript_parser.dart` — grants aceitos no import.
- `src/menu_notifications/menu_notifications_watcher.dart` — mudar o filtro de URL/contagem quebra a detecção; `menu_notification_state_store.dart` guarda `lastCount`+`notifiedUids` num único blob (evita dessincronia entre save parcial).

- src/scheduler/scheduler_coordinator.dart e scheduler_commands.dart — autoridade de gravação do catálogo service_scheduler.v1; scheduler_models.dart e recurrence_calculator.dart definem validação, identidade negativa estável e calendário.

## Observações técnicas e débitos

- `StorageService.toggleExclusion` faz `int.parse(myCharKey)` sem `try` (`storage.dart`).
- `Notifications.parsePageNotifications` falha silenciosamente para notificação vazia se o JSON ASP.NET mudar. O Auto Login **não** usa este endpoint (veredicto = path ChooseCharacter).
- `Utils.getMyID`/`getMyName` parseiam o HTML de `/World/Popmundo.aspx/Character` (TimedFetch com cache). Os helpers JS equivalentes em `helpers.js` continuam só para eval na página atual.
- `test_live/` acessa o site real se o arquivo for passado ao `dart test`; o glob padrão **não** inclui essa pasta. Credenciais: `POPMUNDO_*`. Ver [test_live/README.md](test_live/README.md).
- Testes em test/ usam fakes e relógios determinísticos. Gate: dart test neste pacote; análise: dart analyze. O scheduler tem testes de modelos, recorrência e coordenador.

## Testes

```bash
cd packages/popmundo_utils && dart test
```
