# Grounded findings during execution

These are corrected findings, retained for independent validation and later reusable lesson distillation. Machine-owned lesson files were not edited; user prohibits Python/file-manipulation scripts.

- F1: live native GET of the expected login page was rejected because the generic authenticated-page guard excluded login forms. The synthetic login fixture omitted the real ucLogin markers and did not catch this. Fix1e5535d explicitly allows that initial login page only; authenticated routes remain strict. Evidence f1-red/green and opt-in live session proof.
- T3 origin: a post-auth profile/target could redirect to another permitted Popmundo host, have its form/identity checked there, and then submit to the old origin. T3 now requires the chosen verified origin on profile, target, discovery and gameplay response. Five new origin/form cases were red before correction; post-effect redirect is uncertain, never retry. Evidence t3-review.md and commit18e26aa.
- T3 status: missing fresh gameplay form was safely blocked but classified failed. SGA-08.1 requires unavailable for absent target/form. Execution-level missing/empty form assertions now require unavailable and zero gameplay POST, preserving future recurrence.

Lesson candidates to re-derive: include authentic non-secret marker shapes in fixtures; bind fresh state and identity to the same authenticated origin used for the effect; assert truthful result categories in addition to zero effects. Final verifier independently checks outcomes and mutation sensitivity before promoting any lesson.

- T5 disposal: coordinator previously cancelled only the active HTTP transaction and delayed service.dispose until its own queue drained. A discovery already queued in the independent service could start a new transport in that gap. The new execution test reproduced discoveryStarted instead of serviceUnavailable (t5-dispose-race-red.log). Production fix starts service shutdown immediately and awaits both queues together; green race test plus full405 core/165 app gates and analyses passed in3cb4ecf. Lesson candidate: close admission synchronously before draining work, across every collaborator queue sharing the lifecycle.

### F2 user clarification 2026-10-06

User reported crew artist visible and Save disabled after a likely weekly payment; also no visible fetch feedback. User now requires future scheduling regardless of current weekly availability and maximum bonus as default. Initial requirement requiring a presently offered quote excluded this legitimate future case. New contract uses optional quote cap (legacy caps preserved); unavailable-now is disclosed, fresh server form still required at execution. No real gameplay effect submitted. Browser read-only Troy/black panties on assigned host75 currently shows levels14..20; this does not reproduce the unavailable band selected by user.
