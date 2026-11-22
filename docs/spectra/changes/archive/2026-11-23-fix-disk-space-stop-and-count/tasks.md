## 1. Measurement keeps what it did

- [x] 1.1 `sizes` prints each row as measured in candidate-list order, and TERM/INT stop the measurement in progress (Candidate sizes have time limits; design: Stream rows instead of sorting, Stop the child from the TERM and INT traps). Verified by `tests/test_sizes.sh` (stopped run keeps its first row, no leftover stub process, for TERM and INT).
- [x] 1.2 A temporary directory that cannot be created stops the run with exit 1 and the reason (Candidate sizes have time limits; design: Fail on a missing temp dir). Verified by `tests/test_cleanup.sh`.
- [x] 1.3 A tab in a path makes it unsafe (Unsafe paths are escaped). Verified by `tests/test_sizes.sh` (one 7-field `unsafe_cache` row).

## 2. online-only reports what it did

- [x] 2.1 `online-only` counts done by exact listed path and prints its counts when stopped, exiting 143 (Unconfirmed files count as failed); `evict.js` writes each result as it goes; files are split with one `find` (design: Counts on stop come from the same function, One find for the dataless split). Verified by `tests/test_online_only.sh` (duplicate and unlisted ok, stopped part-way, 2000 files within 4 s, `Dropbox-*` accepted and a lookalike refused).

## 3. Skill, agent and release

- [x] 3.1 SKILL.md: Step 2 sorts the table; the fallback sets the Bash timeout for `sizes` and names both causes of `not-measured`; `online-only` timeout and stopped output; `unsafe_` rows; closed wording for other cloud services. The agent sets a 330000 ms timeout for `sizes 5`. Verified by `tests/test_skill.sh` and `tests/test_agent.sh`.
- [x] 3.2 Version 0.2.1 in `plugin.json`, CHANGELOG, README and CLAUDE.md; the real-Mac rows say 0.2.1 was not re-run. Verified by `scripts/check-version-bump.sh origin/main` and `scripts/check-privacy.sh`.
