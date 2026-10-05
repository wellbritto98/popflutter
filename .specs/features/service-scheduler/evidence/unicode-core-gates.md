# SCHED-02 supplementary UTF-16 model gates

Test-only change after the independent discrimination sensor found that replacing String.length with runes.length survived the original ASCII-only boundary tests. SCHED-02 explicitly counts UTF-16 code units after trim and forbids silent truncation. No production code, public API, recurrence behavior or dependency changes are required.

## Exact acceptance mapping

| SCHED-02 outcome | Oracle in packages/popmundo_utils/test/scheduler_models_test.dart |
| --- | --- |
| Name maximum80, title maximum120, body maximum1000 UTF-16 units are inclusive after trim | Lines78–84 construct40,60,500 supplementary emoji respectively and wrap each with spaces, tab and newline. Lines100–103 assert exact trimmed name and complete action payload in both draft and saved rule JSON. |
| Saved Unicode payload survives encode/decode without normalization/truncation | Lines104–108 roundtrip SchedulerSnapshot and assert exact name and complete action map containing localNotification type, title and body. |
| Name82/title122/body1002 units fail rather than truncate | Lines110–130 run three distinct cases using41,61,501 supplementary emoji with surrounding whitespace; each requires SchedulerException.code == invalidText. |

The four new tests specifically distinguish UTF-16 code-unit limits from rune-count limits. Existing tests were retained unchanged. This model gate covers the pure-Dart boundary and snapshot payload; UI error/no-save behavior belongs to the separate shell gate. No WebView JavaScript changes are needed (AD-002).

## Fresh author gates — 2026-10-05

Native Windows SDK commands ran through cmd.exe /d /c from C:\Users\Wellington\Documents\projetos\popflutter\packages\popmundo_utils. All listed commands exited0.

| Command | Actual result | Raw evidence |
| --- | --- | --- |
| dart.bat format --output=none --set-exit-if-changed test/scheduler_models_test.dart | 1 file checked,0 changed | unicode-core-format.log |
| dart.bat test test/scheduler_models_test.dart --reporter expanded | 19 passed,0 failures; previous15,+4 | unicode-core-model-tests.log |
| dart.bat test --reporter expanded | 277 passed,0 failures; previous273,+4 | unicode-core-tests.log |
| dart.bat analyze | No issues found | unicode-core-analysis.log |

Diff whitespace check passed. Production scheduler_models.dart remains unchanged. Independent verifier must rerun the scratch rune-count mutant and record its killed/restored outcome; this author record claims only the green gates above.
