# autologin (`popmundo_app`)

UI e cofre da feature Auto Login. Lógica: `packages/popmundo_utils/lib/src/autologin/`.

## Objetivo

Configurar enabled/usuário/senha/personagem/status e traduzir `AutoLoginStatus` em snackbars EN/PT e notificações locais de sucesso/falha em segundo plano.

## Responsabilidade principal

Persistir settings não-secretos no `KeyValueStore` e a senha no `SecretStore`. Não implementa HTTP.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `auto_login_screen.dart` | Form: toggle, username, password (obscure), character full name, ddlStatus, Save |
| `secure_secret_store.dart` | `FlutterSecureStorage` (iOS `first_unlock`) |
| `auto_login_messages.dart` | `autoLoginStatusMessage` → chaves `autologin.cycle.*` |
| `auto_login_notifications.dart` | Notifica done/failed em background; id fixo 2, texto EN/PT, falha do plugin contida |
| `auto_login_status_snackbar.dart` | `showAutoLoginStatusSnackBar(...)` — renderiza o snackbar a partir de `AutoLoginStatus` |
| `auto_login_menu_item.dart` | `autoLoginMenuItem({required onTap})` — `AppMenuItem` desta feature, consumido em `app.dart`'s `items:` |

Wiring: `AppWiring` (`app_wiring.dart`) cria um `InAppCookieSink()` compartilhado (`cookieJar`) como `cookieSink`/`cookieSource` do `AutoLoginController` e chama `start()`. O User-Agent vem de `InAppWebViewController.getDefaultUserAgent`, via plataforma nativa; não exige renderer ativo nem depende de captura anterior à criação da WebView. `_PopmundoHomeState` (`app.dart`) assina `wiring.autoLoginStatus` (precisa de `BuildContext` para a cor do snackbar de erro), chama `showAutoLoginStatusSnackBar` em foreground e `notifyAutoLoginResult` quando o app não está `resumed`.

## Dependências

`easy_localization`, `flutter_secure_storage`, `popmundo_utils`, `InAppCookieSink`.

## Relacionados

Item `id: 'auto-login'` em `buildAppMenuItems`. Catálogos `assets/translations`.

## Pontos de entrada

`_openAutoLogin()` em `app.dart`. Save vazio na senha **mantém** o secret existente.

## Observações e débitos

- Snackbar `serverRejected` interpola `serverMessage`, que o controller atual em geral não envia.
- Testes: `test/auto_login_screen_test.dart`, `test/auto_login_messages_test.dart`.
