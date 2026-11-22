#!/bin/bash
# test_kb — the knowledge base reader enforces its closed lists and never matches unknown signals.
set -u
cd "$(dirname "$0")/.." || exit 2
TOOL=plugin/scripts/disk-space.sh
FX=tests/fixtures
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export DISK_SPACE_KB="$FX/kb_basic.json"
export DISK_SPACE_LOCAL_KB="$TMPD/none.json"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
ids() { cut -f1 | sort | tr '\n' ' '; }

# Knowledge base schema and closed lists
/bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "fixture knowledge base does not validate"
sed 's/"class": "ask"/"class": "sometimes"/' "$FX/kb_basic.json" > "$TMPD/badclass.json"
DISK_SPACE_KB="$TMPD/badclass.json" /bin/bash "$TOOL" validate >/dev/null 2>&1 && bad "unknown class validated" || ok

# list prints id, status, origin, title
n="$(/bin/bash "$TOOL" list | awk -F'\t' 'NF==4 && $3=="shipped"' | wc -l | tr -d ' ')"
[ "$n" -eq 2 ] && ok || bad "list printed $n shipped lines, want 2"

# match: a condition holds
printf 'container_free_pct=1\nlocal_snapshots=3\n' > "$TMPD/s1"
got="$(/bin/bash "$TOOL" match "$TMPD/s1" | ids)"
[ "$got" = "fixture-nearly-full fixture-snapshots " ] && ok || bad "match got '$got'"

# Unknown signals never match: snapshot count absent
printf 'container_free_pct=30\n' > "$TMPD/s2"
/bin/bash "$TOOL" match "$TMPD/s2" >/dev/null; rc=$?
[ "$rc" -eq 3 ] && ok || bad "no match should exit 3, got $rc"

printf 'container_free_pct=unknown\nlocal_snapshots=unknown\n' > "$TMPD/s3"
got="$(/bin/bash "$TOOL" match "$TMPD/s3" | ids)"
[ -z "$got" ] && ok || bad "unknown values matched: $got"

# show prints the never list
/bin/bash "$TOOL" show fixture-snapshots | grep -q '任何情況都不做' && ok || bad "show has no never list"

echo "test_kb: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
