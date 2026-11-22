## Purpose

Read-only measurement of where the space of a Mac's internal disk went: APFS container volumes, Time Machine local snapshots, swap, free space and a list of candidate locations. It exists because `du` and `df /` alone mislead when APFS clones, local snapshots or the swap volume hold the space.

## ADDED Requirements

### Requirement: Probe reports container-level signals

`disk-space.sh probe` SHALL print one `signal=value` line per measured signal: `container_free_pct`, `container_free_gb`, `volume_used_gb_<role>` for each APFS volume role found in the container of the boot volume, `local_snapshots`, `swap_used_gb`, and `probe_result`. Sizes SHALL be whole gigabytes (1 GB = 10^9 bytes, as `diskutil` reports), rounded down; percentages SHALL be whole percent, rounded down. Values SHALL come from property lists (`diskutil apfs list -plist`), `df -k`, `tmutil listlocalsnapshotdates /` and `sysctl -n vm.swapusage`, never from text that changes with the system language. The probe SHALL NOT change any setting, delete any file, or start a backup.

#### Scenario: All sources readable

- **WHEN** every source returns data
- **THEN** the probe prints every signal and `probe_result=ok`

##### Example: container with a large VM volume

- **GIVEN** a fixture container of 1000 GB with Data 900 GB, VM 40 GB, System 15 GB, 2 local snapshots and 38.5 GB of swap used
- **WHEN** `disk-space.sh probe` runs against the fixtures
- **THEN** it prints `volume_used_gb_Data=900`, `volume_used_gb_VM=40`, `local_snapshots=2`, `swap_used_gb=38` and `container_free_pct` computed from the container's free capacity

#### Scenario: A source cannot be read

- **WHEN** one source fails or returns nothing parseable
- **THEN** the probe omits the signals of that source, prints the remaining signals, and prints `probe_result=partial`

### Requirement: Candidate sizes have time limits

`disk-space.sh sizes [MIN_GB]` SHALL measure each location in the shipped `candidates.tsv` and in `~/.config/mac-disk-space/candidates.local.tsv`, expanding `~` and `*` patterns. Each location SHALL get at most 60 seconds and a run at most 300 seconds. A location whose measurement does not finish SHALL be printed with the size `not-measured` and SHALL NOT be counted in any total. The command SHALL NOT scan locations that are not listed.

#### Scenario: A slow location

- **WHEN** one location takes longer than its limit
- **THEN** its row shows `not-measured` and the other rows are printed with their sizes

##### Example: limits

| Situation | Row output |
|---|---|
| finished in 2 s, 24 GB | `24` |
| still running at 60 s | `not-measured` |
| run reached 300 s before this location started | `not-measured` |

### Requirement: Cloud-synced locations report local footprint only

For locations of kind `cloud-sync`, `sizes` SHALL report the space the files occupy on this Mac and how much of it is already online-only, judged by the `dataless` file flag and never by file size. It SHALL NOT report such a location as freeable by deletion.

#### Scenario: A synced folder with online-only files

- **WHEN** a `cloud-sync` location holds 10 GB of downloaded files and 50 GB of online-only placeholders
- **THEN** its row reports 10 GB on this Mac and marks the placeholders as already online-only

### Requirement: Unsafe paths are escaped

`sizes` SHALL print a path holding a shell metacharacter or a control character with `printf %q` and its kind prefixed with `unsafe_`, and SHALL look the location up by its raw path before escaping.

#### Scenario: A folder name with a command substitution

- **WHEN** a matched folder is named `$(x) Library`
- **THEN** its row carries the kind `unsafe_<kind>` and the escaped path, and no other row is marked unsafe

### Requirement: Other processes' command lines are never printed

No subcommand SHALL print the full command line of another process. When a signal needs process information, it SHALL use the process name only.

#### Scenario: Swap pressure from many processes

- **WHEN** the probe reports high swap use
- **THEN** its output contains no process arguments
