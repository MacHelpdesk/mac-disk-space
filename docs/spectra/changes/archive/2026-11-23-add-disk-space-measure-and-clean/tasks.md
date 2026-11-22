## 1. Spikes

- [x] 1.1 Spike before specifying snapshot reserve and online-only mechanisms, part one: on a real Mac, find whether the space held by Time Machine local snapshots can be read before deleting them (APFS snapshot properties, `tmutil`, `diskutil apfs listSnapshots -plist`). Verified by a record in the change's design.md Open Questions with the commands tried, the macOS version and the result; if no source gives it, the probe keeps reporting `cannot-estimate`.
- [x] 1.2 Spike, part two: for iCloud Drive and File Provider services (Dropbox, OneDrive, Google Drive), find a command that makes a downloaded file online-only and confirm it on a test file by its `dataless` flag. Verified by a record per service (command, macOS version, result: verified or not found); only verified mechanisms may appear in "Things the skill asks first".

## 2. Knowledge base and candidate list

- [x] 2.1 Copy kb.js from mac-timemachine-fix instead of sharing code: `disk-space.sh` gains `list`, `show`, `match`, `validate` backed by a copied `plugin/scripts/kb.js`, enforcing Knowledge base schema and closed lists and Unknown signals never match. Verified by `tests/test_kb.sh` (unknown class rejected, absent signal not matched, `match` exit 3 on no match).
- [x] 2.2 Write the Initial entries of `plugin/data/problems.json` (container nearly full with the 10% / 50 GB thresholds, local snapshots holding deleted data, purgeable data large, swap volume large, cache shares blocks), all `unverified`, with the `never` list from the skill spec. Verified by `validate` and by `tests/test_kb.sh` matching the threshold table of the knowledge-base spec. [after: 2.1]
- [x] 2.3 Write `plugin/data/candidates.tsv` with the Candidate list kinds (`cache`, `download`, `build`, `personal`, `cloud-sync`, `system`) with four fields (path, kind, command, reason) because Candidate rows carry their cleaning command, and an empty command for `personal`, `cloud-sync` and `system`, so that the Candidate list decides where to measure, never what to delete; start from the candidate list of mac-timemachine-fix, move cloud folders to `cloud-sync`, and add package-manager caches, downloaded models, Xcode simulators and DerivedData, Docker. Verified by `tests/test_kb.sh` rejecting a malformed line, an unknown kind and a `cloud-sync` line with a command.
- [x] 2.4 Personal additions never hide shipped entries: malformed `problems.local.json` and malformed `candidates.local.tsv` lines are reported and skipped. Verified by `tests/test_kb.sh` with a broken personal file still listing every shipped entry. [after: 2.1]

## 3. Probe and sizes

- [x] 3.1 `disk-space.sh probe` so that the Probe reports container-level signals, including `purgeable_gb` from the two volume capacity keys, from `diskutil apfs list -plist`, `df -k`, `tmutil listlocalsnapshotdates /` and `sysctl -n vm.swapusage`, with `probe_result=partial` when a source fails; every input has a `DISK_SPACE_*` override. Verified by `tests/test_probe.sh` with fixtures, including the example container of the probe spec.
- [x] 3.2 `disk-space.sh sizes` so that Candidate sizes have time limits: Time limits per location and per run of 60 s and 300 s, `not-measured` rows never counted, only listed locations scanned, bash 3.2 without `timeout`. Verified by `tests/test_sizes.sh` with a stub `du` that sleeps past the limit. [after: 2.3]
- [x] 3.3 Cloud-synced locations report local footprint only: for `cloud-sync` rows, report on-Mac size and online-only share by the `dataless` flag, following Cloud-synced folders are a separate kind with online-only as the only action. Verified by `tests/test_sizes.sh` with a stub `stat` reporting dataless files. [after: 3.2]
- [x] 3.4 Unsafe paths are escaped and Other processes' command lines are never printed: reuse the `emit` approach of mac-timemachine-fix, and add a test that greps all subcommand output for argument strings of a fixture process. Verified by `tests/test_sizes.sh` (a `$(x) Library` folder) and `tests/test_probe.sh`. [after: 3.2]

## 4. Skill

- [x] 4.1 Write `plugin/skills/disk-space/SKILL.md`: One row per candidate, Act only on rows the user names with `df -k` before and after, and the four closed tables Things the skill does directly, Things the skill asks first, Things left to the user, Things the skill never does; Clearing local snapshots belongs to this tool through a Terminal window. Verified by a content review against the skill spec, table by table, and by `claude plugin validate plugin`. [after: 1.1, 1.2, 2.2, 3.4]

- [x] 4.2 `disk-space.sh online-only PATH`, written with task 4.1 and specified after verification: Online-only is confined to verified locations (iCloud Drive and Dropbox, after resolving symlinks; exit 64 otherwise), Only downloaded files are evicted (dataless files are skipped), and Unconfirmed files count as failed (a file `evict.js` did not report on is failed; exit 2). Verified by `tests/test_online_only.sh`. [after: 1.2]

## 5. Release

- [x] 5.1 Run the skill once on a real Mac, record the run under `~/.config/mac-disk-space/records/`, and fill the verification tables of README.md and SKILL.md with what was measured and on which macOS version; bump `plugin/.claude-plugin/plugin.json` to 0.1.0 and update CHANGELOG.md and CLAUDE.md. Verified by `scripts/check-privacy.sh`, all tests, and CI on the pull request. [after: 4.1]
- [x] 5.2 Open the follow-ups outside this repository: an issue in MacHelpdesk/mac-helpdesk to add the plugin to the marketplace index, and an issue in MacHelpdesk/mac-timemachine-fix to point `source-disk-nearly-full` to this tool. Verified by the two issue URLs recorded in MacHelpdesk/mac-helpdesk#9. [after: 5.1]
