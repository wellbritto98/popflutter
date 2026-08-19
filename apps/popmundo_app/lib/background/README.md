# background (`popmundo_app`)

Keepalive de processo. Spec: `background-keepalive`. AD-012, AD-013.

## Objetivo

Manter um Foreground Service Android (e o melhor esforço no iOS) **sem** TimedFetch e **sem** WebView no isolate. O GET de sessão (`/World/Popmundo.aspx/Character`) **não** vive aqui — é o timer do `AutoLoginController` (AD-019); o FGS só impede o OS de matar o processo.

## Responsabilidade principal

Permissões, start/stop do FGS, heartbeat para a UI de debug, textos da notificação via i18n.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `background_keepalive.dart` | `bootstrap()`, lifecycle, `ValueNotifier<BackgroundStatus>` |
| `background_platform.dart` | Porta (testável) |
| `flutter_foreground_task_platform.dart` | Plugin real; `stopWithTask: false` |
| `keepalive_task_handler.dart` | Isolate: só emite heartbeat |
| `background_status.dart` | serviceRunning, notification, battery, lifecycle, lastHeartbeat |

`main()` **e** o harness Patrol chamam `FlutterForegroundTask.initCommunicationPort()`.

## Dependências

`flutter_foreground_task`. Manifest: `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`, battery, `android:stopWithTask="false"`. iOS: `UIBackgroundModes: fetch`.

## Relacionados

`DebugOverlay` mostra `backgroundStatus`. Não acoplar isso a Auto Login.

## Pontos de entrada

`BackgroundKeepalive.bootstrap()` no post-frame de `PopmundoHome`.

## Observações e débitos

- iOS não oferece JS contínuo em background (spec honesto).
- Teto `dataSync` no Android 15+.
- Título da notificação de teste Patrol está hardcoded no harness (`Popmundo is running`) para bater KA-05 — produção usa `.tr()`.
