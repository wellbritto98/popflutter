# test_live (`popmundo_utils`)

Suite **opt-in** contra o site real. Não entra no `dart test` padrão (`dart_test.yaml` globa só `test/`).

## Objetivo

Validar parse de login/ChooseCharacter e o handshake HTTP com páginas e cookies verdadeiros, e gravar fixtures em `captured/`.

## Responsabilidade principal

Exercitar `AutoLoginRequests` / `AuthSession` / host real. Não sobe Flutter nem a WebView.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `login_page_live_test.dart` | GET da página de login |
| `host_behaviour_live_test.dart` | Comportamento de host/cookies |
| `auto_login_flow_test.dart` | Fluxo com credenciais |
| `support/live_config.dart` | Env `POPMUNDO_USERNAME`, `POPMUNDO_PASSWORD`, `POPMUNDO_CHARACTER`; `POPMUNDO_ALLOW_SELECT` para POST de personagem |
| `support/live_client.dart` | Cliente HTTP da suite |
| `captured/` | HTML gravado (`LiveCapture`) |

Sem credenciais os testes **skippam**, não falham.

## Dependências

Código de `lib/src/autologin/`. Rede real para `*.popmundo.com`.

## Relacionados

Política do app: Patrol **não** carrega o jogo (`docs/OBJETIVO.md`). Esta pasta é exceção local do pacote utils, fora da CI.

## Pontos de entrada

```bash
export POPMUNDO_USERNAME=... POPMUNDO_PASSWORD=... POPMUNDO_CHARACTER='Nome Completo'
cd packages/popmundo_utils
dart test test_live/login_page_live_test.dart
```

## Observações e débitos

- Agente `popmundo-utils` diz “nunca HTTP real para popmundo.com” nos testes padrão — esta pasta é o desvio explícito e opt-in.
- `.envexample` na raiz usa `TEST_*`; o código lê `POPMUNDO_*`. **Hipótese:** o `.envexample` está desatualizado ou serve outro harness não referenciado neste pacote.
- Tag `@Tags(['live'])` declarada em `dart_test.yaml`.
- ToS / auth real: não commitar senhas; não ligar isso em CI.
