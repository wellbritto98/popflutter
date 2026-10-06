# background (popmundo_app)

Keepalive de processo e host Android do scheduler local. Specs: background-keepalive e service-scheduler. AD-012, AD-013, AD-020, AD-021.

## Responsabilidades

Permissões, início do Foreground Service, heartbeat para o shell e hospedagem do SchedulerRunner no engine secundário. O FGS usa specialUse; o subtype declara manutenção da sessão e agendamentos locais do usuário. Não há WebView nem TimedFetch nesse engine. O GET de sessão permanece no timer do AutoLoginController (AD-019).

| Arquivo | Função |
| --- | --- |
| background_keepalive.dart | bootstrap/lifecycle e ValueNotifier de status |
| background_platform.dart | Porta testável de permissão, bateria e serviço |
| flutter_foreground_task_platform.dart | Adapter real, opções completas e flags derivados do catálogo |
| keepalive_task_handler.dart | Entrypoint registrado; cria scheduler Android, recebe RPC, emite heartbeat e reconcilia |
| background_status.dart | serviceRunning, notification, battery, lifecycle e lastHeartbeat |

main e harness Patrol chamam FlutterForegroundTask.initCommunicationPort. keepaliveStartCallback chama setTaskHandler, que inicializa bindings e registro de plugins para o engine secundário. O início registra scheduler.start com UTC e TaskStarter, sem conteúdo/IDs das regras.

## Opções e continuidade

schedulerOptions(enabled) mantém repeat(5000), allowWakeLock true, allowWifiLock false, allowAutoRestart true e stopWithTask false. autoRunOnBoot e autoRunOnMyPackageReplaced seguem a existência de regra enabled, lida de prefs com reload na inicialização. JSON corrompido não impede o keepalive original de iniciar: flags do scheduler ficam false e o blob é preservado.

configureSchedulerBoot atualiza as opções completas após operações autoritativas; mantém cache do último boolean aplicado com sucesso para evitar gravar a cada heartbeat. Falha de configuração retorna bootConfigurationFailed, sem falso ACK. Pausar/excluir a última regra não para o serviço de sessão.

onStart espera a inicialização do scheduler por até 5s. onRepeatEvent sempre envia heartbeat imediatamente e dispara reconciliação sem aguardá-la; comandos usam namespace próprio scheduler.request/response. Falha de leitura do catálogo mantém o runner e pode se recuperar após leitura válida por heartbeat/RPC. onDestroy marca o engine como encerrado, cancela o executor de jogo e só retorna depois que o dispose do HTTP termina. Um runner que nasce depois do destroy também é cancelado e esperado, sem start.
Falha temporária da factory antes de retornar um runner permite nova tentativa no próximo heartbeat/RPC. A Future subjacente mantém ownership após o timeout de 5s: uma tentativa ainda pendente nunca cria um segundo escritor; resultado tardio após destroy é descartado e disposto sem start.

## Plataforma

Android depende de flutter_foreground_task, shared_preferences e adapters scheduler. Manifest usa FOREGROUND_SERVICE_SPECIAL_USE, POST_NOTIFICATIONS, bateria e stopWithTask false; boot restoration usa a infraestrutura do plugin. iOS mantém o caminho de keepalive existente e UIBackgroundModes fetch, sem scheduler contínuo.

Force-stop e políticas do OS/fabricante podem encerrar o serviço. Com regras habilitadas, a configuração solicita restauração após boot/replacement; slots perdidos são pulados pelo core. Não há garantia de entrega rígida ou trabalho contínuo no iOS. Distribuição Play exige revisão do caso specialUse.

DebugOverlay mostra backgroundStatus. O scheduler aguarda um heartbeat Dart real antes de enviar o primeiro comando da UI; o flag nativo running sozinho não prova que o canal já está pronto. Testes unitários usam FakeBackgroundPlatform; lifecycle real pertence ao tier Patrol.
