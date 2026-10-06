# notifications (`popmundo_app`)

Notificações locais do app: MVP de teste manual, ponte para notificações do jogo e executor das regras de agendamento. Specs: `local-notifications`, `popmundo-menu-notifications`, `service-scheduler`. MENUNOTIF-10.

## Objetivo

Prover um `NotificationService` (porta + real + fake), traduzir os itens de `MenuNotificationsWatcher` (`popmundo_utils`) em notificações OS reais, e expor `showScheduledNotification` para o scheduler Android.

## Responsabilidade principal

Init do plugin, permissão, exibição (teste fixo, genérica e agendada). Não decide *quando* notificar sobre o jogo — isso é do `MenuNotificationsWatcher` em `popmundo_utils`. O calendário e o claim da ocorrência também ficam no core; este módulo só mostra o que o chamador manda.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `notification_service.dart` | Porta: `initialize`, `requestPermission`, `showTestNotification`, `showNotification({id, title, body, payload})` |
| `local_notifications_service.dart` | Real, via `flutter_local_notifications`. Canais `popflutter_debug_channel` (teste), `popflutter_game_notifications_channel` (jogo) e `popflutter_schedules` (agendamento); constantes `kTestNotificationId`/`kTestNotificationTitle`/`kTestNotificationBody` (fixas, debug-only, sempre em inglês por AD-014) |
| `fake_notification_service.dart` | Double de teste: `ShownNotification`, lista `shownNotifications`, contadores, `permissionGranted`/`initializeError`/`showDelay` configuráveis |
| `menu_notifications_bridge.dart` | `MenuNotificationsBridge` assina `watcher.newNotifications`, resolve `Utils.getMyName()` uma vez por lote e chama `showNotification` por item; `menuNotificationIdFor(uid)` gera o id `int` não-negativo exigido pelo plugin |

| Uso | Canal / identidade |
| --- | --- |
| FGS de sessão | `popmundo_keepalive`, definido pelo adapter background |
| Teste manual do overlay | `popflutter_debug_channel`, id 1 |
| Resultado de Auto Login | notificação genérica, id 2 |
| Menu do jogo | `popflutter_game_notifications_channel`; `MenuNotificationsBridge` usa UID do evento |
| Agendamento local | `popflutter_schedules`; ID negativo estável alocado pelo core |

## Executor de agendamentos

`showScheduledNotification({required int id, required String title, required String body})` é um caminho estrito separado. Antes da primeira submissão exige `initialize` retornar true; falha produz `SchedulerException` `notificationInitializationFailed`. Exige adapter Android e `areNotificationsEnabled` true; ausência/negação produz `permissionDenied`. Erros de show propagam para o coordenador, que persiste `failed`; não há sucesso silencioso.

`ScheduledNotificationExecutor` em `scheduler_environment.dart` passa o `notificationId` e o título/corpo salvos diretamente. O mesmo ID substitui o card anterior da mesma regra; IDs de regras diferentes não colidem com os usos positivos existentes. O core mantém o contador após exclusão. Pausa/exclusão impedem próximas submissões; não removem um card já visível.

O serviço secundário inicializa seu próprio plugin; não depende da inicialização feita em `main`. `submitted` registra retorno bem-sucedido da requisição ao OS, sem afirmar que a pessoa viu o card. Não se usa o scheduling nativo do plugin: o Timer/reconciliação ficam no `SchedulerRunner`.

`isScheduledNotificationGranted()` consulta somente `areNotificationsEnabled` via `applicationContext`, sem inicialização nem diálogo/Activity. `createSchedulerRunner` usa esse método para ativação no engine secundário. O `checkNotificationPermission` de `flutter_foreground_task` 11 exige Activity e fica restrito ao fluxo principal; requests de permissão continuam na UI.

## Dependências

`flutter_local_notifications` (só em `local_notifications_service.dart`), `popmundo_utils` (`MenuNotificationsWatcher`, `MenuNotification`, `Utils`, scheduler).

## Relacionados

`packages/popmundo_utils/lib/src/menu_notifications/` (watcher/service/state store que produzem os lotes); `DebugOverlay` (botão `debug-send-notification`, sempre em inglês por AD-014); `AppWiring` (`app_wiring.dart`, wiring de `menuNotificationsWatcher`/`menuNotificationsBridge`); `lib/scheduler/`.

## Pontos de entrada

`main.dart`: `LocalNotificationsService().initialize()` seguido de `requestPermission()` antes de `runApp` — no *startup*, não atrás do painel de debug, porque a ponte de notificações do jogo não tem gatilho manual (MENUNOTIF-10). `AppWiring.start()`/`dispose()` (`app_wiring.dart`) iniciam `menuNotificationsWatcher`/`menuNotificationsBridge` e finalizam ambos; a bridge só é construída se `notificationService` não for nulo.

## Observações e débitos

- Tap-to-navigate está deliberadamente fora de escopo: `Url` do item é carregado em `MenuNotification.url` e passado como `payload` para `showNotification`, mas nada lê esse payload ainda (Out of Scope de `popmundo-menu-notifications`).
- `Utils.getMyName()` não usa mais `runtime.evaluate` — lê `/World/Popmundo.aspx/Character` via `TimedFetch` (cacheado) e faz parse do HTML (commit `4ec5f50`); em erro (`TimedFetchException`/`PopmundoRuntimeException`), volta nome vazio.
- Dedup por `UID` é responsabilidade do `MenuNotificationStateStore` em `popmundo_utils`, não deste módulo.
- Gap aceito de cobertura: o `catch` de `LocalNotificationsService.initialize()` (que zera `_initialized` em qualquer exceção) não é exercitado por nenhum teste em nenhum tier — registrado como gap aceito em `.specs/features/local-notifications/validation.md` (NOTIF-08), risco considerado baixo por ser um try/catch simples.
- MENUNOTIF-10 (permissão pedida no startup) não tem teste automatizado dedicado — gap documentado no `spec.md` da feature (`popmundo-menu-notifications`), smoke test manual pendente.
- `test/notifications` cobre a interface e bridges existentes. `scheduler_platform_test` verifica inicialização false, permissão negada, erro nativo e payload exato com ID negativo; `scheduler_runtime_test` verifica os resultados autoritativos. A observação real da bandeja pertence aos testes Android/Patrol. `scheduler_background_permission_test` reproduz a ausência de Activity e confere regra/payload persistidos e denial sem alteração do catálogo.
