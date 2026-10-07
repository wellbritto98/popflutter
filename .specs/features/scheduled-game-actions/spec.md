# Scheduled Game Actions — Specification

Status: Approved; implementation verified 2026-10-07 (validation.md, commit 857466b). User confirmed isolated HTTP and character binding on 2026-10-05.
Date: 2026-10-05 (America/Sao_Paulo).
Scope: Complex; Android scheduler, isolated authentication, game forms and native UI.
Baseline: 5ce2153; AD-021 scheduler and AD-022 AppWiring.
Research: research.md; user decisions/defaults: context.md.

## Problem and goals

Agendamentos already runs local notifications. The user now needs scheduled usarItem and pagarEquipe, with a notification before each execution and without changing the character, URL or unfinished work in the visible game screen. Existing Puppeteer functions supply behavior references; production must use native HTTP requests and current ASP.NET forms.

The first release adds precisely these two game actions, preserves local reminders and existing recurrence/lifecycle semantics, and provides reusable isolated-login/form helpers for later actions.

## Scope

Included: service selection in the existing scheduler; discovery of owned characters and action options through an independent HTTP session; use one eligible item per occurrence; one chosen crew cash bonus per occurrence; native start/result notifications; persistent rules; serial, cancellable HTTP execution; Android secondary-engine evidence.

Excluded: all other gameplay functions in the supplied script; arbitrary URLs/JS; multiple accounts/profiles; bulk item use; instrument tuning; a hidden WebView or a new Android process; changes to the visible Auto Login behavior; iOS continuous scheduling; recovery/replay of missed or uncertain effects.

The user request explicitly expands the historical gameplay exclusion for these two actions. Broader gameplay exclusions remain in place. AD-023 explicitly amends AD-021's auth/game-HTTP exclusion; it must preserve its single writer, claims, notification IDs and recurrence semantics.

## P1 stories and acceptance criteria

### Configure services without disturbing the game

SGA-01 — Compatibility and typed actions

1. WHEN the scheduler reads an existing schemaVersion 1 localNotification snapshot, THEN all rules SHALL preserve their identities, negative notification IDs, nextSequence, recurrence and stored text, remain editable, and execute as before.
2. WHEN a rule contains an action, THEN the action SHALL be a validated localNotification, useItem or payCrew payload; unknown/malformed types SHALL reject the operation without resetting or overwriting the catalog.
3. WHEN a new game rule is persisted or crosses engine RPC, THEN it SHALL carry only non-secret configuration: the bound username, owned character ID and display name, and the service-specific fields. Passwords, cookie values, session selectors, viewstate, handover tokens and authenticated HTML SHALL NOT be stored in the rule, RPC or logs.

SGA-02 — Editor and discovery

1. WHEN opening create/edit on Android, THEN the existing editor SHALL offer Notificação local, Usar item and Pagar equipe in EN/PT, preserving the existing name/recurrence/enabled fields and save/cancel/error behavior.
2. WHEN loading game choices, THEN discovery SHALL use the saved Auto Login credentials in an isolated session, list owned characters by ID/name, and obtain usable item names or current crew bonus options for the selected character. It SHALL NOT read/evaluate/navigate the visible WebView.
3. WHEN selecting Usar item, THEN the rule SHALL require one owned character and a nonempty normalized exact item name of at most 120 UTF-16 units; only rows with an eligible use button SHALL be offered. One use per occurrence is the MVP quantity.
4. WHEN selecting Pagar equipe, THEN discovery SHALL display the current artist name and available quoted bonus levels. The default SHALL be maximum level 20, as requested by the user on 2026-10-06. A verified owned character and current artist ID/name SHALL permit saving even when the weekly restriction hides the bonus form. An available selected quote SHALL be saved as the cost cap; with no quote the cap SHALL be absent and the summary SHALL state that the game determines the price at execution. No invented quote or substitute level.
5. WHEN no credentials/options are available, discovery fails or inputs are invalid, THEN the form SHALL retain its input, show a specific translated error and SHALL NOT report a saved game rule. Previously saved rules SHALL remain readable/editable without automatic live discovery; changing a game target requires fresh valid choices.
6. WHEN discovery is pending, THEN a visible progress indicator and translated loading text SHALL explain the fetch; completion or failure SHALL clear loading and retain all entered data.
7. WHEN saving a game rule, THEN the editor SHALL show its effect summary and the fact that it will consume an item or distribute a cash bonus on each eligible occurrence. Save/enable is the user's authorization for that configured recurring effect.
8. WHEN listing a game rule, THEN its card SHALL show service, target character, selected item or artist/bonus, next due time and latest truthful result. Editing action configuration alone SHALL preserve the rule identity and cadence like existing text-only edits.

### Isolated reusable HTTP execution

SGA-03 — Independent authentication and identity

1. WHEN discovery or an occurrence authenticates, THEN it SHALL create a dedicated native HTTP sender and initially empty cookie jar, authenticate with the saved account, and resolve subsequent requests against the host actually assigned by the login redirects.
2. WHEN selecting the target character, THEN selection SHALL match the configured owned ID uniquely and verify the resulting character identity before gameplay. Missing/ambiguous/mismatched identity SHALL prevent the gameplay POST.
3. WHEN execution changes its own active character, THEN it SHALL NOT call CookieSource/CookieSink, seed from the visible cookie jar, mutate visible HostTracker, or call visible loadUrl/evaluate. The visible session, character, URL and unfinished inputs SHALL remain unchanged by the automation.
4. WHEN the saved username differs from the rule's bound username, the password is missing or secret storage is unavailable, THEN execution SHALL fail before gameplay with a sanitized credential code. Settings SHALL be freshly read in the secondary engine; the Auto Login enabled toggle SHALL remain independent of game scheduling.
5. WHEN the sender follows any request/hop, THEN production requests SHALL be HTTPS to popmundo.com or a true subdomain, without userinfo or unexpected ports; external/insecure targets SHALL be rejected before transmission. Tests may inject an explicit loopback transport only in the non-production fixture boundary.

SGA-04 — Common form and outcome helpers

1. WHEN preparing a game POST, THEN the helper SHALL read a fresh #aspnetForm and serialize the entire set of successful controls, preserving repeated names and current hidden state, excluding disabled/unchecked controls and unrelated submit/image buttons.
2. WHEN applying action overrides, THEN it SHALL clear __EVENTTARGET/__EVENTARGUMENT, use the chosen control's name attribute, preserve the row's runtime hidItemIDstring, and submit only the intended gameplay button. Empty/missing forms or controls SHALL prevent gameplay.
3. WHEN a login, route or form validation fails, THEN the executor SHALL expose only a bounded non-secret code; it SHALL NOT persist or publish the raw HTTP exception, query string, cookie, payload or authenticated document.
4. WHEN checking gameplay outcome, THEN it SHALL use a fresh server success/error signal from the same isolated session. A notification check SHALL establish a neutral baseline before the gameplay POST in at most two reads, then read the current outcome using the known GetPageNotifications protocol. HTTP 200 or redirect completion alone SHALL NOT imply success.

### Use one item

SGA-05 — usarItem

1. WHEN an eligible occurrence executes, THEN it SHALL GET /World/Popmundo.aspx/Character/Items/ on its authenticated host and match only item links inside #checkedlist rows by exact case/whitespace-normalized name, never substring matching.
2. WHEN multiple eligible rows have that exact name, THEN it SHALL use the first eligible row in document order. User confirmation accepted this proposed default; each occurrence uses only one item.
3. WHEN the row contains input[type=image], THEN only an enabled button whose src pathname ends in /Item_Use.png SHALL be usable. Item_Tune.png, wearable buttons, unrelated images and missing buttons SHALL NOT be executed, even if named btnUse.
4. WHEN submitting use, THEN the entire fresh form plus <use-button-name>.x=1 and <use-button-name>.y=1 SHALL be posted once. All hidItemIDstring values remain those returned in the current document; none are persisted for later reuse.
5. WHEN the named item is absent or no eligible use row exists, THEN the occurrence SHALL be marked unavailable with zero gameplay POSTs; future recurrence remains enabled unless the user pauses it.

### Distribute the chosen crew bonus

SGA-06 — pagarEquipe

1. WHEN an occurrence executes, THEN it SHALL GET /World/Popmundo.aspx/Artist/Crew/ and verify the configured artist ID against the page's current artist marker before any payment. A changed/missing artist SHALL prevent gameplay.
2. WHEN preparing the bonus, THEN the selected integer level SHALL be within 14..20 AND appear as an enabled option in the actual current ddlCashBonus. The current cost SHALL parse unambiguously into integer minor currency units; when a saved cap exists, the price SHALL be no greater than it. An absent cap authorizes the configured level at its fresh game price. A missing/invalid/over-budget option SHALL produce unavailable without selecting a substitute.
3. WHEN submitting payment, THEN the fresh full form SHALL override ctl00$cphLeftColumn$ctl01$ddlCashBonus with that selected level and ctl00$cphLeftColumn$ctl01$btnCashBonus with the actual enabled submit button value. The JavaScript confirmation dialog adds no POST field.
4. WHEN the crew form is unavailable, including maximum mood or the game's weekly restriction, THEN execution SHALL perform zero payment POSTs and record unavailable. It SHALL NOT infer a specific reason from select absence alone, or report a bonus delivered.
5. WHEN configuring recurrence, THEN the editor SHALL explain the game's one-bonus-per-seven-days limit. More frequent scheduler occurrences remain allowed, but unavailable occurrences SHALL spend nothing and await the next scheduled slot.

### Notification, outcome and duplicate prevention

SGA-07 — Start and result notifications

1. WHEN a game occurrence is claimed, THEN the durable claim SHALL succeed before any start notification or HTTP request. The strict native notification path SHALL then submit an EN/PT message naming the service and character before the first HTTP request.
2. WHEN start notification permission/initialization/submission fails, THEN the occurrence SHALL fail without issuing the game's action, preserving the claim and next-future cadence. Notification submission means Android accepted it, not proof the person saw it.
3. WHEN the occurrence finishes, THEN the same stable negative rule ID SHALL replace the start card with confirmed, unavailable, failed or uncertain outcome. A failure to publish this final card SHALL NOT overwrite an already confirmed game result or trigger the action again.
4. WHEN localNotification executes, THEN its configured title/body and existing submitted result semantics SHALL remain unchanged, without an extra game-start card.

SGA-08 — Truthful persisted results

1. WHEN a fresh server signal confirms gameplay, THEN the rule SHALL record confirmed at UTC completion; a known rejection SHALL record failed with a sanitized code; absence of an eligible target/form SHALL record unavailable.
2. WHEN a gameplay POST may have reached the server but its response/outcome cannot be confirmed, THEN the rule SHALL record uncertain and SHALL NOT automatically resend that gameplay POST.
3. WHEN death/reboot interrupts a claimed occurrence, THEN the existing skippedInterrupted recovery SHALL prevent replay. If result persistence fails after any effect, the writer SHALL retain the existing resultUncertain/claim safety; it SHALL NOT retry the effect.

SGA-09 — Serial execution, deadlines and lifecycle

1. WHEN multiple rules/discovery calls compete, THEN one HTTP transaction at a time SHALL include login, selection, target GET, gameplay POST and outcome verification. Requests within the transaction SHALL honor at least 750 ms after the prior request finishes, including failed requests. No unbounded backlog of overdue occurrences SHALL be created.
2. WHEN a game transaction runs, THEN its overall deadline SHALL be 120 seconds, with at most 20 seconds per request and a 2 MiB decoded response ceiling. The local-notification deadline remains five seconds. Limits are injectable in tests.
3. WHEN deadline/disposal/service destruction cancels HTTP, THEN the sender SHALL actually abort/close, and a cancellation check SHALL prevent every subsequent request, especially gameplay POST. The transaction lock SHALL remain held until prior work can no longer send; merely Future.timeout followed by queue release is forbidden.
4. WHEN a gameplay POST is in progress at cancellation, THEN its result SHALL be uncertain; cancellation before gameplay SHALL be a failed/timeout result. A late response SHALL NOT launch a POST or change a newer execution's session.
5. WHEN a long transaction delays another occurrence beyond the existing eligibility window, THEN the scheduler SHALL skip that overdue slot and arm the next future occurrence, preserving the existing no-replay semantics.

SGA-10 — Android evidence and maintenance

1. WHEN Android runs the FGS with the UI backgrounded/removed and after reboot, THEN the secondary engine SHALL be able to read the secure test secret, authenticate with a loopback fixture, execute the mapped POST and submit native start/result notifications; no visible game WebView or Activity SHALL be required.
2. WHEN gates run, THEN default tests SHALL use fakes and device tests SHALL use loopback, never real Popmundo. User-authorized browser inspection/live checks SHALL remain opt-in and separate, with no production credentials or authenticated HTML committed.
3. WHEN validation completes, THEN a fresh independent verifier SHALL map every AC to evidence and kill behavior-level faults for wrong item button, wrong bonus, shared cookies, missing start notice and unsafe timeout/duplicate behavior. Documentation SHALL describe the final supported behavior and concrete limits.

## Approved assumptions

| Decision | Approved default | Rationale | Confirmation |
| --- | --- | --- | --- |
| Transport | Native HTTP in existing FGS, independent login/jar | User explicitly permits HTTP; avoids shared WebView cookies and renderer dependency | Approved by user confirmation |
| Item identity | Exact normalized name; first usable matching row; one use | Supports replenished consumables; avoids original substring/tune bug | Approved by feature confirmation |
| Credentials | Reuse account/password already saved in Auto Login, bind username per rule | Keeps scope to two actions; prevents silently executing old rules under another account | Approved by user confirmation |
| Crew destination | Artist selected at configuration remains fixed by ID | Character may change bands before occurrence | Approved by user confirmation |
| Bonus policy | Default maximum level20; save even without a currently available form; preserve a quote cap when available, otherwise use fresh game price | User requires future scheduling after weekly payment and maximum default | User clarification 2026-10-06 supersedes initial explicit-choice-only default |
| Unavailable occurrence | No gameplay POST; record unavailable and wait for next slot | Missing form cannot mean success; user controls pause | Approved by user confirmation |
| Start-notice failure | Abort gameplay | User requires notice before each execution | Approved by user confirmation |
| Deadlines | 120 s total, 20 s/request, 2 MiB response | Existing 5 s unsuitable; bounded real cancellation | Approved by user confirmation |
| Live testing effects | Inspect/login/character selection authorized; no item consumption/bonus delivered yet | Test effect needs a specific item and bonus/amount chosen before submission | No destructive live test executed |

The user confirmed the proposal and character binding. Remaining details follow these ACs and the approved design.

## Implicit requirement dimension sweep

| Dimension | Coverage |
| --- | --- |
| Input validation/bounds | SGA-01/02/05/06/09; current scheduler text/recurrence bounds unchanged |
| Failure/partial failure | SGA-07/08/09; notice failure, result persistence, unknown effect |
| Idempotency/retry | SGA-05/06 single gameplay POST; SGA-08 claim/no replay |
| Auth/rate limits | SGA-03/04/09; secure credentials, private host/jar, 750 ms |
| Concurrency/ordering | SGA-09; one full HTTP transaction; cancel before release |
| Data lifecycle | SGA-01/03; ephemeral jar/HTML; existing rule deletion semantics |
| Observability | SGA-02/07/08; UI result and non-secret codes |
| External failure | SGA-04/05/06/08/09; unexpected markup/network/price changes |
| State transitions | SGA-01/07/08; claim before effect, results, interrupted recovery |

## Requirement traceability

| ID | Deliverable | Status |
| --- | --- | --- |
| SGA-01 | Backward-compatible action models | Verified |
| SGA-02 | Editor, discovery and summaries | Verified |
| SGA-03 | Independent login and credentials | Verified |
| SGA-04 | Shared ASP.NET helpers and outcome checks | Verified |
| SGA-05 | usarItem | Verified |
| SGA-06 | pagarEquipe | Verified |
| SGA-07 | Start/result native notifications | Verified |
| SGA-08 | Truthful durable outcome | Verified |
| SGA-09 | Serial cancellation/deadlines | Verified |
| SGA-10 | Device proof, verifier and docs | Verified |

Coverage: 10 requirements; task mapping follows approved design. No implementation claim.

## Success criteria

- [ ] Existing local reminders retain data and behavior.
- [ ] User can configure either game action with owned targets and explicit parameters.
- [ ] Action runs through isolated native HTTP without touching visible session state.
- [ ] Start notice precedes requests; results never infer gameplay success from HTTP 200 alone.
- [ ] Timeout/restart cannot duplicate uncertain item use or payment.
- [ ] Secondary-engine Android loopback proof and independent verification pass.

## Approved precision notes

- Character ID is authoritative; saved display name labels the action. Owned selection must be unique in its character box, then verified against a fresh scoped profile marker before gameplay.
- Minor currency units are cents of M$: observed 2.250,00 M$ = 225000. Reject ambiguous unsupported numeric grammar.
- Notification preflight must establish a neutral baseline in at most two reads, without assuming the endpoint drains previous notifications. Failed/non-neutral preflight prevents gameplay. Empty/malformed/unknown or mixed success/error outcome after a possibly sent POST is uncertain and never retried.
