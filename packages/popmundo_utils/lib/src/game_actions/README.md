# Independent scheduled game HTTP

GameActionsService serializes character/item/crew discovery and execution using a fresh native transport and empty AuthSession cookie jar per transaction. Its collaborators are readCredentials, createTransport and injectable limits/clock/sleep; it has no WebView, CookieSource/Sink or visible HostTracker. GameCredentials stay in memory. A rule binds username and numeric character ID; owned selection and the fresh scoped profile marker are both verified.

Public discovery: discoverCharacters returns GameCharacterCatalog; discoverItems and discoverCrew require boundUsername/character and return validated public DTOs. Changing saved account, missing credentials, unsafe routes and malformed forms return bounded GameActionException codes. cancel closes the active transport; dispose prevents queued transactions and drains ownership. Auth/session/form state is never a DTO.

GameActionLimits default to120s total,20s per request,2097152 decoded UTF8 bytes and750ms cooldown after every completed/failed request, including between transactions. Cancellation closes IO before returning and guards each later request; a response arriving late cannot start another request. Tests can provide a transport which rewrites logical Popmundo destinations to loopback, without relaxing production HTTPS/host policy.

Files: game_action_contracts.dart (ports/limits/outcome), game_actions_service.dart (gateway/auth/discovery/ownership), game_transaction.dart (deadline/abort/cooldown/private session and notification protocol), game_forms.dart (scoped identities, strict fresh forms, direct inventory rows and exact crew quotes), game_notification_signals.dart (strict envelope decoding).

Successful form controls use opt-in strictDisabledControls, including disabled fieldsets/optgroups/options, first-legend exception and foreign form ownership. Existing visible login retains default serialization. Gameplay helpers clear event fields and read live button/hidden state; no stale form is persisted. Item eligibility requires Item_Use.png; crew prices use strict PT grammar and overflow-safe integer cents. Artist display label comes from the verified page title (optional notification counter), never the sidebar's Informações gerais link.

Notification preflight accepts an empty list or only normal Status0/Textstring signals. It seeks neutrality in at most two reads; malformed/non-neutral baseline aborts. After a possible effect, only an all-success response confirms, all-error fails; empty/normal/unknown/mixed is uncertain. Endpoint name does not imply draining.

At the T2 foundation stage execute remains an unavailable hook; item and crew adapters follow in T3/T4. Production credentials and authenticated HTML never enter default tests. Tests use synthetic transports/loopback; the opt-in test_live/game_actions_discovery_live_test.dart only selects/discovers, never calls execute or writes captures.

Login GET explicitly permits the actual login controls on /Default.aspx; every post-authentication route still rejects a login form. This distinction is regression-tested with synthetic real control names. Optional live diagnostics require POPMUNDO_TRACE_ROUTES=true and publish only method/host/path/status plus sanitized form action routing, never query strings or payloads.
