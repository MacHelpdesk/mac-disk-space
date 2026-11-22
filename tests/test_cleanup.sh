#!/bin/bash
# test_cleanup — no subcommand leaves a temporary directory behind (probe output holds
# disk identifiers; sizes output holds paths under the home directory).
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
FX=tests/fixtures
OUTER="$(mktemp -d)"
trap 'rm -rf "$OUTER"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

left() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

for sub in probe "sizes 0" list validate candidates "match"; do
  T="$OUTER/t$RANDOM"; mkdir -p "$T"
  TMPDIR="$T" DISK_SPACE_INFO_PLIST="$FX/info_root.plist" DISK_SPACE_APFS_PLIST="$FX/apfs_list.plist" \
    DISK_SPACE_SNAPSHOTS="$FX/snapshots_two.txt" DISK_SPACE_SWAP="$FX/swapusage.txt" DISK_SPACE_CAPACITY="$FX/capacity.txt" \
    DISK_SPACE_DU="$PWD/tests/stubs/du" DISK_SPACE_DATALESS="$PWD/tests/stubs/dataless" \
    DISK_SPACE_CANDIDATES="$FX/candidates_basic.tsv" DISK_SPACE_LOCAL_CANDIDATES="$OUTER/none" DISK_SPACE_LOCAL_KB="$OUTER/none.json" \
    /bin/bash "$TOOL" $sub >/dev/null 2>&1
  n="$(left "$T")"
  [ "$n" -eq 0 ] && ok || bad "$sub left $n entries in TMPDIR: $(ls "$T")"
done

# probe without overrides reads the real commands through source_file; it must clean up too
T="$OUTER/real"; mkdir -p "$T"
TMPDIR="$T" /bin/bash "$TOOL" probe >/dev/null 2>&1
n="$(left "$T")"
[ "$n" -eq 0 ] && ok || bad "real probe left $n entries in TMPDIR"

echo "test_cleanup: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
