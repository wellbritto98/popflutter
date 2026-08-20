# popmundo_utils

> Análise do código deste pacote. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Pacote **Dart puro** (sem Flutter) com o contrato `PopmundoRuntime` e a lógica de negócio do wrapper: host sticky, fetch com throttle, Auto Login (orquestração + HTTP abstrato), catálogo/parser/shim de UserScripts e GM, storage, facades de personagem/notificações/seletores/scoring, política de navegação e bus de eventos. Equivale ao `common/` do [Popmundo-Utils](https://github.com/ilpersi/Popmundo-Utils) (GPL-3), portado para Dart.

## Responsabilidade principal

Definir **o que** o wrapper faz, sem saber **como** o WebView renderiza. Testável com `dart test` e `FakePopmundoRuntime`. Primeira dependência pub: `html` (parse ASP.NET). `dart:io` só em `auth_http_io.dart`.

## Funcionalidades existentes

| Área | Arquivos | Função |
| ---- | -------- | ------ |
| Contrato | `src/popmundo_runtime.dart` | `PopmundoRuntime` (`evaluate`, `fetchInPage`, `loadUrl`, `waitUntilReady`); `InPageFetchResult` (inclui `headers`, `url`); `PopmundoRuntimeException` |
| Host | `src/host_tracker.dart` | Origem sticky `https://www.popmundo.com`; `isPopmundoUri`; `resolve(path)` |
| Política | `src/observe_policy.dart` | `allowInWebView` / `openExternal`; `observeOnlyResourceResponse()` = `null` |
| Eventos | `src/events.dart` | `network`, `console`, `navigation`, `gmValue`, `gmCall`; `BodyCapture` 32 KiB |
| Fetch | `src/timed_fetch.dart` | Fila serial, 750 ms, cache `METHOD:URL`, non-2xx → `TimedFetchException` |
| Facades | `utils`, `notifications`, `css_selector`, `scoring` | `Utils.getMyID`/`getMyName` via TimedFetch+HTML; demais DOM/`__popmundo.*`; Scoring `autoApplyOnLoad = false` |
| Menu notifications | `src/menu_notifications/` | `MenuNotificationsWatcher` observa o `NetworkEvent` de `GetMenuNotificationCount` (o jogo já poll sozinho); ao mudar, busca `GetMenuNotifications` via `TimedFetch`, faz parse em `MenuNotification` e emite só itens novos, deduplicados por `UID` e persistidos via `MenuNotificationStateStore`/`KeyValueStore` |
| Storage | `src/storage.dart`, `src/secret_store.dart` | `KeyValueStore` + `MemoryKeyValueStore`; `SecretStore` + `MemorySecretStore`; `StorageService` |
| Logger | `src/logger.dart` | Ring buffer 200 (`warn`/`error`) |
| Auto Login | `src/autologin/` | Ver [README do submódulo](lib/src/autologin/README.md) |
| UserScripts / GM | `src/userscript/` | Ver [README do submódulo](lib/src/userscript/README.md) |
| Barrel | `popmundo_utils.dart` | Único export público |

## Dependências internas e externas

- **Internas:** nenhuma (folha da árvore).
- **Externas:** `html: ^0.15.6`. SDK `^3.13.0`. Dev: `lints`, `test`.
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
- **Auto Login:** ver submódulo; transporte injetável (`AuthHttpSend`) nos testes.
- **GM values:** eventos `gmValue` aplicados em `GmValueStore` (o app assina o bus).
- **Menu notifications:** `MenuNotificationsWatcher.start()` assina `events.network`; ao ver uma contagem diferente da persistida, chama `MenuNotificationsService.fetch()` (`TimedFetch`, `useCache: false`), difere `UID`s contra `MenuNotificationState.notifiedUids` e emite só os novos em `newNotifications`; persiste `{lastCount, notifiedUids}` só em caso de sucesso (falha não corrompe o estado — a próxima contagem diferente tenta de novo).

## Arquivos críticos

- `src/popmundo_runtime.dart` — mudar a porta quebra adapter e fakes.
- `src/host_tracker.dart`, `src/timed_fetch.dart` — host sticky e throttle (deslogin no jogo real).
- `src/events.dart` — forma dos eventos (webview + app).
- `src/autologin/auto_login_controller.dart` — ciclo de sessão.
- `src/userscript/userscript_parser.dart` — grants aceitos no import.
- `src/menu_notifications/menu_notifications_watcher.dart` — mudar o filtro de URL/contagem quebra a detecção; `menu_notification_state_store.dart` guarda `lastCount`+`notifiedUids` num único blob (evita dessincronia entre save parcial).

## Observações técnicas e débitos

- `StorageService.toggleExclusion` faz `int.parse(myCharKey)` sem `try` (`storage.dart`).
- `Notifications.parsePageNotifications` falha silenciosamente para notificação vazia se o JSON ASP.NET mudar. O Auto Login **não** usa este endpoint (veredicto = path ChooseCharacter).
- `Utils.getMyID`/`getMyName` parseiam o HTML de `/World/Popmundo.aspx/Character` (TimedFetch com cache). Os helpers JS equivalentes em `helpers.js` continuam só para eval na página atual.
- `test_live/` acessa o site real se o arquivo for passado ao `dart test`; o glob padrão **não** inclui essa pasta. Credenciais: `POPMUNDO_*`. Ver [test_live/README.md](test_live/README.md).
- Testes em `test/` (29 arquivos, inclusive `fake_runtime.dart`). Gate: `dart test` neste pacote.

## Testes

```bash
cd packages/popmundo_utils && dart test
```
