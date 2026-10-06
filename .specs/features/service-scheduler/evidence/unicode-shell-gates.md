# SCHED-02 supplemental Unicode editor gate

Scope: test-only coverage for the independently observed UTF-16 length mutant. Production validators already use the required Dart String.length after trim; no production code is changed.

The editor test adds two SCHED-02 scenarios:

- Creating with whitespace-padded 40/60/500 supplementary emojis must return and persist the exact trimmed name/title/body, respectively 80/120/1000 UTF-16 code units, with no truncation.
- Editing an existing persisted rule with whitespace-padded 41/61/501 supplementary emojis must visibly show the exact name/title/body field errors, retain every input verbatim, issue no new create or update, report no save, and preserve the raw existing catalog.

The rejected scenario checks actual error widgets scoped to their TextFormField and visible on screen. Thus an editor-only length-to-runes mutation cannot be hidden by the core model rejecting the draft.

Gate execution completed under the exclusive SDK handoff. All author gates passed. The root independent verifier owns scratch mutation red/restoration green evidence after the atomic test commits.

## Assertion traceability and necessity

Paths below are relative to the repository and point to apps/popmundo_app/test/scheduler_editor_test.dart after formatter execution.

| SCHED-02 outcome | Exact assertion evidence | Coverage / necessity |
| --- | --- | --- |
| After-trim name boundary has no truncation | :54 expect(authoritative.name, name); :55 expect(authoritative.name.length, 80); :62 expect(persisted.name, name) | Exact 40-emoji value in successful reply and storage; required UTF-16 boundary |
| After-trim title boundary has no truncation | :56 expect(authoritative.action.title, title); :57 expect(authoritative.action.title.length, 120); :63 expect(persisted.action.title, title) | Exact 60-emoji value in successful reply and storage; required UTF-16 boundary |
| After-trim body boundary has no truncation | :58 expect(authoritative.action.body, body); :59 expect(authoritative.action.body.length, 1000); :64 expect(persisted.action.body, body) | Exact 500-emoji value in successful reply and storage; required UTF-16 boundary |
| Successful return is authoritative persisted state | :60 expect(api.store.raw, saved!.encode()) | SCHED-03 success acknowledged only after persisted state; prevents callback-only proof |
| 41/61/501 emoji inputs get field-specific errors | :117 expect(find.descendant(of: formField, matching: find.text(errors[input.key]!)).hitTestable(), findsOneWidget); errors :108 | Name/title/body exact EN catalog messages; visible per-field errors required by SCHED-02 |
| Invalid inputs retained verbatim | :127 expect(tester.widget<TextFormField>(formField).controller!.text, input.value) | All three padded, overlong inputs retained; SCHED-02/03 error behavior |
| Invalid save never reports success or submits a mutation | :133 expect(saved, isNull); :134 expect(api.creates, creates); :135 expect(api.updates, 0); :136 expect(api.savedDraft!.name, 'original') | SCHED-02 invalid input blocks create/update before core can hide the UI error |
| Existing saved catalog preserved byte-for-byte | :137 expect(api.store.raw, raw) | SCHED-02 invalid input must not mutate saved state |

All new assertions map to SCHED-02 or its existing SCHED-03 persistence/retention contract. No framework-only, speculative, skipped, or assertion-free test is added. Both prior tests and production behavior remain unchanged. Per-layer depth is strengthened specifically against the observed Unicode mutant; no architectural or product-flow documentation change is required.

## Author execution results

All commands were executed natively on Windows from apps/popmundo_app on 2026-10-05, serially under the root SDK handoff. CLI command spaces are preserved below; evidence logs have only ANSI color sequences and carriage returns normalized.

| Command | Exit | Result | Log |
| --- | --- | --- | --- |
| cmd.exe /d /c dart.bat format test/scheduler_editor_test.dart | 0 | 1 file formatted | unicode-shell-format.log |
| cmd.exe /d /c flutter.bat test test/scheduler_editor_test.dart --reporter expanded | 0 | 10 tests passed (8 existing + 2 new) | unicode-shell-editor-tests.log |
| cmd.exe /d /c flutter.bat test --reporter expanded | 0 | 140 tests passed (138 existing + 2 new) | unicode-shell-app-tests.log |
| cmd.exe /d /c flutter.bat analyze | 0 | No issues found | unicode-shell-analysis.log |

Adequacy verdict: all task criteria covered with exact values and located assertions; both tests are necessary for SCHED-02, inspect resulting UI/persisted payload rather than only call counts, and follow the existing editor widget-test conventions. No production code, existing assertion, or unrelated file changed. Author green gates are complete; mutation discrimination awaits the independent verifier.
