#!/bin/bash
# test_skill — static checks that keep SKILL.md, the knowledge base, the candidate list
# and the script's defaults from drifting apart.
set -u
cd "$(dirname "$0")/.." || exit 2
S=plugin/skills/disk-space/SKILL.md
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# table_rows HEADING: number of numbered rows ("| <n> |") in the table under HEADING
table_rows() {
  awk -v h="$1" 'index($0, h) == 1 { on = 1; next } on && /^### / { exit } on && /^\| [0-9]+ \|/ { n++ } END { print n + 0 }' "$S"
}
# heading_count PREFIX: the number written in the heading ("只有這四件" -> 4)
heading_count() {
  case "$(grep -m1 "^$1" "$S")" in *只有這一件*) echo 1;; *只有這二件*|*只有這兩件*) echo 2;; *只有這三件*) echo 3;; *只有這四件*) echo 4;; *只有這五件*) echo 5;; *只有這六件*) echo 6;; *) echo "?";; esac
}

for h in "### 直接做" "### 先問" "### 只說明步驟"; do
  rows="$(table_rows "$h")"; want="$(heading_count "$h")"
  [ "$rows" = "$want" ] && ok || bad "$h: heading says $want, table has $rows rows"
done

# the never list in SKILL.md and in problems.json have the same number of items
never_kb="$(plutil -extract never raw -o - plugin/data/problems.json 2>/dev/null)"
never_skill="$(awk '/^### 不做/ { on = 1; next } on && /^## / { exit } on && /^- 不/ { n++ } END { print n + 0 }' "$S")"
[ "$never_kb" = "$never_skill" ] && ok || bad "never list: problems.json has $never_kb, SKILL.md has $never_skill"
grep -q "一共${never_kb}項\|一共五項" "$S" && ok || bad "SKILL.md does not state the never count"

# the default time limits are the ones the spec names
grep -qF 'LOCATION_LIMIT="${DISK_SPACE_LOCATION_LIMIT:-60}"' plugin/scripts/disk-space.sh && ok || bad "default location limit is not 60"
grep -qF 'RUN_LIMIT="${DISK_SPACE_RUN_LIMIT:-300}"' plugin/scripts/disk-space.sh && ok || bad "default run limit is not 300"

# cloud-synced folders are listed per service, so each row maps to one boundary table
awk -F'\t' '$1 == "~/Library/CloudStorage"' plugin/data/candidates.tsv | grep -q . && bad "CloudStorage is listed as one row" || ok
awk -F'\t' '$2 == "cloud-sync" && $1 ~ /Dropbox/' plugin/data/candidates.tsv | grep -q . && ok || bad "no Dropbox row"

# every kind that can lack a command has a row in the boundary tables for that case
grep -q '指令欄是空的列' "$S" && ok || bad "no rule for cache/download/build rows without a command"

echo "test_skill: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
