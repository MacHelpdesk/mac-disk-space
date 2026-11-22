## Context

Version 0.1.0 ships one skill, `disk-space`, whose first three steps run `disk-space.sh probe`, `match` with `show`, and `sizes 5` in the main conversation. A `sizes` run takes up to 300 seconds and, on the one real-Mac run recorded so far, printed more than two hundred rows (measured, macOS 27.3; tracked in MacHelpdesk/mac-disk-space#1). The decisions behind this change are recorded in MacHelpdesk/mac-disk-space#3.

Constraints read from the Claude Code subagent documentation on 2026-11-22:

- A plugin's `agents/` directory is loaded automatically; only `name` and `description` are required in the frontmatter.
- Plugin subagents ignore the `hooks`, `mcpServers` and `permissionMode` fields.
- Subagents do not receive `AskUserQuestion`.
- The `tools` field grants or withholds a whole tool. A subagent that has `Bash` can run any command.
- A skill with `context: fork` runs entirely inside a subagent.

No tool in the MacHelpdesk series ships a subagent yet.

## Goals / Non-Goals

**Goals:**

- Keep measurement output out of the main conversation while keeping every decision and every cleaning action in it.
- Make an omitted or rewritten row visible to the skill.
- Keep the skill usable when the agent cannot be dispatched.

**Non-Goals:**

- The weekly background measurement and its notification (decisions 6 to 8 of MacHelpdesk/mac-helpdesk#9).
- Reducing the number of rows `sizes` prints (MacHelpdesk/mac-disk-space#1).
- Mechanical enforcement of the read-only boundary inside the agent; the platform offers no per-command restriction for plugin subagents.
- A second entry point: the agent is not documented as something users call by themselves.
- Rejected: `context: fork` on the skill (the skill could no longer ask the user); the agent writing the measurement record (it would need a file-writing tool); returning raw output unchanged (the output would return to the main conversation); the models `haiku` and `inherit`.

## Decisions

### Dispatch through the Agent tool, not context fork

The skill calls the Agent tool with the subagent type `mac-disk-space:disk-space-measure`. Steps 4 to 6 of the skill need the user's answers, and a forked skill has no way to ask.

### Read-only boundary is a tool list plus a closed command list

The agent's frontmatter lists `Bash` and `Read` and nothing else, so it has no file-writing tool. Its body lists the exact commands it runs and states that the list is closed. A test checks the tool list and checks that every listed subcommand exists in `disk-space.sh` and that `online-only` is not among them. What the agent actually runs is confirmed only by reading its transcript on a real Mac.

### Counts line makes omissions visible

The report ends with one line `sizes_rows=<n> table_rows=<n> not_measured=<n> matched=<n>`. The skill counts the table rows it received and compares them with `sizes_rows`. A mismatch is one of the fallback cases. The check is self-reported on the agent's side for `sizes_rows`; it catches a table that lost rows, and it does not catch an agent that miscounts both numbers the same way.

### Fallback keeps the skill usable

When the agent cannot be used the skill runs the same three commands in the main conversation. The commands are therefore written in two places; a test compares the two lists.

### Model is sonnet

The work is running commands and copying fields into a table. `sonnet` is named in the frontmatter so the cost of a run does not follow the model of the main conversation.

### Records stay with the skill

The record needs the free space before and after each cleaning action, which only the main conversation knows.

## Implementation Contract

**Behavior.** A user who invokes the `disk-space` skill sees one sentence saying the measurement is handed to an agent, then the per-row table, then the question which rows to handle. The probe output, the `show` text and the raw `sizes` rows do not appear in the main conversation unless the fallback runs.

**Interface.**

- Agent file: `plugin/agents/disk-space-measure.md`, frontmatter `name: disk-space-measure`, `model: sonnet`, `tools: Bash, Read`, and a `description` that names the `disk-space` skill as its caller.
- Commands the agent runs, closed list: `disk-space.sh probe`; `disk-space.sh match`; `disk-space.sh show <id>` for each matched id; `disk-space.sh sizes 5`; `df -k /`.
- Report, in this order: a `Signals` section with the probe lines unchanged; a `Matched entries` section with id, verification status and title per entry and the fixes `show` printed; a `Candidates` table with one row per `sizes` row and the columns number, location, size, kind, what deleting it loses, cleaning command, origin, online-only GB; the counts line.
- Sizes, `not-measured`, kinds (including the `unsafe_` prefix), commands and escaped paths are copied from the `sizes` output without change.

**Failure modes.** `probe_result=partial` is reported as it is. `match` exit code 3 is reported as "no entry matched" with `matched=0`. A `sizes` run that hits the time limit is reported with its `not-measured` rows. The four fallback cases are: the user declines the dispatch; the Agent tool is not available; the agent returns an error or no report; the table row count differs from `sizes_rows` or the counts line is missing.

**Acceptance.** `tests/test_agent.sh` passes under `/bin/bash`; `claude plugin validate plugin` passes; one real-Mac run records the four verification items in the README table, or the agent stays marked unverified.

**Scope.** In: the agent file, the skill text, the test, docs, the version. Out: any change to `disk-space.sh`, the knowledge base or the candidate list; the marketplace index.

## Risks / Trade-offs

- [The agent runs a command outside its list] → no file-writing tool; closed list in its body; transcript read on the real-Mac run; documentation states that the boundary is not enforced by the platform.
- [The agent drops or rewrites rows] → counts line and row comparison; fallback on mismatch.
- [A permission prompt appears inside the agent during a 300-second run] → unmeasured; the real-Mac run records whether and how often prompts appear.
- [The two command lists drift] → test comparing the agent's list with the skill's fallback steps.
- [Cost of an extra model] → `sonnet` fixed in the frontmatter.

## Open Questions

- Whether commands run by a plugin subagent raise permission prompts in the default permission mode. Estimated: yes for `Bash` unless the user allowed it. Confirmed or refuted by the real-Mac run in the tasks.
