## Purpose

The subagent that measures a nearly full disk and interprets the measurements on behalf of the `disk-space` skill, so that measurement output stays out of the main conversation. It exists to hand back a per-row report and nothing else: it never cleans, never changes a setting and never writes a file.

## ADDED Requirements

### Requirement: The plugin ships the disk-space-measure agent

The plugin SHALL ship one subagent definition at `plugin/agents/disk-space-measure.md` whose frontmatter declares `name: disk-space-measure`, `model: sonnet`, and a `tools` list containing exactly `Bash` and `Read`. Its `description` SHALL name the `disk-space` skill as its caller. The frontmatter SHALL NOT declare `hooks`, `mcpServers` or `permissionMode`.

#### Scenario: The definition is loaded from the plugin

- **WHEN** the plugin is installed
- **THEN** the subagent is available under the identifier `mac-disk-space:disk-space-measure`

##### Example: frontmatter of the shipped agent

| Field | Expected | Notes |
| ----- | -------- | ----- |
| name | disk-space-measure | |
| model | sonnet | |
| tools | Bash, Read | no Write, Edit or NotebookEdit |
| hooks, mcpServers, permissionMode | absent | ignored for plugin subagents |

### Requirement: The agent runs a closed list of read-only commands

The agent SHALL run only these commands: `disk-space.sh probe`; `disk-space.sh match`; `disk-space.sh show <id>` for each id that `match` printed; `disk-space.sh sizes 5`; `df -k /`. This list is closed. The agent SHALL NOT run `disk-space.sh online-only`, any command from the command column of a candidate row, or any command that deletes, moves or writes a file.

#### Scenario: A candidate row carries a cleaning command

- **WHEN** a `sizes` row lists a cleaning command in its command column
- **THEN** the agent copies the command into the report and does not run it

##### Example: subcommands named in the agent definition

| Subcommand | In the agent's list | Notes |
| ---------- | ------------------- | ----- |
| probe | yes | |
| match | yes | |
| show | yes | |
| sizes | yes | |
| online-only | no | the only subcommand that changes anything |
| candidates, list, validate | no | not needed for a report |

### Requirement: The agent report has a fixed shape

The agent SHALL return one report with these parts in this order: a `Signals` section holding every line `probe` printed, unchanged; a `Matched entries` section with the id, verification status and title of each matched entry and the fixes `show` printed for it; a `Candidates` table with exactly one row per row that `sizes` printed; and a final counts line of the form `sizes_rows=<n> table_rows=<n> not_measured=<n> matched=<n>`. Sizes, `not-measured`, kinds including the `unsafe_` prefix, cleaning commands and escaped paths SHALL be copied from the `sizes` output without change. A size that was not measured SHALL NOT be replaced by a number.

#### Scenario: Nothing in the knowledge base matches

- **WHEN** `match` exits with code 3
- **THEN** the report says no entry matched and the counts line carries `matched=0`

#### Scenario: A location was not measured

- **WHEN** a `sizes` row has `not-measured` in its size column
- **THEN** the table keeps that row with `not-measured` and the counts line counts it in `not_measured`

##### Example: counts line for three rows

- **GIVEN** `sizes 5` printed 3 rows, one of them `not-measured`, and `match` printed 2 entries
- **WHEN** the agent writes its report
- **THEN** the last line is `sizes_rows=3 table_rows=3 not_measured=1 matched=2`

### Requirement: The agent never acts and never asks

The agent SHALL NOT clean anything, change any setting, write any file, or write a record under `~/.config/mac-disk-space/`. It SHALL NOT decide which rows to handle. When its task message asks for a cleaning action, it SHALL refuse that part, state that cleaning is done in the main conversation after the user names the rows, and return the report.

#### Scenario: The task message asks the agent to clean a cache

- **WHEN** the agent is dispatched with a message that includes "and clear the largest cache"
- **THEN** the agent returns the report, runs no cleaning command, and states that cleaning belongs to the main conversation

No executable check: this is the behavior of a model following its definition; it is confirmed by reading the agent's transcript on the real-Mac run, and the test only checks that the definition contains the prohibition.
