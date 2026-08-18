# Popflutter

Wrapper Flutter (Android + iOS) do [Popmundo](https://www.popmundo.com) com `flutter_inappwebview`. A UI principal é o próprio jogo. O app observa requests/console/navegação, persiste cookies e oferece uma lib de utilitários inspirada em [Popmundo-Utils `common/`](https://github.com/ilpersi/Popmundo-Utils) (GPL-3).

## Packages

| Package | Função |
| ------- | ------ |
| `packages/popmundo_utils` | Dart puro: `HostTracker`, `TimedFetch`, notifications, storage, selectors, Scoring API, `PopmundoRuntime` |
| `packages/popmundo_webview` | Adapter InAppWebView 6.x, UserScripts, JS bridge `popmundo` |
| `apps/popmundo_app` | Shell fullscreen + overlay de debug |

`popmundo_utils` **não** depende do WebView. Teste helpers com um fake de `PopmundoRuntime`.

## Host sticky

A URL inicial é `https://www.popmundo.com`. Redirecionamentos para `73.popmundo.com` (etc.) atualizam a origem. `Utils.getServerLink` e `TimedFetch` usam o hostname atual — nunca hardcode `www` depois do primeiro load.

## TimedFetch

Fila serial, delay padrão **750 ms**, cache in-memory `METHOD:URL`. Executa `fetch` **no contexto da página** (cookies + same-origin). O jogo throttla e pode deslogar se você disparar requests em rajada.

## Overlay

FAB de debug: host atual, lista de network/console, `evaluateJavascript`, clear. Cookies mostram **nome@domínio**, não o valor.

## Estender

```dart
final runtime = InAppPopmundoRuntime(); // composition root no app
final timed = TimedFetch(runtime);
final utils = Utils(runtime);
final id = await utils.getMyID();
```

Scoring **não** roda sozinho no load. Chame `Scoring(runtime).applyScoringNumbers()` se quiser.

Storage substitui `chrome.storage` via `KeyValueStore` (`MemoryKeyValueStore` nos testes, `SharedPreferencesStore` no app).

## Licença

GPL-3.0-or-later. Ver `LICENSE` e `NOTICE`.
