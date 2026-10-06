# Scheduled Game Actions — Research

Date: 2026-10-05, America/Sao_Paulo. Source baseline: 5ce2153.
Status: research record; approved implementation is tracked in tasks.md and STATE.md.

## Evidence and boundaries

Sources: user-supplied Texto colado.txt (1,574 lines, read completely by domain specialist), user-provided mapping, current code/ADs, actual DOM inspected with the embedded browser, installed Android plugin source, official documentation.

Embedded browser: normal login redirected to assigned host 74.popmundo.com; ChooseCharacter and Troy selection completed; inventory and crew pages inspected. All hidden session/form values and character-selector GUIDs are ephemeral; this document retains only names, paths and non-secret gameplay identity. No gameplay use/payment POST was sent. DOM confirms form method/action and submitter controls; raw network packets were not captured by the browser API. Do not label inferred browser form payloads as packet captures.

Independent live login and its effect on a fresh visible session were tested on 2026-10-06. Native discovery selected Peter3155712 while a fresh browser reload remained authenticated as Troy3327035, both assigned host74. No gameplay POST. See evidence/f1-browser-isolation.md and f1-live-fresh-sessions.log.

## Observed routes and identities

- Login starts at https://www.popmundo.com and hands over to a numbered HTTPS host. Never hardcode 74 after authentication.
- ChooseCharacter: /World/Popmundo.aspx/ChooseCharacter; #aspnetForm action ./ChooseCharacter, method post. Each div.box has h2, .idHolder and its own submit input.
- Inventory: /World/Popmundo.aspx/Character/Items/; #aspnetForm action ./, method post; #checkedlist contains item rows and row-scoped controls.
- Crew: /World/Popmundo.aspx/Artist/Crew/; #aspnetForm action ./, method post.
- Mapped test character ID: 3327035 (Troy Drinkwater); artist ID: 2774797 (black panties).
- Crew identity evidence: .idHolder under .entityLogo gameimage idTrigger contains current artist ID; sidebar general artist link points to /World/Popmundo.aspx/Artist/2774797.
- Character bar select name is ctl00$ctl08$ucCharacterBar$ddlCurrentCharacter; change control is image input ctl00$ctl08$ucCharacterBar$btnChangeCharacter. Its runtime values are opaque selectors, NOT numeric character IDs; do not persist/reconstruct them.
- Forms currently include __EVENTTARGET, __EVENTARGUMENT, __VIEWSTATE, __VIEWSTATEGENERATOR and __EVENTVALIDATION. Serialize fresh entire successful controls instead of assuming this list is exhaustive.

## usarItem contract

The original function (attachment line 1369) searches any tr by substring and clicks its first image input. This is unsafe for homonyms and tuning.

Observed inventory: usable Cubo mágico, Vira-Tempo, Fotografia dos avós and several Analgésicos rows. A Violino row has btnUse but src Item_Tune.png/title Afinar. Use eligibility must inspect image src, not just control name.

Each row links to /World/Popmundo.aspx/Character/ItemDetails/<id>, carries a runtime hidden name ending in hidItemIDstring, and may have an image control ending in btnUse. The full repeating name includes group and row indexes, so it must be read from the current document each time.

For the Cubo mágico sample the button name is ctl00$cphLeftColumn$ctl00$repItemGroups$ctl02$repItems$ctl00$btnUse. The user-provided image-submit mapping is the full fresh form plus this name's .x=1/.y=1. It must preserve that row's fresh hidItemIDstring and the rest of the form; no persisted token or hardcoded repeating index.

Instrument tuning, wearing, dropping or discarding are outside this action. The inventory has several same-name Analgésicos rows, making the exact-name versus instance policy a real product decision.

## pagarEquipe contract

The original function (attachment line 1183) hardcodes level 20 and regards navigation as success.

Observed black panties crew mood: admirável. Current form offers:

| Level | Label | Current quote |
| --- | --- | --- |
| 14 | notável | 2.250,00 M$ |
| 15 | excelente | 8.000,00 M$ |
| 16 | formidável | 18.500,00 M$ |
| 17 | espetacular | 34.500,00 M$ |
| 18 | fenomenal | 56.750,00 M$ |
| 19 | incrível | 86.000,00 M$ |
| 20 | sobrenatural | 123.000,00 M$ |

These quotes describe this current crew page, not universal future prices. Configuration must read live options; execution must revalidate selected level and price.

The full form must set ctl00$cphLeftColumn$ctl01$ddlCashBonus=<level> and ctl00$cphLeftColumn$ctl01$btnCashBonus=Entregar bônus (use actual value from response). The initial selected option is 0, Selecionar bônus em dinheiro; it is not a valid scheduled bonus.

The page explicitly says a bonus may be distributed once per seven days. Inline script binds createConfBox to the button: the confirmation is client JavaScript and does not introduce an extra form field. No bonus was submitted.

User reports Deon's XEPA omits select at supernatural mood. That case was NOT independently rechecked in this browser run; implementation must handle missing select generically without claiming its exact cause.

## Reusable source and concrete gaps

| Source | Existing capability | Required change/boundary |
| --- | --- | --- |
| autologin/auth_http.dart | AuthSession owns jar, cooldown, manual redirects | Fresh private session; wrapper/port for serial execution, per-hop policy and cancellation; do not seed visible cookies |
| autologin/auth_http_io.dart | Native sender, no automatic redirects/cookies | Real global deadline/abort, bounded body and sanitized errors |
| autologin/auto_login_requests.dart | Full-form login/choose builders | Reuse without AutoLoginController |
| autologin/aspnet_form.dart | Exact normalized full-name choice and ambiguity detection | Extend discovery with owned numeric IDs; numeric IDs differ from top-bar GUIDs |
| autologin/aspnet_form_data.dart | Ordered full-form successful controls and set overrides | Reuse, with image coordinate/bonus submit overrides |
| facades/notifications.dart | Known GetPageNotifications JSON ts protocol and pure response parser | Pure parser reusable; TimedFetch-backed getter belongs to visible session and must not be used |
| scheduler/scheduler_models.dart | schema1 local rules, claims, results | Typed action variants and precise result states; no reset/migration loss |
| scheduler/scheduler_coordinator.dart | Single writer and pre-effect durable claim | Hardcoded localNotification dispatch and five-second Future.timeout unsuitable for HTTP; cancellation before queue release required |
| app/scheduler/scheduler_environment.dart | Existing secondary-engine composition | Inject private native HTTP and secure credential reader; current comment/AD excludes auth/game dependencies |
| app/scheduler/scheduler_runner.dart | Secondary-engine RPC lifecycle | Generic action parse, read-only discovery and disposal ownership |
| app/autologin/secure_secret_store.dart | Native secure storage | Prove secret access from actual secondary FGS engine |
| app/scheduler/scheduler_editor.dart | Native recurrence/editor | Service fields, discovery, summary, budget and translated statuses |
| app/notifications/local_notifications_service.dart | Strict scheduled notice init/check/show | Reuse before HTTP; stable negative ID start/result; no Activity |
| app/app_wiring.dart | AD-022 owns SchedulerApi and feature menu entry | Preserve composition boundary; no duplicate visible controller/runtime |

AuthSession currently offers cooldown, not a concurrent-request queue, and allows HTTP/external resolved locations. Its exceptions can include URL/Location tokens. Io sender currently allows a 20-second timeout per step and an unbounded decoded join. These are touched-area concerns, not reasons to refactor unrelated visible-login code. Mitigation belongs in the new isolated action boundary and its tests.

A five-second Future.timeout does not cancel the HTTP task. After timeout, a late task could continue switching character or submitting gameplay while the next action starts. Raising the timeout alone is insufficient. The old sender must be closed and subsequent sends blocked before releasing exclusivity.

## Hidden WebView alternatives

1. Recommended: independent native HTTP authentication/jar per transaction. Reuses transport/forms, no page renderer dependency; extra login cost and server coexistence still require testing.
2. Shared-process HeadlessInAppWebView: renders no UI, but is not a separate Android cookie jar. Cannot satisfy character/session isolation merely by constructing a second controller. No background continuity guarantee follows from the word headless.
3. Separate Android process and WebView data directory: genuine storage separation, but requires extra native lifecycle/IPC and separate initialization. Substantially more work for the same two actions; native HTTP already meets the requested fallback.

Installed plugin evidence: flutter_inappwebview_android-1.1.3/.../MyCookieManager.java:120 calls CookieManager.getInstance(); process_global_config/ProcessGlobalConfigSettings.java:51 calls setDataDirectorySuffix for a PROCESS setting. InAppWebView.java:310/589 removes cookies when incognito is enabled; incognito is not a safe per-view cookie isolation shortcut here.

Official sources:

- [Cookie Manager](https://inappwebview.dev/docs/cookie-manager/) documents singleton/shared instance and Android CookieManager.
- [Headless InAppWebView](https://inappwebview.dev/docs/webview/headless-in-app-webview/) documents hidden rendering/controller lifecycle; it does not promise separate sessions or continuous Android execution.
- [Android ProcessGlobalConfig](https://developer.android.com/reference/androidx/webkit/ProcessGlobalConfig) scopes data-directory suffix to the current process, with cookie jars split across processes.

Knowledge chain followed: current source, project docs/ADs, installed package, official web docs. No Context7 capability is available in this session. Confirmed project lessons: none. Per user shell policy, no Python/other file-manipulation script was run; machine-owned lessons files remain unchanged.

## Verification plan after approval

Default pure-Dart fake transport/form tests: exact full payload, malformed identities/routes, host-only cookies, no visible ports, item-use versus tune, bonus choice/budget, uncertain POST, notification order and real cancellation model. Widget tests: editor/catalog options, existing local-rule roundtrip, EN/PT text, failure recovery. Android Patrol: one patrolTest per file, loopback server + real Keystore/preferences/notification APIs in FGS secondary engine with no Activity; repeat future occurrence after restart/reboot without replay. Fresh independent verifier plus behavior fault sensor mandatory.

Live evidence is separate: browser DOM mapping already performed. A read-only independent-login/character-isolation check can follow using opt-in native transport. Any item-use or bonus-delivery live test must name the chosen item/bonus amount before submission; it is not a default test gate. No real account credential or runtime form token enters committed fixtures.

## Approved implementation precisions

Fresh browser GET /World/Popmundo.aspx/Character verified a unique .charPresBox .idHolder with the mapped character ID; its parent is .avatar.idTrigger. Verify the scoped profile marker, never the first global idHolder.

No source proves GetPageNotifications drains old entries. Existing notifications_test.dart Status0/Text'n' fixture establishes that nonempty normal text can be neutral. Preflight must establish only neutral Status0/list-empty baseline in at most two reads; unknown/malformed/non-neutral baseline prevents gameplay. Mixed outcomes after POST are uncertain. This corrects any interpretation that the helper promises automatic clearing.

Fresh browser renewal on 2026-10-06 assigned host75. Crew option14.textContent was exactly "notável 2.250,00 M$"; option20 exactly "sobrenatural 123.000,00 M$"; no parentheses/hyphen. Generic artist link text is "Informações gerais"; entityLogo has only its ID. Artist display label is available in document.title "(2) Popmundo - black panties" (optional notification count). Title supplies label only; scoped ID supplies identity. Browser session had redirected to Default.aspx?logout=true before renewal; cause unmeasured and no new native authentication had run yet.

Native follow-up on 2026-10-06: opt-in discovery plus read-only ASMX probe PASS29s (evidence/t4-live-discovery-signals.log). Both ASMX reads returned HTTP200 and a valid neutral empty list. Native crew DTO: Troy3327035, artist2774797, levels14..20, costsMinor[225000,800000,1850000,3450000,5675000,8600000,12300000], agreeing with DOM. Browser fresh reload still authenticated as Troy. This checks the actual envelope/available form, not the signal after real gameplay; post-effect semantics remain covered by synthetic fixtures.
