# notifications (popmundo_app)

Adapter de notificações locais e bridge de eventos observados do jogo. A implementação real concentra flutter_local_notifications em LocalNotificationsService.

## Consumidores existentes

NotificationService mantém initialize, requestPermission, showTestNotification e showNotification. initialize captura erro e marca a disponibilidade; os métodos genéricos não fazem nada quando não inicializados, preservando o contrato do painel de debug, Auto Login e notificações do jogo. FakeNotificationService é a porta de teste desses consumidores.

| Uso | Canal / identidade |
| --- | --- |
| FGS de sessão | popmundo_keepalive, definido pelo adapter background |
| Teste manual do overlay | popflutter_debug_channel, id 1 |
| Resultado de Auto Login | notificação genérica, id 2 |
| Menu do jogo | popflutter_game_notifications_channel; MenuNotificationsBridge usa UID do evento |
| Agendamento local | popflutter_schedules; ID negativo estável alocado pelo core |

## Executor de agendamentos

showScheduledNotification({required int id, required String title, required String body}) é um caminho estrito separado. Antes da primeira submissão exige initialize retornar true; falha produz SchedulerException notificationInitializationFailed. Exige adapter Android e areNotificationsEnabled true; ausência/negação produz permissionDenied. Erros de show propagam para o coordenador, que persiste failed; não há sucesso silencioso.

ScheduledNotificationExecutor em scheduler_environment.dart passa o notificationId e o título/corpo salvos diretamente. O mesmo ID substitui o card anterior da mesma regra; IDs de regras diferentes não colidem com os usos positivos existentes. O core mantém o contador após exclusão. Pausa/exclusão impedem próximas submissões; não removem um card já visível.

O serviço secundário inicializa seu próprio plugin; não depende da inicialização feita em main. submitted registra retorno bem-sucedido da requisição ao OS, sem afirmar que a pessoa viu o card. Não se usa o scheduling nativo do plugin: o Timer/reconciliação ficam no SchedulerRunner.

## Verificação

test/notifications cobre a interface e bridges existentes. scheduler_platform_test verifica inicialização false, permissão negada, erro nativo e payload exato com ID negativo; scheduler_runtime_test verifica os resultados autoritativos. A observação real da bandeja pertence aos testes Android/Patrol.

isScheduledNotificationGranted() consulta somente areNotificationsEnabled via applicationContext, sem inicialização nem diálogo/Activity. createSchedulerRunner usa esse método para ativação no engine secundário. O checkNotificationPermission de flutter_foreground_task 11 exige Activity e fica restrito ao fluxo principal; requests de permissão continuam na UI. scheduler_background_permission_test reproduz a ausência de Activity e confere regra/payload persistidos e denial sem alteração do catálogo.
