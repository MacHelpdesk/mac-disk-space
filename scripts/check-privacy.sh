#!/bin/bash
# check-privacy — fail when a tracked file contains details of someone's environment.
#
# This repo is public and its tool reads disk and volume information that names devices by
# UUID and prints paths under the home directory. None of that belongs in the repo.
# Fixtures and examples use the all-zero UUID and paths without a user name.
#
# Checked, and only these:
#   1. a full IPv4 address in a private range (10/8, 172.16/12, 192.168/16, 169.254/16)
#   2. an absolute home path (/Users/<name>/ or /home/<name>/); /Users/Shared/ is the
#      system's shared folder, not anyone's home, and is allowed
#   3. a UUID other than 00000000-0000-0000-0000-000000000000
#   4. an email address, except at the RFC 2606 example domains (example.com, example.org,
#      example.net and their subdomains). Spectra writes `created_by` and `archived_by` as
#      "name <email>" from git config into docs/spectra/changes/**/.openspec.yaml; keep the
#      name and remove the address (MacHelpdesk/mac-disk-space#9).
#
# Usage: scripts/check-privacy.sh        (from the repo root)

set -u

cd "$(dirname "$0")/.." || exit 2

PRIVATE_IP='(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|169\.254\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'
HOME_PATH='/(Users|home)/[A-Za-z0-9._-]+/'
UUID='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
ZERO_UUID='00000000-0000-0000-0000-000000000000'
EMAIL='[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}'
EXAMPLE_EMAIL='@([A-Za-z0-9-]+\.)*example\.(com|org|net)([^A-Za-z0-9.-]|$)'

found=0
report() { # label pattern
  local hits
  hits="$(git grep -n -I -E "$2" -- . ':(exclude)scripts/check-privacy.sh' 2>/dev/null)"
  if [ -n "$hits" ]; then
    printf '%s:\n%s\n\n' "$1" "$hits"
    found=1
  fi
}

report "private IPv4 address" "$PRIVATE_IP"
homes="$(git grep -n -I -E "$HOME_PATH" -- . ':(exclude)scripts/check-privacy.sh' 2>/dev/null | grep -vE '/Users/Shared/')"
if [ -n "$homes" ]; then
  printf 'absolute home path:\n%s\n\n' "$homes"
  found=1
fi

uuids="$(git grep -n -I -E "$UUID" -- . ':(exclude)scripts/check-privacy.sh' 2>/dev/null | sed "s/$ZERO_UUID//g" | grep -E "$UUID")"
if [ -n "$uuids" ]; then
  printf 'UUID:\n%s\n\n' "$uuids"
  found=1
fi

# each address on a line is checked on its own, so an example address cannot hide a real one
emails="$(git grep -n -I -o -E "$EMAIL" -- . ':(exclude)scripts/check-privacy.sh' 2>/dev/null | grep -vE "$EXAMPLE_EMAIL")"
if [ -n "$emails" ]; then
  printf 'email address:\n%s\n\n' "$emails"
  found=1
fi

if [ "$found" -eq 0 ]; then
  echo "privacy check passed"
else
  echo "privacy check failed: replace the values above with RFC 5737 addresses, the all-zero UUID, example.com addresses or placeholders" >&2
fi
exit "$found"
