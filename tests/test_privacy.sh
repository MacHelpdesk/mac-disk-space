#!/bin/bash
# test_privacy — scripts/check-privacy.sh fails on each kind of personal detail it checks
# and passes on the allowed placeholders. Runs the script inside a throwaway git repo.
set -u
cd "$(dirname "$0")/.." || exit 2
SCRIPT="$PWD/scripts/check-privacy.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# check TEXT: run check-privacy.sh in a fresh repo whose only file holds TEXT; print its exit status
check() {
  local r="$TMPD/r$RANDOM$RANDOM"
  mkdir -p "$r/scripts" && cp "$SCRIPT" "$r/scripts/"
  printf '%s\n' "$1" > "$r/file.txt"
  (cd "$r" && git init -q && git add -A) || return 99
  /bin/bash "$r/scripts/check-privacy.sh" >/dev/null 2>&1
  echo $?
}

# The samples are built from pieces so that this file itself holds no value the check flags.
U="us""er"; AT="@"; IP="192.168"".1.20"; ID="12345678-1234""-1234-1234-123456789abc"
for text in "created_by: someone <$U${AT}gmail.com>" "mail me at a.b-c${AT}mail.example-isp.tw" "ip $IP" "/Users/$U/Documents/x" "id $ID"; do
  [ "$(check "$text")" = 1 ] && ok || bad "not flagged: $text"
done
[ "$(check "a $U${AT}example.com and b $U${AT}gmail.com")" = 1 ] && ok || bad "an example address hid a real one on the same line"
for text in "contact $U${AT}example.com" "x${AT}sub.example.org" "y${AT}example.net" "ip 192.0.2.10" "/Users/Shared/x" "id 00000000-0000-0000-0000-000000000000" "Refs #9 @ 3 GB" "user${AT}localhost"; do
  [ "$(check "$text")" = 0 ] && ok || bad "flagged an allowed value: $text"
done

echo "test_privacy: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
