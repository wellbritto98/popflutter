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
