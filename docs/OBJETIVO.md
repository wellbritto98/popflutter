# Objetivo do Sistema — Popflutter

> Documento gerado por análise do código-fonte e dos artefatos de spec (`.specs/features/popmundo-wrapper/spec.md`, `context.md`) — não da imaginação do produto. Trechos sem base direta no repositório estão marcados como **Hipótese**.
>
> Última atualização: 2026-08-17.

---

## 1. Propósito principal do sistema

Popflutter é um **wrapper Flutter (Android + iOS) do jogo web [Popmundo](https://www.popmundo.com)**, construído sobre `flutter_inappwebview`. A UI do produto é a própria página do jogo, renderizada em WebView; o Flutter não recria a interface do Popmundo. O propósito central é dar a jogadores um app nativo persistente para jogar, e a desenvolvedores uma **fundação Dart observável e extensível** — equivalente à camada `common/` do projeto de referência [Popmundo-Utils](https://github.com/ilpersi/Popmundo-Utils) (uma extensão de navegador GPL-3) — para construir automações e ferramentas futuras sem reimplementar essa extensão do zero.

## 2. Problemas que ele resolve

| Problema | Como o sistema resolve |
| -------- | ----------------------- |
| O Popmundo distribui sessões entre subdomínios (`www`, `73.popmundo.com`, etc.) por load balancing | `HostTracker` mantém um "host sticky": acompanha redirecionamentos e garante que toda chamada auxiliar use o host atual, não um valor fixo |
| O jogo throttla requests agressivos e pode deslogar o jogador em rajada | `TimedFetch` serializa chamadas com delay mínimo de 750 ms e cache em memória por `METHOD:URL` |
| Construir ferramentas de desenvolvedor hoje exige reimplementar toda a extensão Chrome original | `popmundo_utils` porta a fundação `common/` (host, fetch, personagem, notificações, seletores, storage, scoring) para Dart puro, testável sem navegador |
| `chrome.storage`/`chrome.runtime` não existem fora de uma extensão de navegador | `StorageService` + `KeyValueStore` reimplementam a lógica de storage por chaves lógicas em Dart (`shared_preferences` no app) |
| Depurar uma WebView em produção sem ferramentas USB é difícil | Overlay de debug nativo (FAB + painel) mostra host atual, eventos de rede/console e permite `evaluateJavascript` ad-hoc |
| Interceptar tráfego sem quebrar o jogo (risco de banimento/instabilidade ao mutar requests) | Toda a interceptação é **somente-observação**: nunca bloqueia, reescreve ou substitui request/response |

## 3. Principais fluxos de negócio

1. **Jogar**: o jogador abre o app → WebView carrega `https://www.popmundo.com` em tela cheia → sessão/cookies persistem entre aberturas (não incógnito) → navegação segue o jogo normalmente, inclusive redirecionamentos de subdomínio.
2. **Sair do domínio do jogo**: se o jogador toca um link para fora de `popmundo.com`/`*.popmundo.com`, o app abre no navegador do sistema em vez de substituir a sessão do WebView.
3. **Observar tráfego (uso de desenvolvedor)**: enquanto o jogo roda, `fetch`/`XHR`/`console`/navegação são espelhados como streams Dart (`PopmundoEventBus`), visíveis no overlay de debug, sem alterar o que o jogo recebe.
4. **Chamar helpers Dart contra o jogo**: um desenvolvedor usa `Utils`, `TimedFetch`, `Notifications`, `CssSelectorHelper`/`XPathHelper`, `Scoring`, `StorageService` para ler/escrever dados do personagem, disparar notificações in-game, consultar o DOM ou aplicar melhorias visuais (scoring/barras) — sempre por chamada explícita, nunca automático no load.
5. **Depurar via overlay**: o desenvolvedor expande o FAB de debug, inspeciona host atual, lista de rede/console, nomes de cookies (sem valores), executa um snippet JS e lê o resultado ou erro.

## 4. Atores envolvidos

| Ator | Papel |
| ---- | ----- |
| **Jogador** | Usa o app para jogar Popmundo com sessão persistente; não interage com o overlay de debug necessariamente |
| **Desenvolvedor** | Constrói novas funcionalidades sobre a fundação `popmundo_utils`; usa o overlay e as APIs Dart para inspecionar e estender o app |
| **Backend do Popmundo** (`*.popmundo.com`) | Serviço externo não controlado pelo time; define os endpoints (ex.: `/WebServices/A/Open.asmx/GetPageNotifications`), a marcação HTML (`div.idHolder`, `#notifications`, etc.) e a política de throttle que o sistema precisa respeitar |

## 5. Funcionalidades centrais

Com base nas user stories P1/P2/P3 de `spec.md` (todas com status "Verified" na tabela de rastreabilidade):

- **WebView shell com host sticky** (P1/MVP) — carrega o jogo fullscreen e segue redirecionamentos de subdomínio.
- **Sessão persistente** (P1) — cookies não-incógnito sobrevivem ao fechar/reabrir o app.
- **Interceptor somente-observação** (P1) — streams de `NetworkEvent`, `ConsoleEvent`, `NavigationEvent` sem mutar tráfego.
- **TimedFetch com throttle** (P1) — fila serial, delay 750 ms, cache em memória, erro em respostas não-2xx.
- **Personagem, notifications e selectors** (P1) — `Utils.getMyID`/`getMyName`, `Notifications.createNotification`/`getPageNotifications`, `CssSelectorHelper`/`XPathHelper`.
- **Storage sem `chrome.*`** (P1) — `StorageService` com listas de exclusão, cache de nomes de personagem, normalização de mapas.
- **Menu lateral (sidebar)** — `AppShell` hospeda um único FAB nativo (`menu-toggle`) que abre um `Drawer` (`AppSidebar`) cujos itens vêm de um registro único (`buildAppMenuItems`); adicionar uma funcionalidade nativa nova exige apenas uma entrada nesse registro, sem mudança estrutural em `AppSidebar`/`AppShell`.
- **Overlay de debug** (P2) — painel controlado (`visible`/`onClose`) com host, rede, console, eval JS e clear; abre a partir do item "Debug panel" do menu lateral (visível somente em builds de debug), não mais de um FAB próprio.
- **Scoring API não auto-aplicada** (P2) — helpers de QoL visual (`applyScoringNumbers`, `applyBarPercentage`) disponíveis, mas nunca chamados sozinhos no load.
- **Logger com ring buffer** (P3) — buffer limitado (200 entradas) de `warn`/`error` para diagnóstico sem `chrome.runtime`.

## 6. Visão de produto

O sistema se posiciona explicitamente como uma **fundação de desenvolvedor**, não como um port completo da extensão Chrome de referência. A tabela "Out of Scope" de `spec.md` deixa isso explícito:

| Fora de escopo | Motivo registrado |
| --------------- | ------------------ |
| Mass interact, call friends, autograph e demais features de gameplay da extensão | "Fundação `common/` apenas; features são outro produto" |
| Bloquear ou reescrever request/response | "Interceptor é observe-only" |
| `shouldInterceptRequest` nativo Android como fonte da verdade | MVP é Android **+** iOS, precisa de paridade cross-platform |
| Desktop / Flutter Web | Fora do MVP |
| Publicação nas lojas de app | Não pedido |
| Testes e2e contra `www.popmundo.com` em CI | "Instável, auth real, ToS" |
| Auto-aplicar Scoring/QoL visual em todo page load | "API existe; o dev chama" |

Ou seja: o produto entrega a **base observável e reutilizável**; funcionalidades de automação de gameplay são deliberadamente um produto futuro e separado, a ser construído em cima desta fundação.

## 7. Contexto operacional do sistema

- **Plataformas**: Android e iOS desde o MVP (AD-008); sem suporte a desktop/Web.
- **Distribuição**: não há publicação em lojas prevista no escopo atual (`spec.md`, Out of Scope).
- **Licenciamento**: GPL-3.0-or-later, herdado por o código derivar de tradução do `common/` do Popmundo-Utils (AD-005); ver `LICENSE`/`NOTICE` na raiz.
- **Dependência de um serviço externo não controlado**: todo o sistema depende do site real do Popmundo — sua estrutura de DOM, seus endpoints (`/WebServices/A/Open.asmx/...`) e sua política de throttle. Mudanças no site quebram helpers sem aviso em tempo de compilação (ver `docs/ARQUITETURA.md`, seção 7-8).
- **Estratégia de teste**: cobertura por testes unitários Dart puros usando um runtime falso (`FakePopmundoRuntime`); sem e2e contra o site ao vivo, por instabilidade e por questões de Termos de Serviço.
- **Estado do desenvolvimento**: segundo `.specs/STATE.md`, a feature `popmundo-wrapper` está com fase Execute completa (tarefas T1–T17), validação PASS com uma lacuna registrada (UAT de relançamento do app com cookie persistente ainda depende de teste manual em dispositivo).
