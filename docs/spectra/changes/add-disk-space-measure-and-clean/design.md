## Context

The tool is a public plugin in the MacHelpdesk series (MacHelpdesk/mac-helpdesk#9). Its siblings `mac-dropbox-fix` and `mac-timemachine-fix` share one shape: a read-only bash script that prints `signal=value` lines, a JSON knowledge base read by a JXA script (`kb.js`), and a skill whose boundaries are four closed tables. This repository so far holds only the skeleton (manifest, docs, CI, check scripts).

Facts that shaped the design, observed on one Mac (macOS 27.3) while the issue was filed:

- `du` on the home directory and `find -size` both ran for more than 10 minutes without finishing; one test tool had left directories nested hundreds of levels deep.
- Deleting a package-manager cache freed far less than `du` reported, and freed almost nothing until the Time Machine local snapshots were deleted.
- The swap volume held tens of gigabytes in the same APFS container, invisible to `df /`.

Constraints from the series: scripts run under the system `/bin/bash` 3.2, parse no localized text, write personal output only under `~/.config/<tool>/`, and every action that changes the system is listed in a closed table.

## Goals / Non-Goals

**Goals:**

- Show where the space of the internal disk went, at the container level, in under five minutes.
- List each candidate location as one row with enough information for the user to decide it alone: what it is, its size, what deleting it loses, the command that cleans it, and the freeable amount or "cannot estimate".
- Act only on the rows the user names, and measure free space before and after.

**Non-Goals:**

- The weekly background measurement and its notification (a later change).
- A full scan of the home directory.
- Deleting user files, or any file inside a cloud-synced folder.
- External disks, network volumes and backup disks.
- Shared code across MacHelpdesk tools.

## Decisions

### Copy kb.js from mac-timemachine-fix instead of sharing code

Each sibling keeps its own `kb.js`. A shared copy would make every tool depend on the umbrella and complicate release order; with three tools the duplication is small. Revisit when a fourth tool needs it (decision 4 of #9).

### Candidate list decides where to measure, never what to delete

`candidates.tsv` lists locations with a kind and a reason. Its kinds say how a location is handled, not whether it may be deleted: every row is judged by the user. Alternative rejected: a "safe to delete" flag, because the same folder can hold irreplaceable content on one Mac (a model folder with the user's own trained weights) and nothing of value on another.

### Cloud-synced folders are a separate kind with online-only as the only action

Deleting a file in a synced folder deletes it in the cloud. Such locations get the kind `cloud-sync`; the probe reports their local footprint and how much is already online-only (the `dataless` flag, as `mac-dropbox-fix` does), and the skill never offers deletion for them.

### Time limits per location and per run

Each location gets at most 60 seconds of `du` and a run at most 300 seconds. A location that runs out is reported as `not-measured`, never as a partial number. Alternative rejected: one global timeout, because a single slow location would hide all the others.

### Clearing local snapshots belongs to this tool

Clearing Time Machine local snapshots is often the only step that returns space after other deletions; it is an asked action here, and `mac-timemachine-fix` points to this tool for it (decision 5 of #9). It needs administrator rights, so it follows the Terminal-window pattern of `mac-timemachine-fix` 0.1.1: the skill opens Terminal with the command typed in and the user enters the password there.

### Spike before specifying snapshot reserve and online-only mechanisms

Two facts are not yet measured: whether the space held by local snapshots can be known before deleting them, and which command makes files online-only for each sync service. Each gets a spike task; until a spike records a verified result, the probe reports `cannot-estimate` and the skill leaves online-only to the user in Finder.

## Implementation Contract

**Behavior.** `/mac-disk-space:disk-space` measures, looks the signals up, prints one table of candidates, asks which rows to act on, acts only on those rows within the boundary tables, and measures again. Nothing is deleted or changed without the user naming the row in this conversation.

**Interface.** `plugin/scripts/disk-space.sh` subcommands, all read-only:

| Subcommand | Output |
|---|---|
| `probe` | `signal=value` lines: `container_free_pct`, `container_free_gb`, `volume_used_gb_<role>` for Data, VM, System, Preboot, Recovery, `local_snapshots`, `swap_used_gb`, `probe_result` |
| `sizes [MIN_GB]` | tab-separated rows: size in GB or `not-measured`, kind, path (escaped and marked `unsafe_` when it holds a shell metacharacter or a control character), reason |
| `match [FILE]`, `list`, `show ID`, `validate` | as in `mac-timemachine-fix`; `match` exits 3 when nothing matches |

**Data shapes.** `candidates.tsv`: three tab-separated fields (path with `~` and `*`, kind, reason); kinds are a closed list: `cache`, `download`, `build`, `personal`, `cloud-sync`, `system`. `problems.json`: the schema of `mac-timemachine-fix` (signals, never, problems with `match.all`, fixes with `class` direct/ask/user and `evidence` verified/reported/unverified).

**Failure modes.** A command that fails or times out yields no signal line or `not-measured`; an absent signal never matches a condition. A malformed personal file is reported and left out, never hiding the shipped entries.

**Acceptance.** Fixture tests for every subcommand; the privacy check passes; one run on a real Mac recorded in the README verification table with the macOS version; every number in docs labelled measured or estimated.

**Scope.** In: the script, the knowledge base, the candidate list, the skill, docs, tests, and the two spikes. Out: the weekly agent and notification, any deletion command beyond the cleaning commands named in `candidates.tsv`, the marketplace entry until the real-Mac run passes.

## Risks / Trade-offs

- [The user deletes something irreplaceable because the row looked safe] → every row states what deleting it loses; the skill never batches rows the user did not name; `personal` rows carry no cleaning command.
- [Freeable estimates promise space that never returns] → estimates are labelled; APFS-cloned caches and snapshot-held data are reported as `cannot-estimate`; `df` is measured before and after.
- [A slow location blocks the run] → per-location and per-run limits with `not-measured`.
- [Process output leaks credentials] → the script never prints full command lines of other processes.
- [Snapshot deletion needs a password] → Terminal window, password typed by the user, never through the conversation.
