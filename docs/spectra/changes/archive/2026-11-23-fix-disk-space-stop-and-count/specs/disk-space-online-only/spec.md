## MODIFIED Requirements

### Requirement: Unconfirmed files count as failed

A file SHALL count as done only when the evict step reported it as done, matched by its exact listed path and counted once; a report for a path that was not listed SHALL be ignored. A file reported as failed, and a file the evict step did not report on at all (it crashed, was stopped, or printed nothing), SHALL count as failed. When any file failed, `online-only` SHALL exit with status 2. When `online-only` itself is stopped (TERM or INT), it SHALL stop the evict step, print the three counts as they stand (files the evict step had already reported as done count as done, the rest as failed), and exit with status 143 (TERM) or 130 (INT).

#### Scenario: Stopped part-way

- **WHEN** `online-only` receives TERM after the evict step reported the first of two files as done
- **THEN** it prints `online_only_done=1` and `online_only_failed=1`, the evict step is no longer running, and it exits 143 within a few seconds

#### Scenario: A file reported twice

- **WHEN** the evict step reports the first of two files as done twice and the second not at all
- **THEN** `online-only` prints `online_only_done=1` and `online_only_failed=1` and exits 2

#### Scenario: The evict step fails as a whole

- **WHEN** the evict step exits with an error and prints nothing for two listed files
- **THEN** `online-only` prints `online_only_done=0` and `online_only_failed=2` and exits 2
