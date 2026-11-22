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
[ "$n" -eq 3 ] && ok || bad "list printed $n shipped lines, want 3"

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
[ "$got" = "fixture-snapshots-unknown " ] && ok || bad "unknown values: only the equals-unknown entry may match, got '$got'"

# the equals-unknown exception needs the signal to be present
printf 'container_free_pct=30\n' > "$TMPD/s4"
got="$(/bin/bash "$TOOL" match "$TMPD/s4" | ids)"
[ -z "$got" ] && ok || bad "an absent signal matched equals-unknown: $got"

# validate rejects an unknown operator, evidence status and signal
for pair in 's/"op": "lte"/"op": "between"/' 's/"evidence": "unverified"/"evidence": "probably"/' 's/"signal": "container_free_pct"/"signal": "no_such_signal"/'; do
  sed "$pair" "$FX/kb_basic.json" > "$TMPD/bad.json"
  cmp -s "$FX/kb_basic.json" "$TMPD/bad.json" && { bad "sed did not change the fixture: $pair"; continue; }
  DISK_SPACE_KB="$TMPD/bad.json" /bin/bash "$TOOL" validate >/dev/null 2>&1 && bad "validated after: $pair" || ok
done

# show prints the never list
/bin/bash "$TOOL" show fixture-snapshots | grep -q '任何情況都不做' && ok || bad "show has no never list"


# ---- candidates.tsv (Candidate list kinds; Candidate rows carry their cleaning command)
export DISK_SPACE_CANDIDATES="$FX/candidates_basic.tsv"
export DISK_SPACE_LOCAL_CANDIDATES="$TMPD/none.tsv"
/bin/bash "$TOOL" validate >/dev/null 2>&1 && ok || bad "fixture candidates do not validate"

printf '~/x\tsafe\t\tunknown kind\n' > "$TMPD/c_kind.tsv"
DISK_SPACE_CANDIDATES="$TMPD/c_kind.tsv" /bin/bash "$TOOL" validate >/dev/null 2>&1 && bad "unknown kind validated" || ok

printf '~/x\tcache\tonly three fields\n' > "$TMPD/c_fields.tsv"
DISK_SPACE_CANDIDATES="$TMPD/c_fields.tsv" /bin/bash "$TOOL" validate >/dev/null 2>&1 && bad "three-field line validated" || ok

for k in cloud-sync personal system; do
  printf '~/x\t%s\trm -rf ~/x\twith a command\n' "$k" > "$TMPD/c_cmd.tsv"
  DISK_SPACE_CANDIDATES="$TMPD/c_cmd.tsv" /bin/bash "$TOOL" validate >/dev/null 2>&1 && bad "$k line with a command validated" || ok
done

# ---- Personal additions never hide shipped entries
printf '{ not json' > "$TMPD/broken.json"
n="$(DISK_SPACE_LOCAL_KB="$TMPD/broken.json" /bin/bash "$TOOL" list 2>/dev/null | awk -F'\t' '$3=="shipped"' | wc -l | tr -d ' ')"
[ "$n" -eq 3 ] && ok || bad "broken personal kb hid shipped entries ($n listed)"
DISK_SPACE_LOCAL_KB="$TMPD/broken.json" /bin/bash "$TOOL" list 2>&1 >/dev/null | grep -q 'left out' && ok || bad "broken personal kb not reported"

printf '~/mine\tcache\t\tmy cache\n~/bad\tsafe\t\tbad kind\n' > "$TMPD/local.tsv"
out="$(DISK_SPACE_LOCAL_CANDIDATES="$TMPD/local.tsv" /bin/bash "$TOOL" candidates 2>"$TMPD/err")"
printf '%s\n' "$out" | grep -q '	~/mine	' && ok || bad "valid personal candidate dropped: $out"
printf '%s\n' "$out" | grep -q 'bad' && bad "malformed personal candidate kept" || ok
grep -q 'malformed' "$TMPD/err" && ok || bad "malformed personal candidate not reported"
n="$(printf '%s\n' "$out" | awk -F'\t' '$1=="shipped"' | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] && ok || bad "shipped candidates hidden by a bad personal line"

# a valid personal entry is listed as local, and show tells to ask before every command
cat > "$TMPD/local.json" <<'EOF_LOCAL'
{ "schema_version": 1, "problems": [ { "id": "my-entry", "title": "my own entry", "symptoms": ["s"],
  "match": { "all": [ { "signal": "container_free_pct", "op": "lte", "value": 5 } ] }, "cause": "c",
  "confirm": ["echo hi"],
  "fixes": [ { "id": "f", "action": "a", "class": "direct", "command": "echo fix", "evidence": "unverified" } ],
  "evidence": { "status": "unverified" } } ] }
EOF_LOCAL
DISK_SPACE_LOCAL_KB="$TMPD/local.json" /bin/bash "$TOOL" list | awk -F'\t' '$1 == "my-entry" && $3 == "local"' | grep -q . && ok || bad "personal entry not listed as local"
show="$(DISK_SPACE_LOCAL_KB="$TMPD/local.json" /bin/bash "$TOOL" show my-entry)"
printf '%s\n' "$show" | grep -q '不論 class 寫什麼' && ok || bad "show of a personal entry does not say to ask first"
printf '%s\n' "$show" | grep -q '執行前先問' && ok || bad "show of a personal entry does not mark its confirm commands"

echo "test_kb: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
