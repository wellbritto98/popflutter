# Popmundo Wrapper Context

**Gathered:** 2026-08-17
**Spec:** `.specs/features/popmundo-wrapper/spec.md`
**Status:** Ready for design

---

## Feature Boundary

App Flutter que embrulha `https://www.popmundo.com` em InAppWebView. A UI principal é o próprio jogo. O app expõe um interceptor somente-observação (requests, console, navegação), uma lib de utilitários híbrida (JS injetado + API Dart) portando a fundação `common/` do Popmundo-Utils, e um overlay nativo de debug. Features de gameplay da extensão Chrome (mass interact, call friends, etc.) ficam fora.

---

## Implementation Decisions

### Plataformas

- Android + iOS desde o MVP.
- Sem `shouldInterceptRequest` nativo como fonte da verdade (Android-only).

### Interceptor

- Somente observar: stream de requests, responses (quando o JS conseguir o body), console, navegações.
- Nunca bloquear, nunca reescrever URL/headers/body, nunca injetar `WebResourceResponse` customizado.

### Lib de utils

- Híbrido: UserScripts no WebView (fetch/XHR/console/DOM helpers) + API Dart (TimedFetch, host, notifications, storage, Scoring).
- Scoring/barras/estrelas existem como API; **não** auto-aplicam no load da página — o desenvolvedor chama.

### Sessão

- Persistir cookies/sessão entre aberturas do app.

### Superfície nativa

- WebView fullscreen + overlay/dev panel nativo (log de requests, console, host atual, eval JS).
- Overlay recolhível; quando recolhido não intercepta toques no WebView.
- Valores de cookie ocultos por padrão.

### Recorte do port

- Toda a fundação `common/` (utils, notifications, css/xpath helpers, color, logger, popup-helper, Scoring, exclude-storage).
- `chrome.storage` / `chrome.runtime` reescritos em Dart (`shared_preferences` + sem cota 8 KB).
- Sem mass interact, call friends, autograph collector, nem outras features de gameplay.

### Forma do projeto

- Monorepo: `apps/popmundo_app` + packages `popmundo_webview` e `popmundo_utils`.

### Agent's Discretion

- Layout visual exato do overlay (Material 3, abas vs lista).
- Truncamento de body de request/response no stream (tamanho máximo).
- Nome do JavaScript handler (`popmundo`).
- Melos como tool de workspace.
- Abrir links fora de `*.popmundo.com` no browser do SO.

### Declined / Undiscussed Gray Areas → Assumptions

- Desktop/Web: fora do MVP (confirmado indiretamente pelas plataformas).
- Overlay disponível também em release (não só `kDebugMode`) — o app é ferramenta de desenvolvedor; pode ser escondido por um toggle, default visível como FAB. **Superseded by AD-009** (`.specs/STATE.md`): o overlay agora é gated por `kDebugMode` via `buildAppMenuItems`, inacessível em release; o FAB que permanece sempre visível é o do sidebar (`AppShell`), não mais um FAB próprio do `DebugOverlay`.

---

## Specific References

- InAppWebView 6.x: https://inappwebview.dev/docs/intro
- Popmundo-Utils `common/utils.js` e `common/notifications.js` (e demais arquivos `common/`)
- `Utils.getServerLink` usa `window.location.hostname`
- `TimedFetch` delay padrão 750 ms, fila serial, cache, aviso de logout por throttle

---

## Deferred Ideas

- Features de gameplay da extensão Chrome (mass interact, call friends, etc.)
- Mutação de requests
- Publicação nas stores
- Testes e2e contra `www.popmundo.com` em CI
