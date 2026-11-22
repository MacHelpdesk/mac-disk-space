## Purpose

`disk-space.sh online-only PATH`, the only subcommand that changes the system: it makes the downloaded files under a cloud-synced folder online-only, so that their local copies stop taking space while the cloud copies stay. It exists because deleting a file in a synced folder deletes it in the cloud too, and making it online-only is the one safe way to get that space back.

## ADDED Requirements

### Requirement: Online-only is confined to verified locations

`online-only` SHALL accept a path only when, after every symlink in it is resolved, it lies inside iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs`) or a Dropbox folder (`~/Library/CloudStorage/Dropbox` or `~/Library/CloudStorage/Dropbox-*`): the services whose mechanism was verified. Every other path SHALL be refused with exit status 64 before any file is touched. This list of locations is closed; adding a service requires a verified test of its mechanism on a real Mac first.

#### Scenario: A path outside the verified locations

- **WHEN** `online-only` is given a folder in the home directory outside both locations
- **THEN** it exits 64 and no file reaches the evict step

##### Example: refused paths

| Path | Result |
|---|---|
| `~/Documents` | refused, 64 |
| a OneDrive folder under `~/Library/CloudStorage` | refused, 64 |
| `~/Library/CloudStorage` itself | refused, 64 |
| a symlink inside Dropbox pointing to `~/Documents` | refused, 64 |
| a folder inside iCloud Drive | accepted |

### Requirement: Only downloaded files are evicted

`online-only` SHALL pass to the evict step only regular files that do not already have the `dataless` flag, found without following symlinks, and SHALL count files already online-only as skipped. It SHALL print `online_only_done`, `online_only_failed` and `online_only_skipped`.

#### Scenario: A folder with one file already online-only

- **WHEN** a folder holds two files and one of them is already online-only
- **THEN** one file reaches the evict step and `online_only_skipped=1` is printed

### Requirement: Unconfirmed files count as failed

A file SHALL count as done only when the evict step reported it as done. A file reported as failed, and a file the evict step did not report on at all (it crashed, was stopped, or printed nothing), SHALL count as failed. When any file failed, `online-only` SHALL exit with status 2.

#### Scenario: The evict step fails as a whole

- **WHEN** the evict step exits with an error and prints nothing for two listed files
- **THEN** `online-only` prints `online_only_done=0` and `online_only_failed=2` and exits 2
