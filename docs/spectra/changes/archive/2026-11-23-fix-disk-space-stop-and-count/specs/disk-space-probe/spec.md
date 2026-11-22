## MODIFIED Requirements

### Requirement: Candidate sizes have time limits

`disk-space.sh sizes [MIN_GB]` SHALL measure each location in the shipped `candidates.tsv` and in `~/.config/mac-disk-space/candidates.local.tsv`, expanding `~` and `*` patterns. Each location SHALL get at most 60 seconds and a run at most 300 seconds; stopping a measurement that ran out of time SHALL take at most 3 more seconds. The 60 seconds of a location cover every measurement of that location, including the online-only scan of a `cloud-sync` location. A location whose measurement does not finish, or whose measuring command exits with a non-zero status (for example a folder it cannot fully read), SHALL be printed with the size `not-measured` and SHALL NOT be counted in any total. A stopped measurement SHALL leave no process running. Rows SHALL be printed as each location is measured, in the order of the candidate list, so that a run stopped part-way keeps the rows it measured; when the run itself is stopped (TERM or INT), the measurement in progress SHALL stop with it. The command SHALL NOT scan locations that are not listed. Every subcommand SHALL stop with exit status 1 and a message naming the cause when it cannot create its temporary directory (for example on a full disk), instead of reporting empty or partial results.

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

### Requirement: Unsafe paths are escaped

`sizes` SHALL print a path holding any of the characters $ ` ; | & < > \ " ' ! * ? [ ] ( ) { } or a control character with `printf %q` and its kind prefixed with `unsafe_`, and SHALL look the location up by its raw path before escaping. A space alone SHALL NOT make a path unsafe. A tab is a control character and does make it unsafe, since `sizes` output is tab-separated. This list of characters is closed.

#### Scenario: A folder name with a tab

- **WHEN** a matched folder name holds a tab
- **THEN** its row carries the kind `unsafe_<kind>`, so the tab cannot split the row into extra fields

#### Scenario: A folder name with a command substitution

- **WHEN** a matched folder is named `$(x) Library`
- **THEN** its row carries the kind `unsafe_<kind>` and the escaped path, and no other row is marked unsafe
