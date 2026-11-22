#!/bin/bash
# disk-space — measure where the space of this Mac's internal disk went, and look the
# result up in a knowledge base of known problems.
#
#   disk-space.sh probe              print what can be measured, one signal=value per line
#   disk-space.sh sizes [MIN_GB]     size of each candidate location (see candidates.tsv)
#   disk-space.sh match [FILE]       known problems these signals fit (id, evidence status,
#                                    origin, title; tab separated). Without a file it runs
#                                    the probe. Exit 3: no match.
#   disk-space.sh list               every known problem
#   disk-space.sh show ID            one problem: symptoms, cause, fixes, what does not work
#   disk-space.sh validate           check problems.json and the personal additions
#
# Every subcommand reads; none deletes a file, changes a setting or starts a backup.
# What the skill may change is decided in plugin/skills/disk-space/SKILL.md.
#
# Nothing here parses text that changes with the system language.
#
# The knowledge base is ../data/problems.json. A person's own additions go in
# ~/.config/mac-disk-space/problems.local.json; see README.md.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
KB="${DISK_SPACE_KB:-$HERE/../data/problems.json}"
LOCAL_KB="${DISK_SPACE_LOCAL_KB:-$HOME/.config/mac-disk-space/problems.local.json}"
KBJS="$HERE/kb.js"

TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT
tmpdir() { [ -n "$TMPD" ] || TMPD="$(mktemp -d)"; }

kb() { osascript -l JavaScript "$KBJS" "$@"; }

probe() {
  echo "probe_result=partial"
}

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

case "${1:-}" in
  probe) probe ;;
  match)
    tmpdir
    if [ -n "${2:-}" ]; then cp "$2" "$TMPD/signals"; else probe > "$TMPD/signals"; fi
    kb match "$KB" "$LOCAL_KB" "$TMPD/signals" > "$TMPD/matched" || exit 1
    cat "$TMPD/matched"
    [ -s "$TMPD/matched" ] || exit 3
    ;;
  list) kb list "$KB" "$LOCAL_KB" ;;
  show) [ -n "${2:-}" ] || { echo "usage: $0 show ID" >&2; exit 64; }; kb show "$KB" "$LOCAL_KB" "$2" ;;
  validate) kb validate "$KB" "$LOCAL_KB" ;;
  *) usage ;;
esac
