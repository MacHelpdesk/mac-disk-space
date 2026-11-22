#!/bin/bash
# test_online_only — online-only accepts only paths inside the verified roots (iCloud
# Drive, Dropbox), skips files already online-only, and reports what it did.
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
H="$(cd "$TMPD" && pwd -P)/home"
ICLOUD="$H/Library/Mobile Documents/com~apple~CloudDocs"
DROPBOX="$H/Library/CloudStorage/Dropbox"
mkdir -p "$ICLOUD/Notes" "$DROPBOX/Big" "$H/Library/CloudStorage/OneDrive-Personal/x" "$H/Documents"
echo a > "$ICLOUD/Notes/a.txt"; echo b > "$ICLOUD/Notes/b.txt"
echo c > "$DROPBOX/Big/c.bin"; echo d > "$DROPBOX/Big/fails.bin"
echo o > "$H/Library/CloudStorage/OneDrive-Personal/x/o.txt"; echo m > "$H/Documents/mine.txt"
ln -s "$H/Documents" "$DROPBOX/escape"
export HOME="$H" DISK_SPACE_EVICT="$PWD/tests/stubs/evict" EVICT_LOG="$TMPD/evicted"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

out="$(/bin/bash "$TOOL" online-only "$ICLOUD/Notes")"; rc=$?
[ "$rc" -eq 0 ] && ok || bad "iCloud folder: exit $rc"
printf '%s\n' "$out" | grep -qx 'online_only_done=2' && ok || bad "iCloud folder: $out"
grep -c . "$EVICT_LOG" | grep -qx 2 && ok || bad "iCloud: evict called $(grep -c . "$EVICT_LOG") times"

: > "$EVICT_LOG"
out="$(/bin/bash "$TOOL" online-only "$DROPBOX/Big")"; rc=$?
printf '%s\n' "$out" | grep -qx 'online_only_done=1' && ok || bad "Dropbox done: $out"
printf '%s\n' "$out" | grep -qx 'online_only_failed=1' && ok || bad "Dropbox failed count: $out"
[ "$rc" -eq 2 ] && ok || bad "a failed file should exit 2, got $rc"

# refused: outside the verified roots, a root that is not verified, and a symlink escape
for p in "$H/Documents" "$H/Library/CloudStorage/OneDrive-Personal/x" "$DROPBOX/escape" "$H/Library/CloudStorage" "/tmp"; do
  : > "$EVICT_LOG"
  /bin/bash "$TOOL" online-only "$p" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 64 ] && ok || bad "$p was not refused (exit $rc)"
  [ ! -s "$EVICT_LOG" ] && ok || bad "$p reached evict"
done

# files already online-only are skipped (DISK_SPACE_DATALESS_TEST marks paths as dataless)
: > "$EVICT_LOG"
out="$(DISK_SPACE_DATALESS_TEST="a.txt" /bin/bash "$TOOL" online-only "$ICLOUD/Notes")"
printf '%s\n' "$out" | grep -qx 'online_only_skipped=1' && ok || bad "dataless file not skipped: $out"
grep -c . "$EVICT_LOG" | grep -qx 1 && ok || bad "a dataless file reached evict"

echo "test_online_only: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
