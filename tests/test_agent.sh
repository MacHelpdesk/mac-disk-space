#!/bin/bash
# test_agent — static checks on the disk-space-measure subagent definition and on the
# parts of SKILL.md and README.md that depend on it. What the agent actually runs can
# only be confirmed by reading its transcript on a real Mac.
set -u
cd "$(dirname "$0")/.." || exit 2
A=plugin/agents/disk-space-measure.md
S=plugin/skills/disk-space/SKILL.md
TOOL=plugin/scripts/disk-space.sh
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

if [ ! -f "$A" ]; then
  echo "FAIL: $A does not exist"
  echo "test_agent: 0 passed, 1 failed"
  exit 1
fi

# frontmatter: the lines between the first two "---" lines
fm="$(awk '/^---$/ { n++; next } n == 1 { print }' "$A")"
field() { printf '%s\n' "$fm" | awk -v k="$1" 'index($0, k ":") == 1 { sub(/^[^:]*:[ ]*/, ""); print; exit }'; }

# spec-example: disk-space-agent / frontmatter of the shipped agent
[ "$(field name)" = "disk-space-measure" ] && ok || bad "name is '$(field name)'"
[ "$(field model)" = "sonnet" ] && ok || bad "model is '$(field model)'"
tools="$(field tools | tr -d ' ' | tr ',' '\n' | sort | tr '\n' ' ')"
[ "$tools" = "Bash Read " ] && ok || bad "tools are '$tools', want exactly Bash and Read"
for k in hooks mcpServers permissionMode; do
  [ -z "$(field "$k")" ] && ! printf '%s\n' "$fm" | grep -q "^$k:" && ok || bad "frontmatter declares $k"
done
field description | grep -q 'disk-space' && ok || bad "description does not name the disk-space skill"

# section HEADING FILE: the lines under a "## " heading up to the next "## " heading
section() { awk -v h="$1" 'index($0, h) == 1 { on = 1; next } on && /^## / { exit } on { print }' "$2"; }
# subcommands FILE-SECTION-TEXT: the set of disk-space.sh subcommands named in it
subcommands() { grep -o 'disk-space\.sh [a-z][a-z-]*' | awk '{ print $2 }' | sort -u | tr '\n' ' '; }

# spec-example: disk-space-agent / subcommands named in the agent definition
agent_cmds="$(section '## 只跑這五個指令' "$A" | subcommands)"
[ "$agent_cmds" = "match probe show sizes " ] && ok || bad "agent lists '$agent_cmds', want match probe show sizes"
for c in $agent_cmds; do
  grep -q "^  $c)" "$TOOL" && ok || bad "subcommand $c is not in $TOOL"
done
section '## 只跑這五個指令' "$A" | grep -q 'df -k /' && ok || bad "agent's list has no df -k /"
rows="$(section '## 只跑這五個指令' "$A" | grep -c '^| [0-9][0-9]* |')"
[ "$rows" = 5 ] && ok || bad "agent's command table has $rows rows, want 5"
for c in online-only candidates list validate; do
  case " $agent_cmds " in *" $c "*) bad "agent's list contains $c";; *) ok;; esac
done

# the script ships without the execute bit, so both callers must go through /bin/bash,
# and the agent must not chain commands or diagnose a failure with unlisted commands
grep -qF '/bin/bash <完整路徑> <子命令>' "$A" && ok || bad "agent does not say to run the script through /bin/bash"
grep -qF '/bin/bash <完整路徑> <子命令>' "$S" && ok || bad "skill does not say to run the script through /bin/bash"
section '## 只跑這五個指令' "$A" | grep -q '只放一個指令' && ok || bad "agent may chain commands"
section '## 只跑這五個指令' "$A" | grep -q '不要診斷' && ok || bad "agent has no rule for a failed command"

# spec-example: disk-space-agent / counts line for three rows
l1="$(grep -n '^### Signals' "$A" | head -n 1 | cut -d: -f1)"
l2="$(grep -n '^### Matched entries' "$A" | head -n 1 | cut -d: -f1)"
l3="$(grep -n '^### Candidates' "$A" | head -n 1 | cut -d: -f1)"
[ -n "$l1" ] && [ -n "$l2" ] && [ -n "$l3" ] && [ "$l1" -lt "$l2" ] && [ "$l2" -lt "$l3" ] && ok || bad "report sections missing or out of order ($l1/$l2/$l3)"
grep -qF 'sizes_rows=<n> table_rows=<n> not_measured=<n> matched=<n>' "$A" && ok || bad "no counts-line form"
grep -qF 'sizes_rows=3 table_rows=3 not_measured=1 matched=2' "$A" && ok || bad "no worked counts-line example"

# the agent never acts and never asks
no="$(section '## 不做' "$A")"
for phrase in '不清理' '不改任何設定' '不寫任何檔案' '不決定' '拒絕'; do
  printf '%s\n' "$no" | grep -q "$phrase" && ok || bad "prohibitions do not say: $phrase"
done

# spec-example: disk-space-skill / rows of the table of things done directly
direct="$(awk 'index($0, "### 直接做") == 1 { on = 1; next } on && /^### / { exit } on && /^\| [0-9]+ \|/ { print }' "$S")"
[ "$(printf '%s\n' "$direct" | grep -c .)" = 5 ] && ok || bad "table of things done directly does not have 5 rows"
printf '%s\n' "$direct" | sed -n 3p | grep -qF 'mac-disk-space:disk-space-measure' && ok || bad "row 3 of things done directly is not the dispatch"
grep -q '^### 直接做.*只有這五件' "$S" && ok || bad "heading of things done directly does not say five"

# the measuring step names the agent and the task list has one measuring task
section '## Step 1' "$S" | grep -qF 'mac-disk-space:disk-space-measure' && ok || bad "Step 1 does not name the agent"
tasks="$(section '## Step 0' "$S" | grep -c '^| [0-9][0-9]* |')"
[ "$tasks" = 4 ] && ok || bad "task table has $tasks rows, want 4"

# spec-example: disk-space-skill / count comparison
cmp="$(awk 'index($0, "### 核對列數") == 1 { on = 1; next } on && /^##/ { exit } on && /^\| / { print }' "$S")"
printf '%s\n' "$cmp" | grep -q '相同.*有.*繼續' && ok || bad "count check: no 'equal, line present, continue' case"
printf '%s\n' "$cmp" | grep -q '不同.*退回' && ok || bad "count check: no 'different, fall back' case"
printf '%s\n' "$cmp" | grep -q '沒有.*退回' && ok || bad "count check: no 'line missing, fall back' case"

# spec-example: disk-space-skill / fallback and agent command lists agree
fb="$(awk 'index($0, "### 退回自己量") == 1 { on = 1; next } on && /^## / { exit } on { print }' "$S")"
fb_cmds="$(printf '%s\n' "$fb" | subcommands)"
[ "$fb_cmds" = "$agent_cmds" ] && ok || bad "fallback lists '$fb_cmds', agent lists '$agent_cmds'"
[ "$(printf '%s\n' "$fb" | grep -c '^| [0-9][0-9]* |')" = 4 ] && ok || bad "fallback does not list exactly four cases"
grep -q '^### 退回自己量.*只有這四種' "$S" && ok || bad "fallback heading does not say four"

# the README verification table has a row for the agent with a stated status
row="$(section '## 驗證到哪裡' README.md | grep -F 'disk-space-measure' | grep '^|' | head -n 1)"
case "$row" in *已實測*|*未驗證*) ok;; *) bad "README has no verification row for the agent";; esac

echo "test_agent: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
