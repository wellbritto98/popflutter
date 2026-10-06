# .specs — Spec Driven Development

Estado persistido da skill `tlc-spec-driven`. Fonte de requisitos e decisões para implementação futura. Visão de sistema: `docs/ARQUITETURA.md` e `docs/OBJETIVO.md`.

## Objetivo do módulo

Guardar o *quê* e o *porquê* das features: requisitos com IDs, decisões de gray area, design, tasks, relatório do Verifier, log de ADs e lições.

## Responsabilidade principal

Pipeline Specify → Design → Tasks → Execute. Não é código de runtime. Agentes devem invocar a skill em vez de planejar ad hoc (`CLAUDE.md`).

## Funcionalidades existentes (artefatos)

| Caminho | Função |
| ------- | ------ |
| `STATE.md` | Decisions AD-001…AD-023 + Handoff |
| `LESSONS.md` / `lessons.json` | Lições; **não** editar `LESSONS.md` à mão — `scripts/lessons.py` da skill |
| `features/popmundo-wrapper/` | Fundação WebView / utils |
| `features/app-sidebar-menu/` | Drawer + registro |
| `features/userscript-manager/` | Catálogo + injector |
| `features/auto-login/` | Relog silencioso (código = AD-018; handshake nativo AuthSession) |
| features/service-scheduler/ | Regras locais persistentes Android; intervalos, dias da semana, skip de perdidas e AD-021 |
| features/scheduled-game-actions/ | UsarItem/pagarEquipe aprovado; execução HTTP isolada, personagem por regra, implementação em andamento (AD-023) |
| features/background-session-reliability/ | Sessão contínua specialUse, UA limitado e notificações de Auto Login; AD-020 |
| `features/background-keepalive/` | FGS |
| `features/app-i18n/` | EN/PT |
| `features/mobile-e2e-tests/` | Patrol |
| `features/gm-host-apis/` | Polyfill Host — só `spec.md` + `context.md` (sem `validation.md`) |
| `features/webview-back-navigation/` | System-back |

Uma feature grande costuma ter `spec.md`, `context.md`, `design.md`, `tasks.md`, `validation.md`.

## Dependências

Nenhuma dependência de runtime. Consomido por agentes e humanos. Código em `packages/` e `apps/` deve rastrear os ACs.

## Módulos relacionados

Packages e app documentados em `docs/` e nos READMEs locais. Skill: `.claude/skills/tlc-spec-driven/`.

## Pontos de entrada

- Resume: seção Handoff de `STATE.md`.
- Decisão nova: `STATE.md` Decisions (skill memory), não editar ADs superseded além de marcar status.
- Feature nova: pasta `features/<id>/`.

## Fluxos importantes

Execute termina com Verifier (author ≠ verifier). Lições só via `python3 .claude/skills/tlc-spec-driven/scripts/lessons.py`.
Quando scripts não forem autorizados no ambiente, use o fallback da skill: registre candidatos a lição no validation.md, preservando LESSONS.md e lessons.json como arquivos geridos pela ferramenta.

## Arquivos críticos

- `STATE.md` — ADs ativos (AD-018 Auto Login; AD-011/017 superseded).
- `features/*/spec.md` — WHEN/THEN; se o código mudar o comportamento, atualize o spec ou registre SPEC_DEVIATION.

## Observações técnicas e débitos

- `gm-host-apis` sem design/tasks/validation no disco; implementação existe no código.
- `LastUrlStore` foi removido do código; specs antigas ainda citam — banners no próprio spec apontam para `spec.md`/`validation.md`.
