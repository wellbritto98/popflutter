# popmundo_utils

> Gerado por análise do código-fonte real deste pacote. Ver também `docs/ARQUITETURA.md` e `docs/OBJETIVO.md` na raiz do repositório para a visão de sistema completa.

## Objetivo do módulo

Pacote **Dart puro** (sem dependência de Flutter) com o contrato `PopmundoRuntime` e toda a lógica de negócio do wrapper Popmundo: host sticky, fetch com throttle, storage, facades de personagem/notificações/seletores/scoring, política de navegação e bus de eventos. É a "fundação" equivalente ao `common/` do [Popmundo-Utils](https://github.com/ilpersi/Popmundo-Utils) (GPL-3), portada de JS/extensão Chrome para Dart.

## Responsabilidade principal

Definir **o que** o wrapper faz (regras, decisões, parsing), sem saber **como** o WebView é renderizado. Todo o pacote é testável com `dart test`, sem emulador/dispositivo, usando um runtime falso.

## Funcionalidades existentes

| Arquivo | Funcionalidade |
| ------- | --------------- |
| `src/popmundo_runtime.dart` | Contrato `PopmundoRuntime` (porta) que o adapter WebView implementa; `InPageFetchResult`; `PopmundoRuntimeException` |
| `src/host_tracker.dart` | `HostTracker` — origem sticky (`https://www.popmundo.com` até o primeiro redirect para `*.popmundo.com`); `resolve(path)` |
| `src/observe_policy.dart` | `ObservePolicy` — decisão pura `allowInWebView`/`openExternal`; helper que garante interceptação observe-only (`observeOnlyResourceResponse()` sempre `null`) |
| `src/events.dart` | `NetworkEvent`, `ConsoleEvent`, `NavigationEvent`, `BodyCapture` (trunca corpo em 32 KiB), `PopmundoEventBus` (streams broadcast) |
| `src/timed_fetch.dart` | `TimedFetch` — fila serial, delay padrão 750 ms, cache em memória `METHOD:URL`, erro em resposta não-2xx |
| `src/utils.dart` | `Utils` — `getServerLink`, `getMyID`, `getMyName`, `getMyCharDetails` |
| `src/notifications.dart` | `Notifications` — `createNotification`/`notifySuccess`/`notifyError`/`notifyNormal`, `getPageNotifications` (via `TimedFetch` contra `/WebServices/A/Open.asmx/GetPageNotifications`), parsing da resposta ASP.NET |
| `src/css_selector.dart` | `CssSelectorHelper` (`getSingle`/`getAll`), `XPathHelper` (`getSingle`) — consultam o DOM da página via `window.__popmundo.query*`/`xpathSingle` |
| `src/scoring.dart` | `Scoring` — `applyScoringNumbers`/`applyBarPercentage`; `autoApplyOnLoad = false` documentado (nunca roda sozinho) |
| `src/storage.dart` | `KeyValueStore` (contrato) + `MemoryKeyValueStore` (fake); `StorageService` — `getExcludedIds`, `toggleExclusion`, `normalizeExcludeMap`, `excludeEntryId`, `cacheCharName`, `loadSyncedCharNames` |
| `src/logger.dart` | `Logger` — ring buffer de 200 entradas para `warn`/`error` |
| `popmundo_utils.dart` | Barrel file que exporta tudo acima |

## Dependências internas e externas

- **Internas**: nenhuma — é o pacote base do monorepo (folha da árvore de dependências).
- **Externas (pub.dev)**: nenhuma em `dependencies` além do SDK Dart (`^3.13.0`); `dev_dependencies` são `lints` e `test`.
- **Consumido por**: `packages/popmundo_webview` (implementa `PopmundoRuntime`) e `apps/popmundo_app` (usa facades, `KeyValueStore`, eventos) — ambos via `path:` no `pubspec.yaml`.

## Módulos relacionados

- `packages/popmundo_webview` — implementa `PopmundoRuntime` como `InAppPopmundoRuntime` e traduz o handler JS `'popmundo'` para os eventos definidos aqui.
- `packages/popmundo_webview/assets/js/{hooks,helpers}.js` — contraparte JS: define `window.__popmundo.*`, que as facades deste pacote chamam via `runtime.evaluate(...)`.
- `apps/popmundo_app` — implementa `KeyValueStore` como `SharedPreferencesStore` (produção) e consome `PopmundoEventBus` no overlay de debug.

## Pontos de entrada

- `lib/popmundo_utils.dart` — único ponto de import público (`export` de todos os `src/*.dart`).
- Nenhum `main()`; é uma biblioteca, não um executável.

## Fluxos importantes

- **Resolução de host sticky**: `HostTracker.onNavigation(uri)` é chamado a cada navegação real do jogo; `resolve(path)`/`TimedFetch._absoluteUrl` sempre leem `currentOrigin` no momento da chamada, nunca um valor cacheado antigo.
- **TimedFetch**: cada `fetch()` encadeia na fila (`_queue`) do anterior, espera o `delay` desde o último `_lastCall`, chama `runtime.waitUntilReady()` e só então `runtime.fetchInPage(...)`; erros não-2xx viram `TimedFetchException` e não populam o cache.
- **Notifications.getPageNotifications**: sempre `useCache: false` (notificações não devem vir de cache); parsing tolera respostas ASP.NET envelopadas (`{d: ...}`) e strings JSON aninhadas.

## Arquivos críticos

- `src/popmundo_runtime.dart` — mudar essa interface impacta `popmundo_webview` inteiro e qualquer fake de teste.
- `src/host_tracker.dart` e `src/timed_fetch.dart` — violar a regra de host sticky ou o rate limit pode causar deslogin no jogo real (ver `docs/ARQUITETURA.md`, seção 8).
- `src/events.dart` — contrato de forma dos eventos consumido por `popmundo_webview` (bridge) e `popmundo_app` (overlay); mudança de campo é breaking change em dois outros pacotes.

## Observações técnicas e débitos identificados

- `StorageService.toggleExclusion` faz `int.parse(myCharKey)` sem tratar `FormatException` — chamadores devem garantir que `myCharKey` seja uma string numérica válida (`storage.dart:72`).
- `Notifications.parsePageNotifications` depende do formato exato da resposta do backend do Popmundo (`wrapper['d']`, campos `Status`/`Text`); se o backend mudar, o parsing falha silenciosamente para `PageNotification(status: 'normal', text: '')` em vez de lançar erro — não há log/alerta nesse caminho.
- `CssSelectorHelper`/`Scoring`/`Utils.getMyID`/`getMyName` dependem de seletores CSS fixos definidos no lado JS (`helpers.js`), fora deste pacote — qualquer mudança de marcação no site quebra essas facades sem que o tipo Dart acuse erro em compile-time.
- Testes cobrindo este pacote: `test/{css_scoring,events,host_tracker,logger,notifications,observe_policy,runtime,storage,timed_fetch,utils}_test.dart`, todos usando `test/fake_runtime.dart`.
