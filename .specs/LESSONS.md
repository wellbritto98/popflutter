# LESSONS — auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation — do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 — Assert the concrete persistence mechanism in unit tests and keep OS-level session survival as a device UAT criterion
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `webview-session` · harmful: 0
- features: popmundo-wrapper
- evidence: SESS-01 validation.md cookie relaunch (webview-session)
- last seen: 2026-08-18T00:05:39Z

### L-002 — Assert empty HTTP response bodies are rejected with zero catalog writes, not only network/parse failures
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/userscript` · harmful: 0
- features: userscript-manager
- evidence: edge: empty response body (packages/popmundo_utils/userscript)
- last seen: 2026-08-18T02:39:06Z

### L-003 — When UI disables actions during an in-flight operation, assert the disabled state in a widget test with a deferred/async stub
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: userscript-manager
- evidence: edge: import-in-progress disables add (apps/popmundo_app)
- last seen: 2026-08-18T02:39:06Z

### L-004 — Every rejected header in an honor/reject matrix needs a dedicated unit assertion, not only sibling headers
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils/userscript` · harmful: 0
- features: userscript-manager
- evidence: USM-04 @inject-into (packages/popmundo_utils/userscript)
- last seen: 2026-08-18T02:39:06Z

### L-005 — Composition wiring that sets WebView initialUrl from a store must have a widget or fake-runtime test asserting the exact URL, not only the production bootstrap code
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: auto-login
- evidence: NAV-04 / validation.md Gap (apps/popmundo_app)
- last seen: 2026-08-18T14:16:03Z

### L-006 — When a settings screen AC lists exact enum option values, assert the option set in the widget test rather than only exercising one save path
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: auto-login
- evidence: UI-02 status dropdown / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T14:16:03Z

### L-007 — Controller abort branches listed in the feature edge-case table need dedicated tests, not only happy-path and one miss path
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `packages/popmundo_utils` · harmful: 0
- features: auto-login
- evidence: edge cases / validation.md Edge Cases (packages/popmundo_utils)
- last seen: 2026-08-18T14:16:03Z

### L-008 — When a spec names an exact user-visible string (notification title, label), assert that string in a test — production-only presence is not evidence-or-zero
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: FGS-01 / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

### L-009 — Independence claims (bootstrap must not block WebView) need an explicit test or a documented UAT/checklist item — wiring comments alone do not close the AC
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: BG-01 / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

### L-010 — For isolate or cross-isolate callbacks, assert that garbage or missing payloads leave prior state intact and do not throw
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `apps/popmundo_app` · harmful: 0
- features: background-keepalive
- evidence: edge: TaskHandler isolate unreachable / validation.md (apps/popmundo_app)
- last seen: 2026-08-18T18:49:50Z

## Quarantined (failed when applied — ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
