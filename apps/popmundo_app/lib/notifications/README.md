# notifications (`popmundo_app`)

Notificações locais do app: MVP de teste manual + ponte para notificações do jogo. Specs: `local-notifications`, `popmundo-menu-notifications`. MENUNOTIF-10.

## Objetivo

Prover um `NotificationService` (porta + real + fake) e traduzir os itens de `MenuNotificationsWatcher` (`popmundo_utils`) em notificações OS reais, uma por item novo do jogo.

## Responsabilidade principal

Init do plugin, permissão, exibição (teste fixo e genérica). Não decide *quando* notificar sobre o jogo — isso é do `MenuNotificationsWatcher` em `popmundo_utils`; este módulo só mostra o que a watcher manda.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `notification_service.dart` | Porta: `initialize`, `requestPermission`, `showTestNotification`, `showNotification({id, title, body, payload})` |
| `local_notifications_service.dart` | Real, via `flutter_local_notifications`. Canais `popflutter_debug_channel` (teste) e `popflutter_game_notifications_channel` (jogo); constantes `kTestNotificationId`/`kTestNotificationTitle`/`kTestNotificationBody` (fixas, debug-only, sempre em inglês por AD-014) |
| `fake_notification_service.dart` | Double de teste: `ShownNotification`, lista `shownNotifications`, contadores, `permissionGranted`/`initializeError`/`showDelay` configuráveis |
| `menu_notifications_bridge.dart` | `MenuNotificationsBridge` assina `watcher.newNotifications`, resolve `Utils.getMyName()` uma vez por lote e chama `showNotification` por item; `menuNotificationIdFor(uid)` gera o id `int` não-negativo exigido pelo plugin |

## Dependências

`flutter_local_notifications` (só em `local_notifications_service.dart`), `popmundo_utils` (`MenuNotificationsWatcher`, `MenuNotification`, `Utils`).

## Relacionados

`packages/popmundo_utils/lib/src/menu_notifications/` (watcher/service/state store que produzem os lotes); `DebugOverlay` (botão `debug-send-notification`, sempre em inglês por AD-014); `AppWiring` (`app_wiring.dart`, wiring de `menuNotificationsWatcher`/`menuNotificationsBridge`).

## Pontos de entrada

`main.dart`: `LocalNotificationsService().initialize()` seguido de `requestPermission()` antes de `runApp` — no *startup*, não atrás do painel de debug, porque a ponte de notificações do jogo não tem gatilho manual (MENUNOTIF-10). `AppWiring.start()`/`dispose()` (`app_wiring.dart`) iniciam `menuNotificationsWatcher`/`menuNotificationsBridge` e finalizam ambos; a bridge só é construída se `notificationService` não for nulo.

## Observações e débitos

- Tap-to-navigate está deliberadamente fora de escopo: `Url` do item é carregado em `MenuNotification.url` e passado como `payload` para `showNotification`, mas nada lê esse payload ainda (Out of Scope de `popmundo-menu-notifications`).
- `Utils.getMyName()` não usa mais `runtime.evaluate` — lê `/World/Popmundo.aspx/Character` via `TimedFetch` (cacheado) e faz parse do HTML (commit `4ec5f50`); em erro (`TimedFetchException`/`PopmundoRuntimeException`), volta nome vazio.
- Dedup por `UID` é responsabilidade do `MenuNotificationStateStore` em `popmundo_utils`, não deste módulo.
- Gap aceito de cobertura: o `catch` de `LocalNotificationsService.initialize()` (que zera `_initialized` em qualquer exceção) não é exercitado por nenhum teste em nenhum tier — registrado como gap aceito em `.specs/features/local-notifications/validation.md` (NOTIF-08), risco considerado baixo por ser um try/catch simples.
- MENUNOTIF-10 (permissão pedida no startup) não tem teste automatizado dedicado — gap documentado no `spec.md` da feature (`popmundo-menu-notifications`), smoke test manual pendente.
