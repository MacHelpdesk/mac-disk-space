## Context

0.2.0 hands measurement to the `disk-space-measure` agent; the main conversation measures only as a fallback. Both call `disk-space.sh sizes 5` through Claude Code's Bash tool, whose default timeout is 2 minutes.

## Goals / Non-Goals

**Goals:** a stopped `sizes` or `online-only` keeps and reports what it did; no measurement outlives the run; a full disk is named as the cause.

**Non-Goals:** measuring other File Provider services under `~/Library/CloudStorage` again (MacHelpdesk/mac-disk-space#6); changing the time limits themselves.

## Decisions

### Stream rows instead of sorting

`sizes` runs in the main shell and prints each row as it is measured. Sorting needs all input before the first line, so a stopped `sizes | sort` printed nothing. The table is sorted by whoever builds it (the skill's Step 2).

### Stop the child from the TERM and INT traps

`run_limited` records the measuring command's pid in `CURRENT_PID`; the TERM and INT traps kill it (TERM, then KILL after 2 s, so stopping never hangs) and exit 143 or 130. Long steps run in the background followed by `wait`, so the trap runs at once instead of after the foreground command ends. A real online-only scan (`find … -exec stat … +`) can leave the `stat` it had started running for a moment; it ends on its own and writes nowhere the tool reads.

### Counts on stop come from the same function

`online_only_report` computes and prints the counts. It runs at the end of `online_only`, and from the trap through `ON_STOP` while the evict step runs. Done is counted by matching `ok <path>` lines against the evict list (awk, each path once).

### One find for the dataless split

`find -flags +dataless` and `! -flags +dataless` replace one `stat -f %Sf` per file. A read-only check on macOS 27.3 found both agree on files in iCloud Drive and Dropbox.

### Fail on a missing temp dir

`tmpdir` exits 1 with "cannot create a temporary directory … (is the disk full?)". It is called once in the main shell before any subcommand, so the run stops before measuring anything.

## Risks / Trade-offs

- [Unsorted `sizes` output] → the skill and the agent say to sort; the agent copies rows in output order and the row-count check is unaffected.
- [A child that ignores TERM] → KILL after 2 s.
