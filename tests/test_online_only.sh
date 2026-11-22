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

# evict fails as a whole (prints nothing, exits 1): every listed file counts as failed
printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' > "$TMPD/evict_dead"; chmod +x "$TMPD/evict_dead"
out="$(DISK_SPACE_EVICT="$TMPD/evict_dead" /bin/bash "$TOOL" online-only "$ICLOUD/Notes")"; rc=$?
printf '%s\n' "$out" | grep -qx 'online_only_failed=2' && ok || bad "a dead evict reported: $out"
printf '%s\n' "$out" | grep -qx 'online_only_done=0' && ok || bad "a dead evict reported done: $out"
[ "$rc" -eq 2 ] && ok || bad "a dead evict should exit 2, got $rc"

# evict reports only some files and exits 0: the missing ones count as failed
printf '#!/bin/bash\nIFS= read -r first\necho "ok $first"\ncat >/dev/null\n' > "$TMPD/evict_short"; chmod +x "$TMPD/evict_short"
out="$(DISK_SPACE_EVICT="$TMPD/evict_short" /bin/bash "$TOOL" online-only "$ICLOUD/Notes")"; rc=$?
printf '%s\n' "$out" | grep -qx 'online_only_done=1' && ok || bad "short evict done: $out"
printf '%s\n' "$out" | grep -qx 'online_only_failed=1' && ok || bad "short evict: unreported file not counted: $out"
[ "$rc" -eq 2 ] && ok || bad "short evict should exit 2, got $rc"

# evict reports the same file twice and another not at all: done counts files, not lines
printf '#!/bin/bash\nIFS= read -r first\necho "ok $first"\necho "ok $first"\ncat >/dev/null\n' > "$TMPD/evict_dup"; chmod +x "$TMPD/evict_dup"
out="$(DISK_SPACE_EVICT="$TMPD/evict_dup" /bin/bash "$TOOL" online-only "$ICLOUD/Notes")"; rc=$?
printf '%s\n' "$out" | grep -qx 'online_only_done=1' && ok || bad "a repeated ok counted twice: $out"
printf '%s\n' "$out" | grep -qx 'online_only_failed=1' && ok || bad "the unreported file was not failed: $out"
[ "$rc" -eq 2 ] && ok || bad "duplicate-ok run should exit 2, got $rc"

# an ok for a path that was not listed does not count
printf '#!/bin/bash\ncat >/dev/null\necho "ok /somewhere/else"\n' > "$TMPD/evict_other"; chmod +x "$TMPD/evict_other"
out="$(DISK_SPACE_EVICT="$TMPD/evict_other" /bin/bash "$TOOL" online-only "$ICLOUD/Notes")"
printf '%s\n' "$out" | grep -qx 'online_only_done=0' && ok || bad "an ok for an unlisted path counted: $out"

# a large folder is listed by find, not one stat per file
mkdir -p "$DROPBOX/many"; i=0; while [ $i -lt 2000 ]; do : > "$DROPBOX/many/f$i"; i=$((i+1)); done
s0=$SECONDS
out="$(/bin/bash "$TOOL" online-only "$DROPBOX/many")"
took=$((SECONDS - s0))
printf '%s\n' "$out" | grep -qx 'online_only_done=2000' && ok || bad "2000 files: $out"
[ "$took" -le 4 ] && ok || bad "2000 files took ${took}s"

# Dropbox-* (a second Dropbox account) is a verified root; a lookalike name is not
mkdir -p "$H/Library/CloudStorage/Dropbox-Team/t" "$H/Library/CloudStorage/DropboxOld/t"
echo t > "$H/Library/CloudStorage/Dropbox-Team/t/x"; echo t > "$H/Library/CloudStorage/DropboxOld/t/x"
out="$(/bin/bash "$TOOL" online-only "$H/Library/CloudStorage/Dropbox-Team/t")"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx 'online_only_done=1' && ok || bad "Dropbox-Team: exit $rc, $out"
: > "$EVICT_LOG"
/bin/bash "$TOOL" online-only "$H/Library/CloudStorage/DropboxOld/t" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && ok || bad "DropboxOld should be refused with 64, got $rc"
[ -s "$EVICT_LOG" ] && bad "a file under DropboxOld reached evict" || ok

# stopped part-way: the files already reported count as done, the rest as failed, and the
# counts are still printed; the evict step is stopped with it
SLP="27.$$"
printf '#!/bin/bash\nIFS= read -r first\necho "ok $first"\nexec sleep %s\n' "$SLP" > "$TMPD/evict_hang"; chmod +x "$TMPD/evict_hang"
DISK_SPACE_EVICT="$TMPD/evict_hang" /bin/bash "$TOOL" online-only "$ICLOUD/Notes" > "$TMPD/stopped.out" 2>/dev/null &
OP=$!
sleep 1
s0=$SECONDS; kill -TERM "$OP"; wait "$OP"; rc=$?; took=$((SECONDS - s0))
grep -qx 'online_only_done=1' "$TMPD/stopped.out" && ok || bad "stopped run lost its done count: $(cat "$TMPD/stopped.out")"
grep -qx 'online_only_failed=1' "$TMPD/stopped.out" && ok || bad "stopped run: the unreported file is not failed: $(cat "$TMPD/stopped.out")"
[ "$rc" -eq 143 ] && ok || bad "stopped run should exit 143, got $rc"
[ "$took" -le 3 ] && ok || bad "stopping took ${took}s"
ps -ax -o command= | grep -qxF "sleep $SLP" && bad "the evict step is still running" || ok

echo "test_online_only: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
