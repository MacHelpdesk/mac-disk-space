## MODIFIED Requirements

### Requirement: Things the skill does directly

The skill SHALL do only these without asking, and SHALL report them: the read-only subcommands of `disk-space.sh`; `df -k`; dispatching the `mac-disk-space:disk-space-measure` agent; writing a record under `~/.config/mac-disk-space/records/`; adding an entry to `~/.config/mac-disk-space/problems.local.json` or a line to `candidates.local.tsv` and running `validate`. This list is closed.

#### Scenario: Recording a run

- **WHEN** a run finishes
- **THEN** the skill writes a record with the before and after signals without asking

#### Scenario: Dispatching the agent

- **WHEN** the skill starts measuring
- **THEN** it tells the user in one sentence that measurement is handed to an agent and dispatches it without asking

##### Example: rows of the table of things done directly

| Row | Action | Notes |
| --- | ------ | ----- |
| 1 | read-only subcommands of disk-space.sh | unchanged |
| 2 | df -k / | unchanged |
| 3 | dispatch mac-disk-space:disk-space-measure | new |
| 4 | write a record | unchanged |
| 5 | add a personal entry or candidate line, then validate | unchanged |

## ADDED Requirements

### Requirement: Measurement is delegated to the agent

The skill SHALL obtain the probe signals, the matched knowledge-base entries and the candidate sizes by dispatching the `mac-disk-space:disk-space-measure` agent once, and SHALL build its per-row table from the agent's report. The skill SHALL NOT pass the user's request for cleaning to the agent.

#### Scenario: The user asks to free space

- **WHEN** the user says the disk is nearly full and asks to clear caches
- **THEN** the skill dispatches the agent with a measuring task only, and asks the user which rows to handle after the report returns

No executable check: dispatching is a tool call made by the model reading the skill; the test checks that the skill text names the agent identifier in its measuring step and that the task list has one measuring task.

### Requirement: The skill checks the agent's counts

Before presenting the table the skill SHALL count the rows of the `Candidates` table it received and compare the count with `sizes_rows` on the counts line. When they are equal the skill SHALL continue. When they differ, or the counts line is missing, the skill SHALL tell the user which numbers differ and SHALL use the fallback.

#### Scenario: The table lost rows

- **WHEN** the counts line says `sizes_rows=40` and the table the skill received has 37 rows
- **THEN** the skill tells the user that 40 rows were measured and 37 were returned, and measures in the main conversation

##### Example: count comparison

| sizes_rows | Rows received | Counts line present | Result |
| ---------- | ------------- | ------------------- | ------ |
| 12 | 12 | yes | continue |
| 40 | 37 | yes | fallback |
| 12 | 12 | no | fallback |

No executable check: the comparison is made by the model reading the skill; the test checks that the skill text states the three cases of this table.

### Requirement: Fallback to measuring in the main conversation

The skill SHALL measure in the main conversation, by running `disk-space.sh probe`, `disk-space.sh match` with `disk-space.sh show <id>`, and `disk-space.sh sizes 5` itself, in exactly these cases: the user declines the dispatch; the Agent tool is not available in the session; the agent returns an error or no report; the count check fails. This list is closed. Before measuring it SHALL tell the user in one sentence that it measures in the main conversation and why. The commands of the fallback SHALL be the same subcommands the agent definition lists.

#### Scenario: The Agent tool is not available

- **WHEN** the session has no Agent tool
- **THEN** the skill says it measures in the main conversation because no agent can be dispatched, and runs the three measuring commands itself

##### Example: fallback and agent command lists agree

- **GIVEN** the agent definition lists the subcommands probe, match, show and sizes
- **WHEN** the subcommands named in the skill's fallback steps are collected
- **THEN** the two sets are equal

### Requirement: Agent verification record

The documentation SHALL mark the agent as verified only when one run on a real Mac, dispatched from the skill, records all four of these: the row count of the returned table equals the row count `sizes` printed; the agent's transcript contains only commands from its closed list; whether permission prompts appeared inside the agent and how many; the macOS version and the Claude Code version. When any of the four is missing the documentation SHALL mark the agent as unverified. This list is closed.

#### Scenario: The run did not record permission prompts

- **WHEN** a real-Mac run records the row counts, the transcript check and the versions, and does not record whether permission prompts appeared
- **THEN** the README verification table marks the agent as unverified

No executable check: the record is written by a person after a run on a real Mac; the test checks that the README verification table has a row for the agent whose status is one of verified or unverified.
