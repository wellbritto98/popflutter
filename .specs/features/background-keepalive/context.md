# Background Keepalive Context

**Gathered:** 2026-08-18
**Spec:** `.specs/features/background-keepalive/spec.md`
**Status:** Ready for design

---

## Feature Boundary

O app solicita permissões na primeira abertura, mantém keepalive de sessão no Android via Foreground Service + isenção de bateria, pede notificação no iOS (sem JS contínuo em background), e expõe status + heartbeat no debug panel. Push e automação de gameplay ficam fora.

---

## Implementation Decisions

### Objetivo de segundo plano

- Manter WebView/sessão viva em segundo plano no Android (processo + FGS).
- Push é ideia futura — não implementar envio agora.
- iOS: sessão via cookies (AD-004); JS para ao suspender.

### Pedidos de permissão / UX Android

- FGS com notificação persistente **e** isenção de bateria (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
- Prompt na primeira abertura (pós-primeiro-frame).
- Se negar: continua em foreground; debug mostra denied; sem re-prompt forçado a cada launch.

### Pedidos iOS

- Pedir permissão de **notificação** na primeira abertura (preparação para push).
- Sem diálogo genérico de “rodar em segundo plano” (não existe).
- Debug deve ser honesto (lifecycle suspended / heartbeat congelado).

### Debug panel

- Status das permissões **e** prova de vida (heartbeat).
- Linhas densas sob o host, estilo `host: …`, strings em inglês, keys `debug-bg-*`.

### Agent's Discretion

- Plugin único: `flutter_foreground_task`.
- Facade injetável no app shell para testes sem diálogo real.
- Intervalo de heartbeat ~5s.
- Título da notificação: “Popmundo is running”.
- `autoRunOnBoot` / exact alarms desligados.

### Declined / Undiscussed Gray Areas → Assumptions

- Sem botão no debug para reabrir Ajustes / re-pedir (usuário escolheu launch + status + heartbeat, não re-prompt).
- Tipo FGS specialUse com subtype de manutenção contínua de sessão (AD-020; usuário confirmou uso durante a noite em 2026-10-04).

---

## Specific References

- Debug “tipo quando exibe o host” → linhas densas no `DebugOverlay`.
- Diálogo inicial ao abrir o app → bootstrap pós-frame.

---

## Deferred Ideas

- Envio de notificações push / remote messaging.
- Autostart pós-boot / fabricante.
