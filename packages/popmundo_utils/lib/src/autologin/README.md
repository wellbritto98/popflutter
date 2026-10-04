# autologin (`popmundo_utils`)

Lógica de Auto Login **sem UI**. Specs: `.specs/features/auto-login/` e `.specs/features/background-session-reliability/`. Decisões vigentes: **AD-018**, **AD-019**.

## Objetivo

Detectar sessão expirada (navegação de login **ou** heartbeat Character) e reautenticar o jogador fora da WebView, copiando cookies para o jar nativo e navegando só à home do mundo.

## Responsabilidade principal

Orquestrar GET/POST ASP.NET, match de personagem por nome completo, throttle 750 ms no transporte nativo, probe 60 s de sessão, emitir `AutoLoginStatus`. Não persiste senha (usa `SecretStore` injetado). Não fala com `CookieManager` (usa `CookieSink` / `CookieSource`).

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `auto_login_controller.dart` | Escuta navegação; `checkSession` 60 s; HTTP sem renderer; UA nativo/cache; `inFlight` cobre leitura de cookies e ciclo |
| `auth_http.dart` | `AuthSession`: `probe`/`seed`/redirects manuais, jar `GameCookie`, cooldown |
| `auth_http_io.dart` | `IoAuthHttpSender` (`dart:io`, `followRedirects = false`) |
| `aspnet_form.dart` | Paths de login; parse `div.box` / `<h2>`; match exact case-insensitive |
| `aspnet_form_data.dart` | Serializa `#aspnetForm` (regras HTML successful controls) + `set()` |
| `auto_login_requests.dart` | Corpos de POST login e ChooseCharacter (mesmo código do test_live) |
| `auto_login_settings.dart` | `autologin.v1`; `passwordSecretKey = autologin.password` |
| `auto_login_status.dart` | Fases e `AutoLoginFailure` |
| `cookie_sink.dart` | `CookieSink` + `CookieSource` + `MemoryCookieSink` |
| `game_cookie.dart` | Parse `Set-Cookie`; host-only sem `domain=` |
| `auto_login_trace.dart` | Logs; redige segredos |

## Dependências

- Internas: `PopmundoRuntime` (`loadUrl`, `events.navigation`, `host`; `evaluate`/`waitUntilReady` apenas no fallback inicial de UA), `SecretStore`, `KeyValueStore`, `html`.
- Externas: `dart:io` só no sender real.
- Relacionados: `InAppCookieSink` (webview); telas em `apps/popmundo_app/lib/autologin/`.

## Pontos de entrada

`AutoLoginController.start()` / `dispose()` / `checkSession()`. App injeta o mesmo `InAppCookieSink()` como `cookieSink` e `cookieSource`, e `userAgentProvider: InAppWebViewController.getDefaultUserAgent` para ler o UA nativo sem renderer. `webViewTimeout` limita lookup inicial e confirmação de navegação a 2 s por padrão.

## Fluxos

Login path `/` ou `/Default.aspx` **ou** heartbeat 302 em `{hostSticky}/World/Popmundo.aspx/Character` → settings enabled + user + character + password → GET form no origin atual → POST form inteiro → se ainda login: `invalidCredentials` → senão origin = host final → parse ChooseCharacter → POST escolha → se ainda ChooseCharacter: `serverRejected` → `cookieSink.write` → `loadUrl(.../World/Popmundo.aspx)`.

Heartbeat: skip `www`; 200/rede/5xx ≠ logout; não segue o 302 do Character. Timer no isolate do controller (não no FGS).

O UA é capturado uma vez e reutilizado pelo probe e por todos os hops do login. Com `userAgentProvider`, não há leitura de JS. Sem provider, a primeira captura espera o bridge e lê `navigator.userAgent` dentro do mesmo limite de 2 s. Timeout/erro usa o fallback existente, também cacheado; não enfileira leituras de JS a cada tick.

Se o handshake atribuir outro host numerado enquanto a navegação estiver pausada, o controller guarda esse origin privado após sincronizar cookies. Probes e novas tentativas de login usam o host autenticado e leem os cookies desse host. `HostTracker` continua refletindo apenas navegação nativa real (AD-007). Callback atrasado de login no host antigo é ignorado; quando navegação real estabelece o host autenticado ou outra página do jogo, o origin privado é descartado e o tracker volta a definir o roteamento.

`checkSession` não espera `waitUntilReady`: settings, cookies e HTTP usam portas nativas. O lock começa antes das leituras assíncronas. O timer é armado antes do primeiro probe; um renderer suspenso não impede o próximo tick. Após `cookieSink.write`, `done` é emitido antes da navegação; `loadUrl` permanece solicitado, mas uma resposta pendente libera o ciclo após 2 s. Erros de navegação são registrados em trace e não desfazem a sessão já renovada.

Nome duplicado → `characterAmbiguous` (não chuta). Sem `LastUrlStore`.

## Arquivos críticos

`auto_login_controller.dart`, `auth_http.dart`, `aspnet_form.dart`, `aspnet_form_data.dart`, `cookie_sink.dart`.

## Observações e débitos

- `AutoLoginPhase.choosingCharacter` ainda é emitido; `serverMessage` de `GetPageNotifications` existe no modelo mas o abort `serverRejected` atual **não** preenche essa mensagem.
- Sem CookieSink o handshake autentica o cliente `dart:io` e a WebView permanece deslogada (trace avisa). Sem CookieSource o heartbeat não roda.
- Campo `ddlStatus`: 0 Normal, 1 Busy, 2 Mobile, 3 Drunk, 4 Away.
- `auto_login_controller.dart` passou de ~300 linhas (heartbeat + handshake no mesmo arquivo).
