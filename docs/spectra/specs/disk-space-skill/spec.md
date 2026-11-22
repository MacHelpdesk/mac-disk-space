# disk-space-skill Specification

## Purpose

The skill that turns the probe's measurements into decisions the user makes row by row, with closed tables of what it does directly, asks first, leaves to the user, and never does. It exists because the item most worth deleting is often not the largest one, and some locations cannot be deleted safely at all.

## Requirements

### Requirement: One row per candidate

After measuring, the skill SHALL present one table in which each candidate is one row stating what it is, its size or `not-measured`, what deleting it loses, the command that cleans it (or none), and the freeable amount or `cannot estimate`. It SHALL state before the table that the list decides where to measure, not what to delete.

#### Scenario: A cache whose blocks are shared

- **WHEN** a package-manager cache is listed and its freeable amount cannot be known in advance
- **THEN** its row shows `cannot estimate` and says the amount is known only after cleaning

---
### Requirement: Act only on rows the user names

The skill SHALL act only on the rows the user names in this conversation, one row at a time, and SHALL NOT extend a request to rows of the same kind. It SHALL measure free space with `df -k` before and after each action and report both values.

#### Scenario: The user names two rows

- **WHEN** the user answers "clean rows 1 and 3" and row 2 is of the same kind as row 1
- **THEN** the skill cleans rows 1 and 3 only and reports free space before and after each

---
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

---
### Requirement: Things the skill asks first

The skill SHALL ask in this conversation, and act only on a yes, for exactly these: running the cleaning command listed for a candidate of kind `cache`, `download` or `build`; making files of a `cloud-sync` location online-only through a mechanism recorded as verified; deleting Time Machine local snapshots. When asking it SHALL state what is lost, how long re-downloading takes when known, and that deleted snapshots keep no copy of files changed or deleted since they were taken. This list is closed.

#### Scenario: Deleting local snapshots

- **WHEN** the user agrees to delete local snapshots
- **THEN** the skill opens a Terminal window with the command typed in, the user types the password there, and the skill measures free space afterwards

---
### Requirement: Things left to the user

The skill SHALL only explain the steps, and not perform them, for: deleting the user's own files or folders, including rows of kind `personal`; deleting rows of kind `cache`, `download` or `build` that have no command; quitting applications, virtual machines or sessions; making files online-only through a mechanism not recorded as verified; anything in rows of kind `system` that needs administrator rights other than local snapshots. This list is closed.

#### Scenario: A build folder without a command

- **WHEN** the user names a row of kind `build` whose command field is empty
- **THEN** the skill explains what deleting it loses and leaves the deletion to the user, and composes no command

#### Scenario: A large virtual machine

- **WHEN** a virtual machine image of kind `personal` is the largest row
- **THEN** the skill shows its size and what deleting it loses, offers no command, and leaves the decision and the action to the user

---
### Requirement: Things the skill never does

The skill SHALL NOT: delete or modify any file inside a `cloud-sync` location; run `rm -rf` on any cache directory instead of the cache's own cleaning command; touch a backup disk; pass a password through the conversation, a file or an environment variable; batch rows the user did not name.

#### Scenario: The user asks to delete the Dropbox folder

- **WHEN** the user asks the skill to delete a cloud-synced folder to free space
- **THEN** the skill refuses deletion, explains that the deletion would sync to the cloud, and offers online-only instead

---
### Requirement: Measurement is delegated to the agent

The skill SHALL obtain the probe signals, the matched knowledge-base entries and the candidate sizes by dispatching the `mac-disk-space:disk-space-measure` agent once, and SHALL build its per-row table from the agent's report. The skill SHALL NOT pass the user's request for cleaning to the agent.

#### Scenario: The user asks to free space

- **WHEN** the user says the disk is nearly full and asks to clear caches
- **THEN** the skill dispatches the agent with a measuring task only, and asks the user which rows to handle after the report returns

No executable check: dispatching is a tool call made by the model reading the skill; the test checks that the skill text names the agent identifier in its measuring step and that the task list has one measuring task.

---
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

---
### Requirement: Fallback to measuring in the main conversation

The skill SHALL measure in the main conversation, by running `disk-space.sh probe`, `disk-space.sh match` with `disk-space.sh show <id>`, and `disk-space.sh sizes 5` itself, in exactly these cases: the user declines the dispatch; the Agent tool is not available in the session; the agent returns an error or no report; the count check fails. This list is closed. Before measuring it SHALL tell the user in one sentence that it measures in the main conversation and why. The commands of the fallback SHALL be the same subcommands the agent definition lists.

#### Scenario: The Agent tool is not available

- **WHEN** the session has no Agent tool
- **THEN** the skill says it measures in the main conversation because no agent can be dispatched, and runs the three measuring commands itself

##### Example: fallback and agent command lists agree

- **GIVEN** the agent definition lists the subcommands probe, match, show and sizes
- **WHEN** the subcommands named in the skill's fallback steps are collected
- **THEN** the two sets are equal

---
### Requirement: Agent verification record

The documentation SHALL mark the agent as verified only when one run on a real Mac, dispatched from the skill, records all four of these: the row count of the returned table equals the row count `sizes` printed; the agent's transcript contains only commands from its closed list; whether permission prompts appeared inside the agent and how many; the macOS version and the Claude Code version. When any of the four is missing the documentation SHALL mark the agent as unverified. This list is closed.

#### Scenario: The run did not record permission prompts

- **WHEN** a real-Mac run records the row counts, the transcript check and the versions, and does not record whether permission prompts appeared
- **THEN** the README verification table marks the agent as unverified

No executable check: the record is written by a person after a run on a real Mac; the test checks that the README verification table has a row for the agent whose status is one of verified or unverified.
