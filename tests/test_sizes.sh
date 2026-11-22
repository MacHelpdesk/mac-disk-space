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

echo "test_sizes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
