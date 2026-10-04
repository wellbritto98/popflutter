# Background Keepalive Specification

## Problem Statement

Quando o jogador coloca o Popflutter em segundo plano (home, outro app, tela bloqueada), o SO pode matar o processo ou restringir a bateria, derrubando a sessão viva do WebView. O app não pede permissões de segundo plano nem oferece prova observável no debug panel de que o keepalive está ativo. Precisamos de um bootstrap na primeira abertura (Android: notificação + isenção de bateria + Foreground Service; iOS: notificação) e status + heartbeat no debug panel, no estilo da linha `host:`.

## Goals

- [ ] Na primeira abertura, o app solicita as permissões de plataforma necessárias para keepalive (Android) / notificação (iOS) sem bloquear o WebView
- [ ] No Android, um Foreground Service com notificação persistente e isenção de bateria mantém o processo elegível a sobreviver em segundo plano
- [ ] O debug panel mostra status de permissões, lifecycle e heartbeat (prova de vida)

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Envio de push / remote notifications | Feature futura; só pedimos permissão de notificação no iOS agora |
| `autoRunOnBoot` / restart após reboot | Política Play / fora do pedido |
| `SCHEDULE_EXACT_ALARM` | Política restritiva; não necessário para FGS |
| UIBackgroundModes `audio` / `location` | Sem justificativa real; risco de rejeição App Store |
| Autostart de fabricante (Xiaomi etc.) | Fora do controle do app |
| Desktop / Flutter Web | AD-008 — MVP é Android + iOS |
| i18n | Strings nativas em inglês (padrão do shell) |
| Mutar intercept (AD-003) | Observe-only permanece |
| TimedFetch / WebView no isolate do FGS | Isolate só emite heartbeat; sessão fica no processo principal |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Objetivo Android | FGS (`specialUse`) + notificação persistente + isenção de bateria | Pedido explícito do usuário | y |
| Objetivo iOS | Pedir notificação na abertura; JS da página para ao suspender; sessão via cookies (AD-004) | Limite da plataforma; pedido explícito | y |
| Plugin | Só `flutter_foreground_task` (sem `permission_handler` paralelo) | Cobre notif + bateria + FGS + heartbeat | y |
| Momento do prompt | Pós-primeiro-frame em `PopmundoHome`; não bloqueia o WebView | Pedido: pedido inicial ao abrir | y |
| Negativa do usuário | App continua em foreground; debug mostra denied; sem re-prompt a cada launch | SO só mostra o diálogo uma vez; sem loop | y (agent) |
| Debug UI | Linhas densas sob o host: `bg`, `notif`, `battery`, `lifecycle`, `heartbeat` | Pedido explícito | y |
| Idioma UI | Inglês | Consistente com debug overlay existente | y |
| Auto boot / exact alarm | Desligado | Fora de escopo / política | y |

**Open questions:** none — all resolved or logged above.

---

## User Stories

### P1: Bootstrap de permissões na primeira abertura ⭐ MVP

**User Story**: As a player, I want the app to ask for the necessary background-related permissions when I first open it so that session keepalive can work without a separate settings hunt.

**Why P1**: Sem o prompt, o FGS Android não mostra notificação (API 33+) e a isenção de bateria não é concedida.

**Acceptance Criteria**:

1. WHEN the home screen completes its first frame THEN the system SHALL request notification permission (Android 13+ / iOS) without blocking WebView bootstrap or navigation.
2. WHEN the platform is Android and battery optimizations are still enforced THEN the system SHALL request ignore-battery-optimizations (system dialog / settings intent).
3. WHEN the user denies any of those prompts THEN the system SHALL continue running in the foreground, SHALL NOT crash, and SHALL surface the denied state in the debug panel.
4. WHEN the app is launched again after a prior denial THEN the system SHALL NOT force a second system dialog on every launch (OS controls re-prompt).

**Independent Test**: Unit test of the facade with a fake platform adapter: denied paths return without throw; notification/battery request methods are invoked once per bootstrap.

---

### P1: Foreground Service Android ⭐ MVP

**User Story**: As a player on Android, I want a persistent “Popmundo is running” notification and a foreground service so the OS is less likely to kill the process while I am in another app.

**Why P1**: É o mecanismo real de keepalive no Android; isenção de bateria sozinha não basta.

**Acceptance Criteria**:

1. WHEN bootstrap completes on Android and the service is not already running THEN the system SHALL start a foreground service of type `specialUse` with a persistent notification titled such that it communicates the app is running (e.g. “Popmundo is running”).
2. WHEN the foreground service is running THEN `serviceRunning` in the keepalive status SHALL be true and the debug panel SHALL show `bg: running`.
3. WHEN the service is already running THEN bootstrap SHALL NOT start a second instance (idempotent).
4. WHEN the Android manifest is inspected THEN it SHALL declare `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `WAKE_LOCK`, and the plugin `ForegroundService` with `foregroundServiceType="specialUse"`.

**Independent Test**: Facade unit test asserts `startService` only when `!isRunning`; `platform_config_test` asserts manifest strings.

---

### P1: Debug panel — status + heartbeat ⭐ MVP

**User Story**: As a developer, I want the debug panel to show permission status, lifecycle, and last heartbeat like the host line so I can verify keepalive without adb.

**Why P1**: Pedido explícito de validação observável.

**Acceptance Criteria**:

1. WHEN the debug panel is visible THEN it SHALL show dense lines under the host for: `bg: running|stopped`, `notif: granted|denied`, `battery: unrestricted|optimized|n/a`, `lifecycle: <AppLifecycleState name>`, `heartbeat: <relative or never>`.
2. WHEN each of those lines is rendered THEN it SHALL be findable by keys `debug-bg-service`, `debug-bg-notif`, `debug-bg-battery`, `debug-bg-lifecycle`, `debug-bg-heartbeat`.
3. WHEN the TaskHandler emits a heartbeat THEN `lastHeartbeat` SHALL update and the heartbeat line SHALL reflect a recent tick (not stuck at “never” while the service is running in tests with injected status).
4. WHEN the platform is iOS THEN `battery` SHALL display `n/a`.

**Independent Test**: Widget test pumps `DebugOverlay` with injected status and asserts keys + text.

---

### P2: iOS — notificação + heartbeat honesto

**User Story**: As a developer on iOS, I want notification permission requested at launch and an honest debug view (suspended lifecycle / frozen heartbeat) so I do not confuse cookie session survival with live JS.

**Why P2**: Necessário para paridade de prompt e honestidade de plataforma; não mantém JS vivo.

**Acceptance Criteria**:

1. WHEN the app first opens on iOS THEN the system SHALL request notification permission.
2. WHEN `Info.plist` is inspected THEN it SHALL include `UIBackgroundModes` containing `fetch` and `BGTaskSchedulerPermittedIdentifiers` containing `com.pravera.flutter_foreground_task.refresh`.
3. WHEN the app is backgrounded on iOS THEN the debug panel SHALL be allowed to show a non-`resumed` lifecycle and a heartbeat that stops advancing (honest suspended state) — session cookies remain per AD-004.

**Independent Test**: `platform_config_test` for plist keys; facade/widget tests cover status display; live UAT for suspend behavior.

---

## Edge Cases

- WHEN notification permission is denied THEN FGS may still start on Android but the persistent notification may be hidden by the OS; debug shows `notif: denied`.
- WHEN battery exemption is denied THEN service may still start; debug shows `battery: optimized`.
- WHEN `startService` is called while already running THEN no second start (idempotent).
- WHEN TaskHandler isolate cannot reach main THEN heartbeat stays at previous value / never — UI does not crash.
- WHEN bootstrap runs before WebView attach THEN WebView load is unaffected (keepalive is independent).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| BG-01 | P1: Bootstrap permissions | Design | Pending |
| BG-02 | P1: Bootstrap permissions (battery Android) | Design | Pending |
| BG-03 | P1: Bootstrap denial handling | Design | Pending |
| BG-04 | P1: No forced re-prompt every launch | Design | Pending |
| FGS-01 | P1: Start FGS + notification | Design | Pending |
| FGS-02 | P1: serviceRunning / bg: running | Design | Pending |
| FGS-03 | P1: Idempotent start | Design | Pending |
| FGS-04 | P1: Android manifest declarations | Design | Pending |
| DBG-01 | P1: Debug lines under host | Design | Pending |
| DBG-02 | P1: Debug keys | Design | Pending |
| DBG-03 | P1: Heartbeat updates | Design | Pending |
| DBG-04 | P1: battery n/a on iOS | Design | Pending |
| IOS-01 | P2: iOS notification request | Design | Pending |
| IOS-02 | P2: Info.plist background keys | Design | Pending |
| IOS-03 | P2: Honest suspended state | Design | Pending |

**Coverage:** 15 total, mapped in tasks.md

---

## Success Criteria

- [ ] Opening the app on Android shows notification + battery prompts (when not already granted) and a persistent FGS notification while the service runs
- [ ] Debug panel shows accurate permission, lifecycle, and heartbeat status
- [ ] iOS asks for notifications; plist has required keys; debug remains honest when suspended
- [ ] `flutter test` in `apps/popmundo_app` is green; no live popmundo.com e2e required

## Continuous session amendment (2026-10-04, AD-020)

Usuário confirmou funcionamento durante a noite. Serviço specialUse declara subtype de manutenção contínua de sessão; o limite de seis horas de dataSync não corresponde a essa finalidade. Isso não garante sobrevivência a force-stop, reboot ou encerramento do processo. Isolate FGS permanece heartbeat-only; probes nativos vivem no controller principal. Critérios e evidências: .specs/features/background-session-reliability/.
