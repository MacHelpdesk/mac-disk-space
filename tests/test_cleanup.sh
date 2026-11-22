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

# probe without overrides runs commands through source_file, which writes their output
# into the temporary directory; it must clean up too. Stand-in commands on PATH print the
# fixtures, so this does not read this Mac's disks.
B="$OUTER/bin"; mkdir -p "$B"
FXA="$PWD/$FX"
printf '#!/bin/bash\ncase "$1" in info) cat "%s/info_root.plist" ;; apfs) cat "%s/apfs_list.plist" ;; esac\n' "$FXA" "$FXA" > "$B/diskutil"
printf '#!/bin/bash\ncat "%s/capacity.txt"\n' "$FXA" > "$B/osascript"
printf '#!/bin/bash\ncat "%s/snapshots_two.txt"\n' "$FXA" > "$B/tmutil"
printf '#!/bin/bash\ncat "%s/swapusage.txt"\n' "$FXA" > "$B/sysctl"
chmod +x "$B"/*
T="$OUTER/cmd"; mkdir -p "$T"
out="$(PATH="$B:$PATH" TMPDIR="$T" /bin/bash "$TOOL" probe 2>/dev/null)"
printf '%s\n' "$out" | grep -qx 'probe_result=ok' && ok || bad "probe through stand-in commands: $out"
n="$(left "$T")"
[ "$n" -eq 0 ] && ok || bad "probe through commands left $n entries in TMPDIR"

echo "test_cleanup: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
