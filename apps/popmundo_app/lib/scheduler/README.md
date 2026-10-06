# scheduler (popmundo_app)

Adapter Android e UI nativa para regras recorrentes de notificação local. Spec: service-scheduler; decisão AD-021. Modelos, cálculo de recorrência e coordenador são do pacote puro popmundo_utils.

## Responsabilidades

O engine do Foreground Service é o único escritor do JSON service_scheduler.v1. A UI não instancia coordenador nem salva esse catálogo diretamente. PreferencesSchedulerStore chama reload antes de read e trata setString false como writeFailed; JSON inválido ou versão desconhecida fica preservado.

| Arquivo | Papel |
| --- | --- |
| scheduler_environment.dart | createSchedulerRunner compõe timezone, prefs, executor local e portas do FGS no engine secundário |
| scheduler_runner.dart | SchedulerRunner.start/receive/reconcile/dispose; fila serial, um Timer para o próximo vencimento e reconciliação coalescida |
| scheduler_store.dart | Adapter SchedulerStore.read -> String? e write(String) |
| device_zone.dart | flutter_timezone, lookup limitado a 1s, zona IANA válida e cache da última válida |
| scheduler_client.dart | SchedulerApi e SchedulerClient: RPC da UI, IDs correlacionados e validação da resposta |
| scheduler_connection.dart | waitForSchedulerService espera heartbeat Dart, com prazo de 12s, antes do primeiro RPC |
| scheduler_screen.dart | Lista, próximo horário/último resultado, permissões, pausa, edição e exclusão confirmada |
| scheduler_menu_item.dart | `schedulesMenuItem` — `AppMenuItem` desta feature, consumido na lista `items:` de `app.dart` |
| scheduler_editor.dart | Formulário intervalar/semanal e submissão autoritativa com ID estável |
| scheduler_recurrence_fields.dart | Quantidade/unidade, dias ISO e seletor explicitamente 24h |
| scheduler_permissions_card.dart | Status de notificação, bateria e serviço; ações para permissões |
| scheduler_labels.dart | Labels e distinção entre erro de comando e resultado de execução EN/PT |

## Transporte e execução

A comunicação usa FlutterForegroundTask.sendDataToTask/sendDataToMain. Requests têm type scheduler.request, requestId e command list/create/update/toggle/delete. Mutação inclui id estável, draft e revision quando aplicável. Replies type scheduler.response devolvem requestId e snapshot ou error tipado; heartbeat continua no envelope independente heartbeat.

SchedulerApi oferece list(), create(draft, id), update(rule, draft), toggle(rule, enabled) e delete(rule). SchedulerClient espera prontidão e limita o RPC a 15s; nunca reenvia uma mutação automaticamente. Timeout de resposta não prova que a gravação falhou.

O editor guarda o mesmo ID durante a tentativa. Após falha, relê o catálogo antes de liberar novo save: se a criação foi persistida, adota a regra/revisão e uma nova submissão é update. Releitura falha mantém a edição e bloqueia ressubmissão. A UI só confirma após snapshot autoritativo; cancel não salva. Campos aceitam o conteúdo completo e validam limites UTF-16 após trim (nome 80, título 120, corpo 1000); quantidade inteira 1–9999.

O runner rearma um único Timer no vencimento mais próximo após comandos/reconciliação. Heartbeat nativo de 5s reconcilia interrupções e mudanças de zona; ticks simultâneos compartilham a mesma Future. DeviceZone conserva a última zona válida após falha transitória; primeira falha permanece indisponível, sem UTC silencioso. Intervalos continuam independentes da zona. O core define claim persistido antes do efeito, sem replay de slots perdidos e timeout da ação de 5s.

A lista aberta consulta snapshots a cada 5s, coalescendo leituras; pausa essas consultas quando o app está inativo ou o editor aberto e cancela ao destruir a rota. Resultado submitted significa que Android aceitou a chamada de notificação, não que o usuário a viu.

## Plataforma e limites

Agendamentos contínuos são Android-only. iOS mostra explicação localizada e não oferece criação. Não há AlarmManager, WorkManager, backend, WebView, autenticação ou gameplay dentro do scheduler. O serviço mantém sua notificação de sessão separada dos cards dos agendamentos.

Boot/package replacement são configurados pela presença de qualquer regra enabled. Nenhuma regra ativa desliga esses flags, sem parar o keepalive existente. Após morte/reinício, o core pula vencimentos perdidos e arma o próximo futuro. Force-stop, permissão revogada e políticas do OS/fabricante impedem garantias de continuidade; a implementação não promete entrega em horário real rígido.

## Verificação

scheduler_runtime_test, scheduler_client_test, scheduler_platform_test e scheduler_edge_test exercitam as portas de runtime. scheduler_connection_test prova prontidão limitada; scheduler_task_handler_test prova recuperação da factory, ownership após timeout e descarte tardio; scheduler_editor_test e scheduler_screen_test conferem payload persistido, retenção, ID estável, estados e refresh. app_menu_registry_test preserva callbacks/gating e o item de release. Evidência de Home/Recents/reboot/tray é responsabilidade do tier integration_test, com relatório separado em .specs/features/service-scheduler/evidence.

A verificação de ativação usa LocalNotificationsService.isScheduledNotificationGranted(), que consulta NotificationManagerCompat/applicationContext por flutter_local_notifications. A API checkNotificationPermission do FGT requer Activity e não é usada no engine de serviço. Pedidos de permissão continuam no shell principal. scheduler_background_permission_test cobre a composição real com Activity ausente, payload persistido e denial sem gravação.

scheduler_environment inicializa timezone/data/latest_all.dart: banco IANA completo, incluindo aliases válidos GMT/UTC retornados pelo Android. DeviceZone conserva o identificador nativo literal validado, sem fallback arbitrário. scheduler_background_zone_test exercita createSchedulerRunner com o map nativo GMT e confere regra semanal habilitada, zoneId GMT e próxima execução exata amanhã às 09:00 UTC.

## Configuração tipada de ações (AD-023)

O RPC valida ScheduledAction: localNotification, useItem ou payCrew. Cada ação de jogo preserva conta vinculada, personagem por ID/nome e parâmetros do efeito. Edição de nome/recorrência de uma regra de jogo salva funciona offline e conserva seu payload; os campos de título/mensagem pertencem apenas à notificação local. Os resultados confirmados, indisponíveis e incertos do core possuem labels EN/PT próprios, distintos de submitted local.

`createSchedulerRunner` monta `GameActionsService` com jar vazio, relê usuário/senha/status do Auto Login a cada transação e publica avisos pelo caminho estrito de notificação. O texto EN/PT sai dos assets, com o locale recém-lido das preferências, e inclui o nome do personagem salvo. `GameActionsApi` no cliente expõe discoverCharacters/Items/Crew; a resposta carrega só DTOs. Códigos de jogo desconhecidos viram `runtimeUnavailable`. `dispose` do runner cancela o executor e espera o HTTP fechar. `AppWiring.dispose` encerra o cliente e completa RPCs pendentes com `serviceUnavailable`. A seleção visual das ações fica no editor.
