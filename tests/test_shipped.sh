#!/bin/bash
# test_shipped — the shipped knowledge base and candidate list validate, and the
# initial entries match the threshold table of the knowledge-base spec.
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
unset DISK_SPACE_KB DISK_SPACE_CANDIDATES
export DISK_SPACE_LOCAL_KB="$TMPD/none.json" DISK_SPACE_LOCAL_CANDIDATES="$TMPD/none.tsv"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
nearly_full() { # free_pct free_gb -> yes|no
  printf 'container_free_pct=%s\ncontainer_free_gb=%s\n' "$1" "$2" > "$TMPD/s"
  if /bin/bash "$TOOL" match "$TMPD/s" | cut -f1 | grep -q '^container-nearly-full'; then echo yes; else echo no; fi
}

/bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "shipped files do not validate: $(/bin/bash "$TOOL" validate 2>&1 | tail -3)"

# threshold table (knowledge-base spec, Initial entries)
[ "$(nearly_full 30 300)" = no ]  && ok || bad "30% / 300 GB matched nearly-full"
[ "$(nearly_full 9 90)" = yes ]   && ok || bad "9% / 90 GB did not match nearly-full"
[ "$(nearly_full 20 45)" = yes ]  && ok || bad "20% / 45 GB did not match nearly-full"
[ "$(nearly_full 1 25)" = yes ]   && ok || bad "1% / 25 GB did not match nearly-full"

# purgeable data large
printf 'purgeable_gb=120\n' > "$TMPD/p"
/bin/bash "$TOOL" match "$TMPD/p" | cut -f1 | grep -qx 'purgeable-data-large' && ok || bad "purgeable_gb=120 did not match"
printf 'purgeable_gb=5\n' > "$TMPD/p"
/bin/bash "$TOOL" match "$TMPD/p" | cut -f1 | grep -qx 'purgeable-data-large' && bad "purgeable_gb=5 matched" || ok

# every shipped entry is unverified until a real-Mac run
n="$(/bin/bash "$TOOL" list | awk -F'\t' '$2!="unverified"' | wc -l | tr -d ' ')"
[ "$n" -eq 0 ] && ok || bad "$n entries are not unverified"

# the never list forbids deleting in cloud-synced folders
/bin/bash "$TOOL" show container-nearly-full-percent | grep -q '雲端' && ok || bad "never list does not mention cloud-synced folders"

echo "test_shipped: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
