#!/bin/bash
# test_probe — probe reads container volumes, snapshots, swap and the purgeable total
# from fixtures, and reports partial results when a source is missing.
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
FX=tests/fixtures
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
expect()    { printf '%s\n' "$1" | grep -qxF "$2" && ok || bad "missing \"$2\" in: $(printf '%s' "$1" | tr '\n' ' ')"; }
expect_no() { printf '%s\n' "$1" | grep -q "^$2=" && bad "unexpected $2 in: $(printf '%s' "$1" | tr '\n' ' ')" || ok; }

run_probe() {
  DISK_SPACE_INFO_PLIST="${1:-$FX/info_root.plist}" \
  DISK_SPACE_APFS_PLIST="${2:-$FX/apfs_list.plist}" \
  DISK_SPACE_SNAPSHOTS="${3:-$FX/snapshots_two.txt}" \
  DISK_SPACE_SWAP="${4:-$FX/swapusage.txt}" \
  DISK_SPACE_CAPACITY="${5:-$FX/capacity.txt}" \
  /bin/bash "$TOOL" probe
}

# Example "container with a large VM volume" (probe spec)
out="$(run_probe)"
expect "$out" "container_free_pct=4"
expect "$out" "container_free_gb=40"
expect "$out" "purgeable_gb=120"
expect "$out" "volume_used_gb_Data=900"
expect "$out" "volume_used_gb_VM=40"
expect "$out" "volume_used_gb_System=15"
expect "$out" "volume_used_gb_Preboot=5"
expect "$out" "local_snapshots=2"
expect "$out" "swap_used_gb=38"
expect "$out" "probe_result=ok"
expect_no "$out" volume_used_gb_Backup     # the external container is not read

# a source cannot be read: its signals are absent, the rest are printed, partial
out="$(run_probe "" "$TMPD/missing.plist")"
expect_no "$out" container_free_pct
expect_no "$out" volume_used_gb_Data
expect "$out" "local_snapshots=2"
expect "$out" "swap_used_gb=38"
expect "$out" "probe_result=partial"

out="$(run_probe "" "" "" "$TMPD/missing.txt")"
expect_no "$out" swap_used_gb
expect "$out" "probe_result=partial"

# no snapshots at all is a real zero, not a failure
printf 'Snapshot dates for disk /:\n' > "$TMPD/none.txt"
out="$(run_probe "" "" "$TMPD/none.txt")"
expect "$out" "local_snapshots=0"
expect "$out" "probe_result=ok"

# probe output never carries process arguments (Other processes' command lines are never printed)
printf '%s\n' "$out" | grep -Eqv '^[a-z_A-Z]+=[A-Za-z0-9.]*$' && bad "probe printed a line that is not signal=value: $out" || ok

echo "test_probe: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
