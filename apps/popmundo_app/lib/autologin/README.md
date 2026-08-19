# autologin (`popmundo_app`)

UI e cofre da feature Auto Login. Lógica: `packages/popmundo_utils/lib/src/autologin/`.

## Objetivo

Configurar enabled/usuário/senha/personagem/status e traduzir `AutoLoginStatus` em snackbars EN/PT.

## Responsabilidade principal

Persistir settings não-secretos no `KeyValueStore` e a senha no `SecretStore`. Não implementa HTTP.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `auto_login_screen.dart` | Form: toggle, username, password (obscure), character full name, ddlStatus, Save |
| `secure_secret_store.dart` | `FlutterSecureStorage` (iOS `first_unlock`) |
| `auto_login_messages.dart` | `autoLoginStatusMessage` → chaves `autologin.cycle.*` |

Wiring: `PopmundoHome` cria `AutoLoginController` com `InAppCookieSink()`, `start()`, escuta `status`.

## Dependências

`easy_localization`, `flutter_secure_storage`, `popmundo_utils`, `InAppCookieSink`.

## Relacionados

Item `id: 'auto-login'` em `buildAppMenuItems`. Catálogos `assets/translations`.

## Pontos de entrada

`_openAutoLogin()` em `app.dart`. Save vazio na senha **mantém** o secret existente.

## Observações e débitos

- Snackbar `serverRejected` interpola `serverMessage`, que o controller atual em geral não envia.
- Testes: `test/auto_login_screen_test.dart`, `test/auto_login_messages_test.dart`.
