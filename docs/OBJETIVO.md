# Objetivo do Sistema — Popflutter

> Documento gerado por análise do código-fonte e dos artefatos de spec em `.specs/features/` e `.specs/STATE.md`. Trechos sem base direta no repositório estão marcados como **Hipótese**.
>
> Última atualização: 2026-08-19.

Consistente com [ARQUITETURA.md](ARQUITETURA.md).

---

## 1. Propósito principal do sistema

Popflutter é um **wrapper Flutter (Android + iOS) do jogo web [Popmundo](https://www.popmundo.com)**, construído sobre `flutter_inappwebview`. A UI do produto é a própria página do jogo. O Flutter não recria a interface do Popmundo.

O propósito central é:

- dar ao jogador um app nativo com **sessão persistente**, **relogin silencioso** (opcional), **UserScripts** e **keepalive de processo**;
- dar ao desenvolvedor uma **fundação Dart observável** — equivalente à camada `common/` do [Popmundo-Utils](https://github.com/ilpersi/Popmundo-Utils) (extensão GPL-3) — para construir ferramentas sem reimplementar essa extensão.

---

## 2. Problemas que ele resolve

| Problema | Como o sistema resolve |
| -------- | ----------------------- |
| Popmundo distribui sessões entre `www` e `N.popmundo.com` | `HostTracker` acompanha navegação real; Auto Login aterra no host que o POST devolveu |
| Throttle agressivo / logout em rajada | `TimedFetch` (in-page) e `AuthSession` (login nativo) com delay mínimo 750 ms |
| Sessão cai na tela de login ASP.NET | Auto Login (se enabled) autentica em `dart:io`, copia cookies para a WebView e abre a home do mundo |
| Senha em SharedPreferences é inaceitável | `SecretStore` → `flutter_secure_storage` (Keystore/Keychain) |
| Extensão Chrome não roda no app | Catálogo de UserScripts + polyfill `GM_*`/`GM.*` (Core + Host) |
| Android mata o processo em background | Foreground Service `dataSync` + notificação persistente (`stopWithTask=false`) |
| Back do sistema fecha o app | Histórico do WebView é consumido primeiro (`WebViewBackHandler`) |
| `chrome.storage` / `chrome.runtime` não existem | `KeyValueStore` + `StorageService` + `GmValueStore` |
| Depurar WebView sem USB | Overlay de debug (menu, só em `kDebugMode`) |
| Interceptar tráfego sem quebrar o jogo | Observe-only: nunca bloqueia nem reescreve request/response |
| Shell só em inglês | i18n EN/PT (`easy_localization`) nas strings de release |

---

## 3. Principais fluxos de negócio

1. **Jogar:** abre o app → bootstrap do catálogo de UserScripts → WebView carrega `https://www.popmundo.com` → cookies persistem (não incógnito) → redirecionamentos de subdomínio atualizam o host sticky.
2. **Sair do domínio:** link fora de `*.popmundo.com` abre no navegador do sistema (`ObservePolicy.openExternal` + `url_launcher`).
3. **Voltar no jogo:** botão/gesto de system-back anda no histórico da WebView; com histórico vazio, o app sai.
4. **Reautenticar (Auto Login):** se enabled e (a) a navegação cai em `/` ou `/Default.aspx`, ou (b) o heartbeat 60 s em `{hostSticky}/World/Popmundo.aspx/Character` recebe 302 para `/Default.aspx`, o handshake nativo corre fora da tela; o jogador só vê `{host}/World/Popmundo.aspx`. Personagem pelo **nome completo** (`div.box > h2`). Snackbars EN/PT por fase. Sem restore da última URL.
5. **UserScripts:** item sempre visível no sidebar → import por URL, toggle, delete → injector recarrega a página. `@require`/`@resource` via HTTP do app. Scripts com `@grant` GM recebem shim.
6. **GM host:** `GM.xmlHttpRequest` (TimedFetch no jogo / HttpClient fora), `GM.openInTab` (browser do SO), menu commands no sidebar (limpos a cada navegação), notificação in-app, clipboard, `getResourceUrl`.
7. **Keepalive:** FGS sobe no boot; isolate só heartbeat; overlay de debug mostra se o serviço está rodando / bateria / ciclo de vida.
8. **Idioma:** item Language no sidebar; EN/PT; locale do dispositivo no primeiro uso; `setLocale` persiste via Easy Localization.
9. **Observar/depurar:** streams de rede/console/navegação no overlay (debug). Cookies: nome@domínio, sem valor. Eval JS ad-hoc.

---

## 4. Atores envolvidos

| Ator | Papel |
| ---- | ----- |
| **Jogador** | Joga no WebView; configura Auto Login, UserScripts, idioma; vê snackbars e (Android) a notificação de keepalive |
| **Desenvolvedor** | Estende `popmundo_utils`; usa overlay e APIs Dart; escreve testes fake e, no Android, Patrol |
| **Autor de UserScript** | Publica `.user.js` com headers GM; o app importa e executa no `ContentWorld.PAGE` |
| **Backend Popmundo** (`*.popmundo.com`) | Serviço externo: HTML ASP.NET, cookies host-only, throttle, load balancing. O time não controla |

Não há backend próprio do Popflutter.

---

## 5. Funcionalidades centrais

Com base nas features em `.specs/features/` e no código vigente:

| Capacidade | Feature / AD | Notas |
| ---------- | ------------ | ----- |
| WebView fullscreen + host sticky | popmundo-wrapper, AD-007 | Origem inicial `https://www.popmundo.com` |
| Sessão persistente | AD-004 | `incognito: false` |
| Interceptor observe-only | AD-003 | Streams `NetworkEvent` / `ConsoleEvent` / `NavigationEvent` |
| TimedFetch 750 ms | AD-006 | Fila serial, cache `METHOD:URL` em memória |
| Utils / Notifications / selectors / Scoring opt-in | wrapper P1/P2 | Scoring nunca no load |
| Logger ring buffer (200) | wrapper P3 | `warn`/`error` |
| Sidebar + registro de menu | app-sidebar-menu, AD-009 | FAB `menu-toggle`; Debug só em `kDebugMode` |
| Overlay de debug | wrapper P2 | Controlado `visible`/`onClose`; inglês |
| UserScripts persistidos | userscript-manager, AD-010 | `userscripts.v1`; reload após sync |
| Polyfill GM Core + Host | userscript-manager + gm-host-apis, AD-016 | Sem `validation.md` da feature host no repo |
| Auto Login silencioso + heartbeat | auto-login, AD-018, AD-019 | HTTP nativo + `CookieSink`/`CookieSource`; senha no cofre |
| Keepalive em background | background-keepalive, AD-012/013 | FGS Android; iOS suspende a página |
| i18n EN/PT | app-i18n, AD-014 | Catálogos JSON; DebugOverlay fora |
| System-back no WebView | webview-back-navigation | `PopScope` no adapter |
| Patrol device-real | mobile-e2e-tests, AD-015 | Não carrega o jogo |

Itens **sempre visíveis** no sidebar (debug e release): Auto Login, Userscripts, Language. Debug panel só com `kDebugMode`. Em release o FAB continua visível.

---

## 6. Visão de produto

O sistema é **fundação observável + shell de qualidade de vida** (login, scripts, idioma, processo vivo), **não** um port completo da extensão Chrome.

| Fora de escopo | Motivo no spec |
| -------------- | -------------- |
| Mass interact, call friends, autograph e gameplay da extensão | Fundação `common/` + QoL de sessão; gameplay é outro produto |
| Bloquear/reescrever request/response | Observe-only |
| Desktop / Flutter Web | AD-008 |
| Publicação em lojas | Não pedido |
| E2E do **app** contra popmundo.com em CI | Instável, auth real, ToS (Patrol nunca sobe o jogo) |
| Auto-aplicar Scoring no load | API existe; o dev chama |
| Facebook OAuth no Auto Login | Fora do fluxo mapeado |
| Restore da última URL após relog | Sempre World home (pedido explícito) |
| Fallback visível (`form.submit`) no login | Removido no AD-018: um caminho só |
| `GM.getResourceText`, XHR abort/progress | gm-host-apis Out of Scope |

Suite `packages/popmundo_utils/test_live/` é opt-in local com credenciais de ambiente; **não** é o e2e de produto em CI. Ver [ARQUITETURA.md](ARQUITETURA.md) seção 8.

---

## 7. Contexto operacional do sistema

- **Plataformas:** Android e iOS (AD-008). Sem desktop/Web.
- **Distribuição:** sem lojas no escopo atual.
- **Licença:** GPL-3.0-or-later (`LICENSE`/`NOTICE`).
- **Dependência externa:** HTML, cookies e throttle do Popmundo. Mudança no site quebra Auto Login / helpers sem erro de compilação.
- **Testes:**
  - `packages/popmundo_utils`: `dart test` (fakes). `test_live/` só se apontado explicitamente.
  - `popmundo_webview` / `popmundo_app`: `flutter test`.
  - Device: `patrol test --target integration_test/<file>.dart`.
- **Estado (`.specs/STATE.md` Handoff, 2026-08-19):** feature auto-login (rework) com Execute completo (AD-017/018). Próximo passo registrado: smoke em device com `.user.js` real usando `GM_xmlhttpRequest` + `registerMenuCommand`. `gm-host-apis` não tem `validation.md` no repositório.
- **Segredos:** senha do Auto Login no Keystore/Keychain. Credenciais de `test_live` só em variáveis de ambiente (`POPMUNDO_USERNAME` / `POPMUNDO_PASSWORD` / `POPMUNDO_CHARACTER`). Não commitar `.env` com valores reais.
