## Purpose

Read-only measurement of where the space of a Mac's internal disk went: APFS container volumes, Time Machine local snapshots, swap, free space and a list of candidate locations. It exists because `du` and `df /` alone mislead when APFS clones, local snapshots or the swap volume hold the space.

## ADDED Requirements

### Requirement: Probe reports container-level signals

`disk-space.sh probe` SHALL print one `signal=value` line per measured signal: `container_free_pct`, `container_free_gb`, `purgeable_gb`, `volume_used_gb_<role>` for the roles `Data`, `VM`, `System`, `Preboot` and `Recovery` found in the container of the boot volume (a closed list; other roles are not reported), `local_snapshots`, `swap_used_gb`, and `probe_result`. Sizes SHALL be whole gigabytes (1 GB = 10^9 bytes, as `diskutil` reports), rounded down; percentages SHALL be whole percent, rounded down. Values SHALL come from property lists (`diskutil apfs list -plist`), `df -k`, the volume capacity keys `NSURLVolumeAvailableCapacityKey` and `NSURLVolumeAvailableCapacityForImportantUsageKey` of `/` (`purgeable_gb` is the second minus the first: space the system can reclaim from purgeable data, including local snapshots and other purgeable data, not snapshots alone), `tmutil listlocalsnapshotdates /` and `sysctl -n vm.swapusage`, never from text that changes with the system language. The probe SHALL NOT change any setting, delete any file, or start a backup.

#### Scenario: All sources readable

- **WHEN** every source returns data
- **THEN** the probe prints every signal and `probe_result=ok`

##### Example: container with a large VM volume

- **GIVEN** a fixture container of 1000 GB with Data 900 GB, VM 40 GB, System 15 GB, 2 local snapshots and 38.5 GB of swap used
- **WHEN** `disk-space.sh probe` runs against the fixtures
- **THEN** it prints `volume_used_gb_Data=900`, `purgeable_gb` from the two capacity keys, `volume_used_gb_VM=40`, `local_snapshots=2`, `swap_used_gb=38` and `container_free_pct` computed from the container's free capacity

#### Scenario: A source cannot be read

- **WHEN** one source fails or returns nothing parseable
- **THEN** the probe omits the signals of that source, prints the remaining signals, and prints `probe_result=partial`

### Requirement: Candidate sizes have time limits

`disk-space.sh sizes [MIN_GB]` SHALL measure each location in the shipped `candidates.tsv` and in `~/.config/mac-disk-space/candidates.local.tsv`, expanding `~` and `*` patterns. Each location SHALL get at most 60 seconds and a run at most 300 seconds; stopping a measurement that ran out of time MAY take up to 3 more seconds. The 60 seconds of a location cover every measurement of that location, including the online-only scan of a `cloud-sync` location. A location whose measurement does not finish, or whose measuring command exits with a non-zero status (for example a folder it cannot fully read), SHALL be printed with the size `not-measured` and SHALL NOT be counted in any total. A stopped measurement SHALL leave no process running. Rows SHALL be printed as each location is measured, in the order of the candidate list, so that a run stopped part-way keeps the rows it measured; when the run itself is stopped (TERM or INT), the measurement in progress SHALL stop with it. The command SHALL NOT scan locations that are not listed. Every subcommand SHALL stop with exit status 1 and a message naming the cause when it cannot create its temporary directory (for example on a full disk), instead of reporting empty or partial results.

#### Scenario: A folder that cannot be fully read

- **WHEN** `du` prints a total for a location but exits with a non-zero status
- **THEN** that row shows `not-measured`, not the partial total

#### Scenario: A cloud-synced location with a slow online-only scan

- **WHEN** the online-only scan of a `cloud-sync` location runs past what is left of that location's limit
- **THEN** its online-only share is `not-measured`, the location used no more than its limit, and the scan process is no longer running

#### Scenario: The run is stopped from outside

- **WHEN** `sizes` receives TERM after measuring its first location and while measuring the second
- **THEN** the first row is already in its output and the second location's measurement is no longer running

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

`sizes` SHALL print a path holding any of the characters $ ` ; | & < > \ " ' ! * ? [ ] ( ) { } or a control character with `printf %q` and its kind prefixed with `unsafe_`, and SHALL look the location up by its raw path before escaping. A space alone SHALL NOT make a path unsafe. A tab is a control character and does make it unsafe, since `sizes` output is tab-separated. This list of characters is closed.

#### Scenario: A folder name with a tab

- **WHEN** a matched folder name holds a tab
- **THEN** its row carries the kind `unsafe_<kind>`, so the tab cannot split the row into extra fields

#### Scenario: A folder name with a command substitution

- **WHEN** a matched folder is named `$(x) Library`
- **THEN** its row carries the kind `unsafe_<kind>` and the escaped path, and no other row is marked unsafe

### Requirement: Other processes' command lines are never printed

No subcommand SHALL print the full command line of another process. When a signal needs process information, it SHALL use the process name only.

#### Scenario: Swap pressure from many processes

- **WHEN** the probe reports high swap use
- **THEN** its output contains no process arguments
