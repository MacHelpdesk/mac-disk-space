## Why

After 0.1.0 shipped, the second and third rounds of spectra-verify and spectra-review on `add-disk-space-measure-and-clean` (MacHelpdesk/mac-helpdesk#9) found that the tool loses what it already did when it is stopped, and that it says nothing useful on a full disk:

- `sizes` printed nothing until every location was measured, sorted at the end. Claude Code's Bash tool stops a command after 2 minutes by default and `sizes` may take 5, so a stopped run lost every row, and the measurement in progress kept running.
- `online-only` printed no counts when it was stopped, so files already made online-only were not reported, and a TERM to the script alone did not stop the evict step. It also judged each file with its own `stat` (slow on large folders) and counted done by lines, not by path.
- When `mktemp -d` failed (the disk this tool is for is full), every measurement came back empty with no reason.

## What Changes

- `sizes` prints each row as it is measured, in candidate-list order; TERM and INT stop the measurement in progress. The skill sorts the table.
- `online-only` lists files with one `find`, counts done by exact listed path, and prints its counts when stopped; `evict.js` writes each result as it goes.
- A temporary directory that cannot be created stops the run with exit 1 and the reason.
- A tab in a path makes it unsafe (it is a control character and the output is tab-separated); the spec said otherwise.
- SKILL.md and the `disk-space-measure` agent set the Bash timeout for `sizes` and `online-only` and say what stopped output means.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `disk-space-probe`: rows are streamed and stopping is specified; the temp-dir failure; a tab makes a path unsafe
- `disk-space-online-only`: done is matched by path; counts are printed when stopped

## Impact

- `plugin/scripts/disk-space.sh`, `plugin/scripts/evict.js`, `plugin/skills/disk-space/SKILL.md`, `plugin/agents/disk-space-measure.md`, tests. Version 0.2.1.
