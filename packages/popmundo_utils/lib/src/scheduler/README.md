# Núcleo de agendamentos locais

Este submódulo implementa os modelos, o calendário e a autoridade de persistência do scheduler em Dart puro. O import público é package:popmundo_utils/popmundo_utils.dart. Não depende de Flutter, WebView, plugins, HTTP do jogo, credenciais ou avaliação JS. A dependência timezone ^0.11.1 fornece o calendário IANA; o adapter inicializa sua base e informa o identificador atual do dispositivo.

## Arquivos e API pública

| Arquivo | Responsabilidade |
| --- | --- |
| scheduler_models.dart | ScheduleDraft, ScheduledRule, ScheduleRecurrence, IntervalRecurrence, IntervalUnit, WeeklyRecurrence, LocalNotificationAction, ScheduleClaim, ScheduleResult, ScheduleResultStatus, SchedulerSnapshot e SchedulerException |
| recurrence_calculator.dart | RecurrenceCalculator.nextAfter, isEligible e localSlot |
| scheduler_ports.dart | SchedulerStore e ScheduledActionExecutor, implementados pelo adapter |
| scheduler_coordinator.dart | SchedulerCoordinator: load, list, reconcile, fila e tentativa de execução |
| scheduler_commands.dart | Parte da biblioteca do coordenador; extensão pública SchedulerCommands com create, update, toggle e delete |

ScheduleDraft recebe name, recurrence, action e enabled (true por padrão). Os modelos removem espaços nas extremidades do nome, título e mensagem; os limites são 1–80, 1–120 e 1–1000 unidades UTF-16 (Dart String.length), sem truncamento silencioso. LocalNotificationAction é a única ação atual, com title e body. IntervalRecurrence recebe quantity (1 por padrão), unit (minutes por padrão) e anchorUtc obrigatório. A quantidade inteira aceita 1–9999; unidades são seconds, minutes, hours e days. WeeklyRecurrence exige weekdays como conjunto ISO não vazio de 1–7, hour de 0–23 e minute de 0–59. Campos públicos são finais; listas/conjuntos expostos pelo modelo são imutáveis.

## Snapshot e identidade

SchedulerSnapshot.storageKey é service_scheduler.v1. O store trabalha com uma string JSON completa; o adapter aplica essa chave. encode/decode/toJson usam schemaVersion 1, nextSequence e rules. Cada ScheduledRule guarda id lógico, revision, notificationId, name, enabled, recurrence, action, nextDueUtc, zoneId, lastClaim e lastResult. O cursor opcional lastAttemptUtc é emitido no JSON quando presente.

O notificationId é o negativo de uma sequência monotônica de 1 a 2147483648, portanto vai de -1 a -2147483648. Regras distintas têm IDs de notificação distintos; edição/reinício preservam o ID, e a exclusão não recicla a sequência. nextNotificationId lança idExhausted ao esgotar o intervalo. O id lógico é fornecido pelo chamador de create e uma duplicata no catálogo é rejeitada com duplicateId; isso permite reutilizar a mesma identidade de solicitação ao consultar um salvamento incerto, sem alocar outra regra.

A decodificação de JSON corrupto ou versão desconhecida falha com SchedulerException. O coordenador não reseta nem apaga esse blob e não executa seus registros. O adapter deve apresentar a indisponibilidade; a leitura de um valor ausente produz catálogo vazio.

## Portas e comandos

    abstract interface class SchedulerStore {
      Future<String?> read();
      Future<void> write(String snapshot);
    }

    abstract interface class ScheduledActionExecutor {
      Future<void> execute({
        required LocalNotificationAction action,
        required int notificationId,
      });
    }

O store deve ler estado atual e lançar erro quando não puder confirmar uma gravação. Apenas o engine dono do coordenador escreve o snapshot. O executor recebe os campos salvos da ação e o ID estável; erros devem usar categorias sem dados secretos. O registro atual usa a chave localNotification. Concluir o Future significa que a plataforma aceitou a solicitação, sem afirmar que alguém viu a notificação.

SchedulerCoordinator recebe store, executors (mapa de tipo para executor), now (DateTime Function()), zoneId (String Function()) e calculator opcional. Todos os métodos retornam Future<SchedulerSnapshot>:

- load() faz uma leitura nova e aplica a política de inicialização.
- list() retorna o catálogo da autoridade, carregando-o se necessário.
- create(draft, id: ...) aloca a regra e sua identidade de notificação.
- update(id, draft, expectedRevision: ...) substitui os campos editáveis.
- toggle(id, expectedRevision: ..., enabled: ...) altera a ativação.
- delete(id, expectedRevision: ...) remove a regra, preservando nextSequence.
- reconcile() avalia o estado atual e os slots armados.

Comandos e ticks compartilham uma fila, inclusive os awaits de claim e ação. Atualizações, toggles e exclusões rejeitam revisões antigas com revisionConflict e IDs ausentes com ruleNotFound. Os comandos retornam sucesso após a gravação. Edição apenas de texto preserva anchor e próximo slot; alteração de recorrência ou reativação estabelece um novo futuro, limpa claim/watermark e ancora intervalos em now. Regras desativadas não têm próximo slot armado. Uma ação já claimed antes de uma pausa pode terminar; candidates avaliados depois usam o catálogo atualizado.

## Calendário e execução

RecurrenceCalculator.nextAfter(recurrence, now, zoneId: ...) devolve o primeiro instante estritamente futuro. Intervalos seguem anchorUtc + nD, com n positivo; um dia significa 24 horas decorridas e a conclusão da ação não muda a âncora. Regras semanais iteram datas locais no fuso informado. Múltiplos dias selecionados recorrem; uma mudança no identificador de fuso rearma a regra no reconcile seguinte. Um horário inexistente avança pelo tamanho do salto de horário de verão; um horário repetido usa a primeira cópia. localSlot registra a data e o HH:mm escolhidos, inclusive quando o horário real foi deslocado por uma lacuna.

Na inicialização, load pula todos os slots em ou antes de now, rearma o próximo futuro e não emite notificações recuperadas. Uma claim sem timestamp de resultado é interrompida: vira skippedInterrupted e é descartada. A claim concluída permanece como cursor. lastAttemptUtc guarda o instante planejado da tentativa e impede repetição mesmo quando o relógio retrocede. Snapshots anteriores sem esse campo migram lastClaim.plannedUtc antes de remover uma claim interrompida.

Durante operação, isEligible aceita somente o slot atualmente armado, nunca antecipado, com atraso inclusivo de min(30 segundos, duração do intervalo) ou 30 segundos para semanal. Um slot mais antigo é pulado. Cada avaliação executa no máximo uma ocorrência por regra, sem loop de recuperação.

Antes de chamar o executor, o coordenador grava claim, lastAttemptUtc, próxima ocorrência futura e resultado ainda sem timestamp. A garantia é uma tentativa no máximo por slot: se o processo morrer após o claim, uma notificação pode ser perdida. O core não promete uma transação entre persistência e notificação nativa. SchedulerCoordinator.actionTimeout limita a espera da ação a cinco segundos; o Future subjacente pode concluir depois, mas o slot não é reenviado.

## Falhas e resultados

ScheduleResultStatus contém neverExecuted, submitted, failed e skippedInterrupted. ScheduleResult guarda atUtc e errorCode opcionais. O sucesso registra submitted; erro do executor ou timeout registra failed, permite continuar outras regras e mantém o próximo futuro sem retry imediato. Timeout usa actionTimeout; exceções SchedulerException do executor preservam sua categoria e outros erros usam actionFailed. Um executor ausente usa executorUnavailable.

Falhas de leitura/gravação usam readFailed/writeFailed. A falha de claim impede a chamada ao executor. Se a gravação do resultado falhar após a ação, o comando lança resultUncertain; o catálogo em memória é invalidado e a próxima operação relê o store sob a política de inicialização. Isso também trata uma gravação que chegou ao store antes de lançar erro, sem assumir rollback nem reenviar um slot incerto.

Fuso IANA inválido produz zoneUnavailable. Criar/reativar uma regra semanal com esse problema falha; em um catálogo existente a regra é preservada, fica sem due e registra falha visível. Intervalos continuam funcionando, e reconcile rearma o semanal quando o fuso volta a ser válido. Permissões, configuração de boot, Timer e envio nativo pertencem ao adapter do app.

## Verificação

Os testes ficam em packages/popmundo_utils/test/scheduler_models_test.dart, recurrence_calculator_test.dart e scheduler_coordinator_test.dart. Eles usam store/executor falsos e relógio determinístico, cobrindo limites e payload JSON, UTC/zonas/DST, startup e atraso, IDs, revisões e concorrência, falhas de escrita/ação, timeout e relógio retrocedendo. Execute dart test e dart analyze no pacote. A prova do serviço e das notificações no Android pertence ao tier de integração do app.
