## Purpose

The skill that turns the probe's measurements into decisions the user makes row by row, with closed tables of what it does directly, asks first, leaves to the user, and never does. It exists because the item most worth deleting is often not the largest one, and some locations cannot be deleted safely at all.

## ADDED Requirements

### Requirement: One row per candidate

After measuring, the skill SHALL present one table in which each candidate is one row stating what it is, its size or `not-measured`, what deleting it loses, the command that cleans it (or none), and the freeable amount or `cannot estimate`. It SHALL state before the table that the list decides where to measure, not what to delete.

#### Scenario: A cache whose blocks are shared

- **WHEN** a package-manager cache is listed and its freeable amount cannot be known in advance
- **THEN** its row shows `cannot estimate` and says the amount is known only after cleaning

### Requirement: Act only on rows the user names

The skill SHALL act only on the rows the user names in this conversation, one row at a time, and SHALL NOT extend a request to rows of the same kind. It SHALL measure free space with `df -k` before and after each action and report both values.

#### Scenario: The user names two rows

- **WHEN** the user answers "clean rows 1 and 3" and row 2 is of the same kind as row 1
- **THEN** the skill cleans rows 1 and 3 only and reports free space before and after each

### Requirement: Things the skill does directly

The skill SHALL do only these without asking, and SHALL report them: the read-only subcommands of `disk-space.sh`; `df -k`; writing a record under `~/.config/mac-disk-space/records/`; adding an entry to `~/.config/mac-disk-space/problems.local.json` or a line to `candidates.local.tsv` and running `validate`. This list is closed.

#### Scenario: Recording a run

- **WHEN** a run finishes
- **THEN** the skill writes a record with the before and after signals without asking

### Requirement: Things the skill asks first

The skill SHALL ask in this conversation, and act only on a yes, for exactly these: running the cleaning command listed for a candidate of kind `cache`, `download` or `build`; making files of a `cloud-sync` location online-only through a mechanism recorded as verified; deleting Time Machine local snapshots. When asking it SHALL state what is lost, how long re-downloading takes when known, and that deleted snapshots keep no copy of files changed or deleted since they were taken. This list is closed.

#### Scenario: Deleting local snapshots

- **WHEN** the user agrees to delete local snapshots
- **THEN** the skill opens a Terminal window with the command typed in, the user types the password there, and the skill measures free space afterwards

### Requirement: Things left to the user

The skill SHALL only explain the steps, and not perform them, for: deleting the user's own files or folders, including rows of kind `personal`; quitting applications, virtual machines or sessions; making files online-only through a mechanism not recorded as verified; anything in rows of kind `system` that needs administrator rights other than local snapshots. This list is closed.

#### Scenario: A large virtual machine

- **WHEN** a virtual machine image of kind `personal` is the largest row
- **THEN** the skill shows its size and what deleting it loses, offers no command, and leaves the decision and the action to the user

### Requirement: Things the skill never does

The skill SHALL NOT: delete or modify any file inside a `cloud-sync` location; run `rm -rf` on any cache directory instead of the cache's own cleaning command; touch a backup disk; pass a password through the conversation, a file or an environment variable; batch rows the user did not name.

#### Scenario: The user asks to delete the Dropbox folder

- **WHEN** the user asks the skill to delete a cloud-synced folder to free space
- **THEN** the skill refuses deletion, explains that the deletion would sync to the cloud, and offers online-only instead
