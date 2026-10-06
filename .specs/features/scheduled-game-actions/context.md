# Scheduled Game Actions — Context

Gathered: 2026-10-05. Status: Approved.

## User decisions

- Extend the working scheduler with usarItem and pagarEquipe, translating supplied Puppeteer functions into requests with shared helpers.
- Protect the visible session from automated character changes; native HTTP in scheduler is acceptable.
- Use embedded browser for mapping. Test credentials are private session input, never files/logs.
- Submit a local notification before each scheduled game execution.
- Initial mapping: Troy Drinkwater / black panties. No gameplay POST submitted.
- Background and reboot scheduling continue; skip missed slots without replay.
- Independent second login coexistence is user-reported. Shared WebView cookies cannot reproduce independent jars.
- User explicitly confirmed proposed isolation/configuration and added: retain which character belongs to each scheduled action. Rule stores account + positive character ID + name; ID determines execution.

## Approved defaults

Private native sender/login and empty jar per transaction. Saved Auto Login credentials read freshly; visible session never seeded/updated. Exact normalized item name, first eligible row, one use per occurrence (proposed item policy accepted with feature confirmation). Crew default is maximum level20. Verified artist and character permit saving during weekly unavailability. Retain the selected quote cap when available; otherwise store no cap and disclose the fresh game price at execution. This user clarification on 2026-10-06 supersedes the initial explicit-choice-only default. Mandatory start notice; unavailable/uncertain distinct; no retry after possibly applied POST. Details and limits in design.md/spec.md.

## Execution

Scope/design approval received; tools already requested: tlc-spec-driven, embedded browser and Android/code debugging. Routine implementation choices delegated to specialists as required by CLAUDE.md. Eight atomic tasks; independent verifier automatic after implementation. Remaining supplied functions and multi-account profiles stay future scope.
