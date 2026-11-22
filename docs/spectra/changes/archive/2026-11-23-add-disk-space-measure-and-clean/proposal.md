## Why

When a Mac's internal disk is nearly full, the obvious measurements mislead: `du` reports a cache as hundreds of gigabytes while deleting it frees little (APFS clones share blocks with other files), deleted files stay on disk while Time Machine local snapshots exist, and the swap volume is invisible to both `df /` and `du`. Users end up deleting the wrong things, or deleting synced cloud files, which deletes them in the cloud as well. The decisions behind this change are recorded in MacHelpdesk/mac-helpdesk#9.

## What Changes

- Add `plugin/scripts/disk-space.sh` with read-only subcommands: `probe` (container volumes, local snapshots, swap, free space), `sizes` (candidate locations with a time limit per location and per run), `match`, `list`, `show`, `validate`.
- Add `plugin/scripts/kb.js`, copied from `mac-timemachine-fix` and adapted, to read the knowledge base.
- Add `plugin/data/problems.json` (known problems) and `plugin/data/candidates.tsv` (locations to measure). Personal additions are read from `~/.config/mac-disk-space/candidates.local.tsv` and `~/.config/mac-disk-space/problems.local.json`.
- Add the skill `plugin/skills/disk-space/SKILL.md`: measure, look the signals up, list every candidate as one row (what it is, its size, what deleting it loses, the cleaning command, the freeable amount or "cannot estimate"), and act only on the rows the user names.
- Cloud-synced folders form their own category: only their local footprint and online-only potential are measured; the only action is making files online-only, asked first.
- Clearing Time Machine local snapshots becomes an asked action owned by this tool.
- Bump the plugin to 0.1.0 and add it to the `mac-helpdesk` marketplace index after the skill is verified on a real Mac.

## Non-Goals

- The weekly background measurement and its notification (decisions 6–8 of #9). They are a separate change that reuses `disk-space.sh probe`.
- Shared code across MacHelpdesk tools; each tool keeps its own copy of `kb.js` (decision 4 of #9).
- External disks, network volumes and backup disks.

## Capabilities

### New Capabilities

- `disk-space-probe`: read-only measurement of container volumes, local snapshots, swap, free space and candidate locations, with time limits and explicit "not measured" markers
- `disk-space-knowledge-base`: the known-problem knowledge base and the candidate list, their closed value lists, and how personal additions are read
- `disk-space-skill`: the per-item judgement table and the closed boundaries of what the skill does directly, asks first, leaves to the user, and never does
- `disk-space-online-only`: the one subcommand that changes the system, confined to the cloud services whose online-only mechanism was verified, counting unconfirmed files as failed

### Modified Capabilities

(none)

## Impact

- New files under plugin/scripts, plugin/data and plugin/skills; new tests under tests.
- README.md, CLAUDE.md and CHANGELOG.md of this repository.
- Later, the marketplace index in the MacHelpdesk/mac-helpdesk repository, and the `source-disk-nearly-full` entry of mac-timemachine-fix, which will point to this tool.
