#!/bin/bash
# test_sizes — sizes measures only listed locations, within time limits, reports
# cloud-synced locations by local footprint and online-only share, and escapes paths.
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
H="$TMPD/home"; mkdir -p "$H"
export HOME="$H" DISK_SPACE_DU="$PWD/tests/stubs/du" DISK_SPACE_DATALESS="$PWD/tests/stubs/dataless"
export DISK_SPACE_LOCAL_CANDIDATES="$TMPD/none.tsv"
export DISK_SPACE_LOCATION_LIMIT=2 DISK_SPACE_RUN_LIMIT=20   # test limits; defaults are 60 and 300

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
row() { printf '%s\n' "$out" | awk -F'\t' -v p="$1" '$3==p'; }

GiB_KB=976563   # just over 1 GB (10^9 bytes) in KiB
mkdir -p "$H/.cache/uv" "$H/slowdir" "$H/cloud" "$TMPD/shared/Alpha Library" "$TMPD/shared/\$(x) Library" "$H/unlisted"
echo $((24 * GiB_KB)) > "$H/.cache/uv/.size"
echo $((10 * GiB_KB)) > "$H/cloud/.size"
printf '30000000000\n20000000000\n' > "$H/cloud/.dataless"
echo $((3 * GiB_KB)) > "$TMPD/shared/Alpha Library/.size"
echo $((2 * GiB_KB)) > "$TMPD/shared/\$(x) Library/.size"
echo $((99 * GiB_KB)) > "$H/unlisted/.size"
T=$'\t'
cat > "$TMPD/c.tsv" <<TSV
~/.cache/uv${T}cache${T}uv cache prune${T}uv cache
~/slowdir${T}personal${T}${T}slow folder
~/cloud${T}cloud-sync${T}${T}synced folder
$TMPD/shared/* Library${T}download${T}${T}sample libraries
~/missing${T}cache${T}${T}not there
TSV
export DISK_SPACE_CANDIDATES="$TMPD/c.tsv"

start=$(date +%s)
out="$(/bin/bash "$TOOL" sizes 0)"
elapsed=$(( $(date +%s) - start ))

# Candidate sizes have time limits
[ "$(row "$H/.cache/uv" | cut -f1)" = 24 ] && ok || bad "uv row: $(row "$H/.cache/uv")"
[ "$(row "$H/.cache/uv" | cut -f4)" = "uv cache prune" ] && ok || bad "uv command missing"
[ "$(row "$H/.cache/uv" | cut -f6)" = shipped ] && ok || bad "uv origin missing"
[ "$(row "$H/slowdir" | cut -f1)" = not-measured ] && ok || bad "slow row: $(row "$H/slowdir")"
[ "$elapsed" -lt 15 ] && ok || bad "a slow location blocked the run (${elapsed}s)"
printf '%s\n' "$out" | grep -q "$H/unlisted" && bad "an unlisted folder was measured" || ok
printf '%s\n' "$out" | grep -q "$H/missing" && bad "a missing location was printed" || ok

# Cloud-synced locations report local footprint only
[ "$(row "$H/cloud" | cut -f1)" = 10 ] && ok || bad "cloud footprint: $(row "$H/cloud")"
[ "$(row "$H/cloud" | cut -f7)" = 50 ] && ok || bad "cloud online-only share: $(row "$H/cloud")"
[ -z "$(row "$H/.cache/uv" | cut -f7)" ] && ok || bad "a non-cloud row has an online-only share"

# Unsafe paths are escaped (raw path measured, escaped on output)
[ "$(row "$TMPD/shared/Alpha Library" | cut -f2)" = download ] && ok || bad "Alpha Library: $(row "$TMPD/shared/Alpha Library")"
n="$(printf '%s\n' "$out" | awk -F'\t' '$2 ~ /^unsafe_/' | wc -l | tr -d ' ')"
[ "$n" -eq 1 ] && ok || bad "want one unsafe row, got $n"
printf '%s\n' "$out" | grep -qF '$(x) Library' && bad "metacharacter path printed unescaped" || ok
[ "$(printf '%s\n' "$out" | awk -F'\t' '$2 ~ /^unsafe_/' | cut -f1)" = 2 ] && ok || bad "unsafe row was not measured by its raw path"

# MIN_GB drops small measured rows, never not-measured rows
out="$(/bin/bash "$TOOL" sizes 20)"
[ -n "$(row "$H/.cache/uv")" ] && ok || bad "24 GB row dropped at MIN_GB 20"
[ -z "$(row "$H/cloud")" ] && ok || bad "10 GB row kept at MIN_GB 20"
[ "$(row "$H/slowdir" | cut -f1)" = not-measured ] && ok || bad "not-measured row dropped by MIN_GB"

# the run limit: with a 1-second run limit, later locations are not-measured
out="$(DISK_SPACE_RUN_LIMIT=1 DISK_SPACE_LOCATION_LIMIT=1 /bin/bash "$TOOL" sizes 0)"
n="$(printf '%s\n' "$out" | awk -F'\t' '$1=="not-measured"' | wc -l | tr -d ' ')"
[ "$n" -ge 2 ] && ok || bad "run limit did not mark later rows not-measured: $out"

# a malformed personal line is reported on stderr and skipped; the rest are measured
printf '~/.cache/uv\tsafe\t\tbad kind\n' > "$TMPD/local.tsv"
out="$(DISK_SPACE_LOCAL_CANDIDATES="$TMPD/local.tsv" /bin/bash "$TOOL" sizes 0 2>"$TMPD/err")"
grep -q 'malformed' "$TMPD/err" && ok || bad "malformed personal line not reported by sizes"
[ -n "$(row "$H/.cache/uv")" ] && ok || bad "shipped rows dropped by a malformed personal line"
grep -q 'Terminated' "$TMPD/err" && bad "job-control noise on stderr" || ok

# a row with an empty command keeps its fields: command empty, reason in field 5
out="$(/bin/bash "$TOOL" sizes 0 2>/dev/null)"
[ -z "$(row "$H/cloud" | cut -f4)" ] && ok || bad "empty command shifted: field 4 is '$(row "$H/cloud" | cut -f4)'"
[ "$(row "$H/cloud" | cut -f5)" = "synced folder" ] && ok || bad "reason lost: field 5 is '$(row "$H/cloud" | cut -f5)'"
[ "$(row "$H/cloud" | cut -f6)" = shipped ] && ok || bad "origin shifted: field 6 is '$(row "$H/cloud" | cut -f6)'"
[ "$(row "$H/.cache/uv" | cut -f5)" = "uv cache" ] && ok || bad "reason of a row with a command: '$(row "$H/.cache/uv" | cut -f5)'"

# du fails (permission denied) -> not-measured, never the partial number
mkdir -p "$H/denied"
printf '~/denied\tpersonal\t\tunreadable\n' > "$TMPD/c_denied.tsv"
out="$(DISK_SPACE_CANDIDATES="$TMPD/c_denied.tsv" /bin/bash "$TOOL" sizes 0 2>/dev/null)"
[ "$(row "$H/denied" | cut -f1)" = not-measured ] && ok || bad "a failed du was reported as a size: $(row "$H/denied")"

# a cloud-sync location shares one budget between du and the online-only scan, and the
# stopped scan leaves no process behind
mkdir -p "$H/lagcloud"; echo $((6 * GiB_KB)) > "$H/lagcloud/.size"
printf '~/lagcloud\tcloud-sync\t\tsynced\n' > "$TMPD/c_cloud.tsv"
s0=$SECONDS
out="$(DISK_SPACE_CANDIDATES="$TMPD/c_cloud.tsv" DISK_SPACE_LOCATION_LIMIT=2 /bin/bash "$TOOL" sizes 0 2>/dev/null)"
took=$((SECONDS - s0))
[ "$(row "$H/lagcloud" | cut -f7)" = not-measured ] && ok || bad "slow online-only scan: $(row "$H/lagcloud")"
[ "$took" -le 5 ] && ok || bad "one cloud location took ${took}s with a 2 s limit"
sleep 1
# match the exact command line: pgrep -f would also match any shell whose command text
# merely mentions it
ps -ax -o command= | grep -qx 'sleep 31' && bad "the stopped online-only scan is still running" || ok

# fast locations do not each cost a whole polling second
mkdir -p "$H/f1" "$H/f2" "$H/f3" "$H/f4" "$H/f5" "$H/f6"
: > "$TMPD/c_fast.tsv"; for i in 1 2 3 4 5 6; do printf '~/f%s\tcache\t\tfast %s\n' "$i" "$i" >> "$TMPD/c_fast.tsv"; done
s0=$SECONDS
DISK_SPACE_CANDIDATES="$TMPD/c_fast.tsv" /bin/bash "$TOOL" sizes 0 >/dev/null 2>&1
took=$((SECONDS - s0))
[ "$took" -le 3 ] && ok || bad "six instant locations took ${took}s"

echo "test_sizes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
