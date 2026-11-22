## Why

The `disk-space` skill runs its measurements in the main conversation, so the probe output, the knowledge-base entries and a candidate listing of up to several hundred rows all land in the context the user is working in. The user asked for an agent that takes this work (MacHelpdesk/mac-disk-space#3): a subagent measures and interprets, the main conversation keeps only the per-row table and still asks the user before anything is cleaned.

## What Changes

- Add a plugin subagent `disk-space-measure` (file `plugin/agents/disk-space-measure.md`, identifier `mac-disk-space:disk-space-measure`, model `sonnet`, tools `Bash` and `Read` only). It runs a closed list of read-only commands and returns a report: the probe signals, the matched knowledge-base entries, one table row per candidate, and a counts line.
- The agent never cleans, never changes a setting and never writes a file. It cannot ask the user anything; every question stays in the main conversation.
- The `disk-space` skill dispatches the agent for its three measuring steps, checks the counts line against the table it received, and continues with the per-row table, the user's choice, the cleaning and the record as before.
- When the agent cannot be used, the skill measures in the main conversation as in 0.1.0, after telling the user in one sentence. The cases are a closed list of four.
- Documentation marks the agent as verified only after one real-Mac run records four named items.
- Bump the plugin to 0.2.0.

## Non-Goals (optional)

## Capabilities

### New Capabilities

- `disk-space-agent`: the shipped subagent definition, the closed list of commands it runs, the shape of its report, and what it never does

### Modified Capabilities

- `disk-space-skill`: the list of things the skill does directly gains dispatching the agent; new requirements for delegation, the count check, the fallback and the agent's verification record

## Impact

- New file plugin/agents/disk-space-measure.md and new test tests/test_agent.sh.
- plugin/skills/disk-space/SKILL.md: the task table, the measuring steps and the table of things done directly.
- plugin/.claude-plugin/plugin.json (version), README.md, CHANGELOG.md, CLAUDE.md.
- Depends on the change add-disk-space-measure-and-clean being archived first, because this change modifies a requirement of the `disk-space-skill` spec that the earlier change introduces.
