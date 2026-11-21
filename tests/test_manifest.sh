#!/bin/bash
# test_manifest — the plugin manifest is valid and names this tool.
set -u
cd "$(dirname "$0")/.." || exit 2
M=plugin/.claude-plugin/plugin.json
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$M" 2>/dev/null && ok || bad "$M is not valid JSON"
[ "$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$M" 2>/dev/null)" = "mac-disk-space" ] && ok || bad "manifest name is not mac-disk-space"
python3 -c "import json,sys,re; v=json.load(open(sys.argv[1]))['version']; sys.exit(0 if re.fullmatch(r'\d+\.\d+\.\d+', v) else 1)" "$M" 2>/dev/null && ok || bad "version is not X.Y.Z"
echo "test_manifest: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
