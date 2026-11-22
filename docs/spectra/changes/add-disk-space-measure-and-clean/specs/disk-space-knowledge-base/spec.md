## Purpose

The known-problem knowledge base and the candidate list that the probe and the skill read, with closed value lists so that a malformed entry is rejected instead of changing what the skill does. It exists so that each disk-space situation, its cause and its fixes are written down once with their verification status.

## ADDED Requirements

### Requirement: Knowledge base schema and closed lists

`plugin/data/problems.json` SHALL follow the schema used by `mac-timemachine-fix`: `signals`, `never`, and `problems` whose `match.all` conditions use only listed signals and the operators `equals`, `not_equals`, `gte`, `lte`; fixes whose `class` is one of `direct`, `ask`, `user`; and `evidence` one of `verified`, `reported`, `unverified`. `disk-space.sh validate` SHALL reject any other value and exit non-zero.

#### Scenario: An entry with an unknown class

- **WHEN** an entry has a fix with `class` set to `sometimes`
- **THEN** `validate` reports the entry and exits non-zero

### Requirement: Unknown signals never match

A condition on a signal the probe did not print, or whose value is `unknown`, SHALL be false, except an `equals` condition that names `unknown`.

#### Scenario: Snapshot count missing

- **WHEN** the probe could not read local snapshots and an entry requires `local_snapshots gte 1`
- **THEN** `match` does not list that entry

### Requirement: Initial entries

The shipped knowledge base SHALL contain at least these entries, each with evidence `unverified` until a real-Mac run verifies its fix: container nearly full (free below 10% or 50 GB), local snapshots holding deleted data, swap volume large, cache shares blocks with other files so deleting frees less than measured.

#### Scenario: Nearly full container

- **WHEN** the probe prints `container_free_pct=1`
- **THEN** `match` lists the nearly-full entry

##### Example: thresholds

| container_free_pct | container_free_gb | Nearly-full entry listed |
|---|---|---|
| 30 | 300 | no |
| 9 | 90 | yes |
| 20 | 45 | yes |

### Requirement: Candidate list kinds

`plugin/data/candidates.tsv` SHALL have three tab-separated fields per line (path, kind, reason) and its kind SHALL be one of `cache`, `download`, `build`, `personal`, `cloud-sync`, `system`. No kind SHALL authorize deleting a location without the user's decision. Lines of `~/.config/mac-disk-space/candidates.local.tsv` SHALL follow the same format; a malformed personal line SHALL be reported and skipped.

#### Scenario: A personal line with an unknown kind

- **WHEN** a personal candidate line has the kind `safe`
- **THEN** `sizes` reports the line as malformed and measures the remaining locations

### Requirement: Personal additions never hide shipped entries

A malformed `problems.local.json` SHALL be reported and left out; the shipped entries SHALL still be listed. Commands from personal entries SHALL be shown to the user before running, whatever their `class`.

#### Scenario: A broken personal knowledge base

- **WHEN** `problems.local.json` is not valid JSON
- **THEN** `list` prints every shipped entry and reports the personal file as left out
