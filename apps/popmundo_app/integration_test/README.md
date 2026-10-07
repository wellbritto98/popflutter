# integration_test (Patrol)

Tier **device-real** do app. Spec: `mobile-e2e-tests`. AD-015. Agente: `popmundo-e2e`.

## Objetivo

Exercitar APIs de plataforma que fakes não alcançam: Foreground Service, Keystore, canal SharedPreferences, sockets loopback.

## Responsabilidade principal

**Não** carregar popmundo.com. O entrypoint Dart é o arquivo de teste: `lib/main.dart` **não** roda, logo `PopmundoApp` / `InAppPopmundoRuntime` não existem.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `support/harness.dart` | `initForegroundComms()`, `pumpHarness` (`MaterialApp` mínimo), diálogos de permissão/bateria; bootstrap limitado a 30s após prompts |
| keepalive_test.dart | FGS, notificação e stopWithTask; dois ticks novos enquanto Home |
| session_background_test.dart | BSR-05: HTTP loopback, troca de host e cookies Android, relogin e resultado no sistema com JS suspenso; asserts antes de reabrir |
| `storage_test.dart` | prefs reais |
| `userscripts_test.dart` | superfície mobile do catálogo sem WebView de jogo |
| `smoke_test.dart` | fumaça do harness |
| [scheduler_test.dart](scheduler_test.dart) | Um Patrol test: formulário/prefs reais, FGS após Home, IDs/payload e substituição de cartões Android, pausa sem parar keepalive |
| [game_actions_engine_test.dart](game_actions_engine_test.dart) | Um Patrol test: Keystore real, engine/servidor loopback no FGS, duas ocorrências de item após Home, bônus explícito e cartões Android. Não abre Popmundo; pacote backgrounddebug |
| [support/scheduler_reboot_harness.dart](support/scheduler_reboot_harness.dart) | Entrypoint standalone sem jogo: prepara reboot real e regra semanal GMT para inspeção ADB de prefs, serviço e notificações |

**Exatamente um `patrolTest` por arquivo** (bug upstream Patrol 2005/2380). Agrupe asserts num teste sequencial com `reason`.

## Dependências

`patrol: ^4.9.0`, `patrol_cli` global, `adb`. `androidTest` + `testInstrumentationRunner` no Gradle. Analyze: `flutter analyze integration_test`.

## Relacionados

`lib/background/`, `lib/prefs_store.dart`, `lib/autologin/secure_secret_store.dart`. Não substitui `flutter test`.

## Pontos de entrada

```bash
cd apps/popmundo_app
flutter analyze integration_test
patrol test --target integration_test/keepalive_test.dart -d <device-id>
```

## Observações e débitos

- Tudo que `main()` inicializa (ex.: `initCommunicationPort`) deve ser repetido no harness.
- Título de notificação assertado no harness está em inglês fixo para KA-05.
- `flutter test` não executa esta pasta.

## Scheduler: fixtures e evidência Android

O [scheduler_test.dart](scheduler_test.dart) contém exatamente um `patrolTest`. Usa uma página nativa mínima, o FGS real e uma nova leitura do snapshot persistido para verificar o formulário, duas ocorrências distintas após Home, IDs negativos distintos, título/mensagem exatos no Android, substituição do mesmo cartão após editar texto e ausência de novos claims/cartões após pausar. A pausa preserva o keepalive. O fixture cancela explicitamente seus cartões antes da espera de ausência; remover um cartão antigo não é comportamento atribuído à pausa de produção.

O [support/scheduler_reboot_harness.dart](support/scheduler_reboot_harness.dart) é um entrypoint standalone sem jogo e sem instrumentação Patrol. Ele existe porque um reboot real encerra a instrumentação. O botão `Preparar reboot` salva uma regra durável de 180 segundos; a sequência ADB reinicia o emulador e inspeciona o início do serviço pelo sistema, SharedPreferences, Activities e NotificationManager antes e depois do próximo horário futuro. O primeiro poll anterior ao início do serviço não conta como prova de descarte de ocorrências.

O botão `Preparar semanal GMT` usa o identificador retornado pelo plugin `flutter_timezone`, exige GMT nativo e compara o próximo horário salvo com um UTC independente calculado dois minutos à frente. Pausa as regras anteriores, cancela seus cartões apenas para isolar a prova e cria a regra semanal com o dia ISO e HH:mm correspondentes. Após Home, a evidência exige claim/slot local exatos, próxima ocorrência sete dias depois e exatamente um cartão agendado com o ID e payload salvos. Essa prova posterior à correção do banco de aliases é separada da prova anterior de intervalos.

### Execução e preservação de dados

- Execute `flutter analyze integration_test` antes de qualquer execução no dispositivo. O agente executa o build, Patrol, ADB e diagnóstico; comandos documentados não substituem a execução.
- Use apenas o pacote sintético isolado `com.popmundo.popmundo_app.backgrounddebug`. Nunca limpe, desinstale ou force-stop o app de produção `com.popmundo.popmundo_app`; registre e confira seu primeiro horário de instalação e os inodes de dados. Preserve o AVD e seu userdata, sem wipe nem alteração do relógio/fuso para mascarar falhas.
- Para a corrida registrada, Patrol usou `--profile --package-name com.popmundo.popmundo_app.backgrounddebug --no-uninstall --no-check-compatibility`; a fonte de verdade é o XML de instrumentação e o logcat, não apenas o resumo do CLI. Cada arquivo continua com um único teste Patrol.
- A build standalone registrada usou `flutter build apk --profile --target integration_test/support/scheduler_reboot_harness.dart --target-platform android-x64`, com aplicação isolada configurada antes da instalação. Ela nunca usa `lib/main.dart`, `PopmundoApp` ou WebView do jogo.
- O emulador exigiu configuração temporária de profile AOT com inspeção de prefs, minificação desligada, assinatura debug, ABI x64 e promoção da dependência nativa Patrol. Restaure `android/app/build.gradle.kts`, `android/gradle.properties`, `pubspec.yaml` do app e `pubspec.lock` antes de concluir. Essas alterações não pertencem aos commits. Execute `flutter pub get` normal e reconstrua o release sem `--no-pub` para atualizar o registro de plugins.
- Mantenha um único job Flutter/Gradle por vez. Use esperas limitadas e o UTC do dispositivo para comparar horários. Depois de reter a evidência, a limpeza pode atingir somente os dados do pacote sintético que o fixture criou.

### Prova de discriminação e limites

Um teste novo precisa ficar vermelho com o bug correspondente reintroduzido em scratch, seguido de restauração e verde. A mutação que suprimia a submissão das notificações negativas deixou o estado persistido como `submitted`, mas o teste nativo falhou com total esperado 2 e total Android 0. O XML seguinte passou 1/1 após descartar a mutação. Assim, o status persistido não substitui a prova do cartão real.

A evidência observada cobre um AVD Android 16/API 36/x86_64: Home, tela apagada em `Asleep`, remoção efetiva das próprias tarefas de Recents, reboot ADB e semana em GMT. Não comprova handset físico, políticas de outros fabricantes, lock com autenticação/PIN, force-stop bypass ou execução overnight. A entrega é controlada pelo Android.

Referências e oráculos reproduzíveis:

- [Spec service-scheduler](../../../.specs/features/service-scheduler/spec.md), [design](../../../.specs/features/service-scheduler/design.md) e AD-021 em [STATE](../../../.specs/STATE.md).
- [Relatório T6 e asserções file:line / jq](../../../.specs/features/service-scheduler/evidence/device-task-gates.md).
- [Patrol verde](../../../.specs/features/service-scheduler/evidence/patrol-final-green.xml), [mutante vermelho](../../../.specs/features/service-scheduler/evidence/patrol-native-mutant.xml) e [patch scratch descartado](../../../.specs/features/service-scheduler/evidence/native-suppression-mutant.patch).
- [Snapshot após reboot](../../../.specs/features/service-scheduler/evidence/android-reboot-future.json) e [cartões Android](../../../.specs/features/service-scheduler/evidence/android-reboot-future-cards.txt).
- [Snapshot semanal GMT](../../../.specs/features/service-scheduler/evidence/android-weekly-delivered.json), [cartão semanal](../../../.specs/features/service-scheduler/evidence/android-weekly-delivered-cards.txt) e [atribuição de fonte/APK](../../../.specs/features/service-scheduler/evidence/weekly-source-attribution.txt).

## Ações de jogo: fronteira do engine Android

support/game_actions_fixture.dart reconstrói um HttpServer na engine secundária e injeta somente o transporte em createSchedulerRunner. Credenciais, Keystore, coordenador, persistência e notificações são os componentes de produção. O socket usa exclusivamente 127.0.0.1; URLs lógicas de autenticação não são discadas. Os personagens 91002/91003 e banda 92002 são sintéticos.

Na primeira requisição de cada ocorrência, o servidor confere o claim já persistido, jar inicialmente vazio e cartão Android com ID da regra, serviço e personagem salvo. Verifica também o POST inteiro: controles repetidos, estado fresco, primeiro item elegível depois de uma linha homônima de afinação, ou bônus 20 com botão atual e preço obtido no formulário fresco. A evidência persistida guarda apenas IDs, slots UTC, contagens e códigos de violação; senhas e formulários permanecem em memória.

support/game_actions_reboot_harness.dart existe porque reboot encerra a instrumentação. Seus botões preparam remoção efetiva da própria tarefa de Recents ou um POST sintético interrompido por reboot. O servidor é reconstruído pelo callback persistido; a ocorrência interrompida deve receber skippedInterrupted, sem repetir o slot, e somente uma ocorrência futura pode produzir novo POST. A prova usa ADB para inspecionar oracle/prefs, ausência de Activity, serviço e cartões antes de abrir novamente o app. A limpeza remove somente chaves, segredo e notificações do pacote sintético.

Esses entrypoints cobrem a fronteira Android de SGA-10; os casos de parser, orçamento, cancelamento e resultados ambíguos continuam no tier core. Resultados observados e limites ficam em .specs/features/scheduled-game-actions/evidence/. A existência dos fixtures não constitui evidência de execução: somente XML/logs e inspeções registradas contam.

A prova registrada para essas ações está em [T8 Android secondary-engine proof](../../../.specs/features/scheduled-game-actions/evidence/t8-device-gates.md): XML Patrol verde, sensor nativo vermelho/restaurado, duas ocorrências após Home, POSTs com tarefas efetivamente removidas e reconstrução pelo sistema após reboot. O reboot interrompido preserva skippedInterrupted e executa somente o próximo slot futuro. O primeiro ensaio, que atingiu timeout antes do reboot, fica identificado separadamente como evidência de uncertain sem replay.
