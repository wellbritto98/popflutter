# Scheduled Game Actions — Design

Status: Approved approach; implementation detail under agent discretion.
Spec: spec.md. Approval: user confirmed isolated HTTP proposal and explicitly required retaining each action's character (2026-10-05).

## Architecture overview

One GameActionsService in the foreground engine serializes discovery and execution. Each transaction creates its own sender and empty AuthSession jar, reads current secure credentials, authenticates, selects the saved character ID, verifies it against a fresh character profile, executes at most one gameplay POST and closes its transport. The visible runtime/cookies/HostTracker are not collaborators.

Existing SchedulerClient RPC carries only validated non-secret DTOs. SchedulerRunner persists the occurrence claim, submits its start notification, invokes the game executor, persists a truthful outcome and replaces that notification with the result. Local notification execution and schemaVersion1 snapshots retain their behavior.

Approaches considered in research: shared headless WebView (cookie and lifecycle conflict); isolated Android process/WebView (new process/plugin complexity); independent native HTTP jar (recommended and approved). Independent login coexistence is user-reported; dedicated live read-only proof remains a validation target.

## Code reuse analysis

- AuthSession: form login, manual redirect hops, assigned host, jar and 750ms cooldown. Add postJson and optional decoded-body limit to IO sender, preserving existing defaults.
- Existing scheduler models/store/calendar/claims/RPC: same writer, rule IDs, recurrence and stable negative notification IDs.
- SecretStore and saved Auto Login username/password: freshly read in secondary engine; no copying credentials to RPC.
- AppWiring: owns UI SchedulerApi lifecycle; composition remains outside widgets.
- Existing html parser dependency: native form and scoped identity parsing; no page evaluate or injected fetch.

## Components and interfaces

### Typed action configuration

A sealed ScheduledAction hierarchy in scheduler models (part file permitted): LocalNotificationAction; GameScheduledAction with boundUsername and GameCharacter(id,name); UseItemAction with itemName; PayCrewAction with artistId/name, bonusLevel and maxCostMinor. IDs are positive integers; bonus14..20; optional maxCostMinor is positive integer cents of M$ when a quote exists. Whitelisted codecs reject malformed/unknown actions without overwriting the catalog. No legacy title/body getters on game actions.

DTOs GameCharacterCatalog, GameItemChoice and GameCrewOptions expose account/character/item/artist/bonus choices only. Character ID governs execution; stored name is the notification/editor label. Renaming does not select a different character.

### Isolated HTTP service

GameActionsService exposes discoverCharacters, discoverItems, discoverCrew and execute(GameScheduledAction), plus dispose/cancel. A transport factory and fresh credential reader are injected. Discovery and execution share the same serial boundary. GameActionOutcome explicitly reports confirmed/unavailable/failed/uncertain and bounded error codes.

Each transaction checks the bound account, an empty private jar, strict HTTPS Popmundo URL validation, unique owned-character selection, then fresh /World/Popmundo.aspx/Character identity scoped to the actual profile marker. Form POST routes must match the intended route. Full successful-control serialization preserves duplicate names and hidden row state; clears event overrides; excludes unrelated submit/image controls.

Total deadline120s; per-request20s; decoded-body2MiB; cooldown750ms after success or failure. Timeout/dispose closes IO sender and invalidates the generation before another request can start. Queue ownership is held until the transaction cannot send more requests. A possibly transmitted gameplay POST is never retried.

### Endpoint adapters

Use item: exact case/whitespace-normalized name; first eligible direct inventory row in DOM order; enabled image button pathname /Item_Use.png only; row-local hidItemIDstring preserved; button.x=1/button.y=1. No tuning/wearing/drop or persisted item form state.

Crew bonus: verify current scoped artist ID; selected enabled level14..20 offered at execution; parse quoted currency with exact observed PT grouping/decimal grammar into cents (2.250,00 M$ =225000); reject ambiguous unsupported formats. When maxCostMinor is present the current quote must not exceed it; a null cap authorizes the saved level at its freshly parsed game price. Existing non-null caps retain their guard. Full fresh form includes selected bonus and actual button value. Missing form/option => unavailable; no substitute or fabricated reason.

Before gameplay, obtain a neutral notification baseline with at most two bounded ASMX reads; do not assume reads clear state merely from endpoint naming. Failure/non-neutral baseline prevents gameplay. After gameplay, strictly decode GetPageNotifications response; only unequivocal fresh success confirms, explicit error fails, mixed/empty/malformed/unknown signals are uncertain. HTTP200 alone never confirms.

### Scheduler integration

Preserve ScheduledActionExecutor local port; add a game execution boundary returning GameActionOutcome. Only local execution retains existing5s guard. Game timeout/cancellation belongs to the cancellable service, not a Future.timeout that leaves requests alive. Disposal closes the game service. Persist claim before start notice, and start notice before HTTP. Notice failure prevents game traffic. Result notice failure does not reverse a confirmed effect or retry it.

### App integration and editor

Separate GameActionsApi discovery interface implemented by SchedulerClient preserves existing CRUD fakes. Secondary engine reconstructs service/credentials/notifications on startup; locale comes from fresh preferences and bundled EN/PT assets, not main UI localization state. Initialization failures are sanitized and prevent gameplay.

Editor keeps current recurrence fields, adds service selection and independently loaded character/options. Each rule explicitly retains character ID and name. Saved rules can be edited offline without implicit HTTP; changing target requires fresh verified character and artist discovery. Crew defaults to level20 and may be saved without currently available bonus options; its optional cost cap is the current quote when available. Discovery shows progress and clears loading on completion or failure. Crew choice displays cost/cap and weekly limitation; item choice explains one use per occurrence. Rule cards show target/effect/latest outcome.

## Risks & Concerns

- Shared cookie singleton and suspended renderer: mitigate with native independent jar; no WebView dependencies in service.
- Global idHolder selector can read an unrelated entity: scope identity to verified profile/choose-box/artist markers and reject ambiguity.
- Same-name btnUse can tune: inspect image pathname, direct row pairing, reject tune even when control name matches.
- Old notifications can fabricate success: bounded neutral preflight, strict outcome decoding, ambiguity => uncertain.
- Dart timeout alone permits late destructive requests: close transport plus generation guards and serial ownership.
- Secondary engine Keystore/localization differs from UI: actual Android loopback/Keystore/notification proof required.
- Whole-form repeated names and stale hidden fields: fresh form serialization with repeated controls and row-preservation tests.
- Android seconds/background delivery is best effort; existing missed-slot/claim semantics retained. Force-stop remains Android limitation.

## Validation boundary

Default tests never contact Popmundo. Device fixture uses explicit loopback transport reconstruction and isolated application ID. Live browser mapping is read-only; no item use or bonus has been submitted. Final verifier independently checks every AC and kills at least five behavior mutants in scratch state. No script edits of machine-owned lessons; retain grounded candidates in validation report if tooling conflicts with user restriction.
