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
#   disk-space.sh validate           check problems.json, candidates.tsv and the personal
#                                    additions; exit 1 on any malformed line or entry
#   disk-space.sh candidates         every valid candidate line, shipped and personal:
#                                    origin, path, kind, command, reason (tab separated).
#                                    A malformed line is reported on stderr and skipped
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
CANDIDATES="${DISK_SPACE_CANDIDATES:-$HERE/../data/candidates.tsv}"
LOCAL_CANDIDATES="${DISK_SPACE_LOCAL_CANDIDATES:-$HOME/.config/mac-disk-space/candidates.local.tsv}"

TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT
tmpdir() { [ -n "$TMPD" ] || TMPD="$(mktemp -d)"; }

kb() { osascript -l JavaScript "$KBJS" "$@"; }

# check_candidates ORIGIN FILE: print valid lines as ORIGIN<TAB>line, report the
# others on stderr. Exit 1 when a line was malformed. Kinds are a closed list; the
# command field must be empty for personal, cloud-sync and system, because the skill
# runs no command for those rows.
check_candidates() {
  [ -r "$2" ] || return 0
  awk -F'\t' -v origin="$1" -v file="$2" '
    /^#/ || /^[[:space:]]*$/ { next }
    {
      why = ""
      if (NF != 4) why = "needs 4 tab-separated fields, has " NF
      else if ($1 == "") why = "empty path"
      else if ($2 !~ /^(cache|download|build|personal|cloud-sync|system)$/) why = "unknown kind \"" $2 "\""
      else if ($3 != "" && $2 ~ /^(personal|cloud-sync|system)$/) why = "kind " $2 " must have an empty command"
      else if ($4 == "") why = "empty reason"
      if (why != "") { printf "%s:%d: malformed candidate (%s)\n", file, NR, why > "/dev/stderr"; bad = 1; next }
      print origin "\t" $0
    }
    END { exit bad }
  ' "$2"
}

candidates() {
  local rc=0
  check_candidates shipped "$CANDIDATES" || rc=1
  check_candidates local "$LOCAL_CANDIDATES" || rc=1
  return $rc
}

# plist_get FILE KEYPATH: the raw value, or nothing when the key is missing
plist_get() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

# source_file VAR CMD...: the override file named in VAR, or the command's output saved
# to a temporary file. Prints the path; prints nothing when the command failed.
source_file() {
  local var="$1"; shift
  eval "local override=\"\${$var:-}\""
  if [ -n "$override" ]; then
    [ -r "$override" ] && echo "$override"
    return
  fi
  tmpdir
  local f="$TMPD/$var"
  "$@" > "$f" 2>/dev/null && echo "$f"
}

GB=1000000000

probe_container() {
  local info apfs ref n i free ceiling nv j role used
  local data=0 vm=0 system=0 preboot=0 recovery=0 seen=""
  info="$(source_file DISK_SPACE_INFO_PLIST diskutil info -plist /)"
  apfs="$(source_file DISK_SPACE_APFS_PLIST diskutil apfs list -plist)"
  [ -n "$info" ] && [ -n "$apfs" ] || return 1
  ref="$(plist_get "$info" APFSContainerReference)"
  n="$(plist_get "$apfs" Containers)"
  [ -n "$ref" ] && [ -n "$n" ] || return 1
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$(plist_get "$apfs" "Containers.$i.ContainerReference")" = "$ref" ]; then
      ceiling="$(plist_get "$apfs" "Containers.$i.CapacityCeiling")"
      free="$(plist_get "$apfs" "Containers.$i.CapacityFree")"
      [ -n "$ceiling" ] && [ "$ceiling" -gt 0 ] 2>/dev/null && [ -n "$free" ] || return 1
      echo "container_free_pct=$(( free * 100 / ceiling ))"
      echo "container_free_gb=$(( free / GB ))"
      nv="$(plist_get "$apfs" "Containers.$i.Volumes")"
      j=0
      while [ "$j" -lt "${nv:-0}" ]; do
        role="$(plist_get "$apfs" "Containers.$i.Volumes.$j.Roles.0")"
        used="$(plist_get "$apfs" "Containers.$i.Volumes.$j.CapacityInUse")"
        used="${used:-0}"
        case "$role" in
          Data) data=$((data + used)); seen="$seen Data" ;;
          VM) vm=$((vm + used)); seen="$seen VM" ;;
          System) system=$((system + used)); seen="$seen System" ;;
          Preboot) preboot=$((preboot + used)); seen="$seen Preboot" ;;
          Recovery) recovery=$((recovery + used)); seen="$seen Recovery" ;;
        esac
        j=$((j + 1))
      done
      case "$seen" in *" Data"*) echo "volume_used_gb_Data=$(( data / GB ))" ;; esac
      case "$seen" in *" VM"*) echo "volume_used_gb_VM=$(( vm / GB ))" ;; esac
      case "$seen" in *" System"*) echo "volume_used_gb_System=$(( system / GB ))" ;; esac
      case "$seen" in *" Preboot"*) echo "volume_used_gb_Preboot=$(( preboot / GB ))" ;; esac
      case "$seen" in *" Recovery"*) echo "volume_used_gb_Recovery=$(( recovery / GB ))" ;; esac
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

probe_purgeable() {
  local f a i
  f="$(source_file DISK_SPACE_CAPACITY osascript -l JavaScript "$HERE/capacity.js")"
  [ -n "$f" ] || return 1
  a="$(sed -n 's/^available=\([0-9][0-9]*\)$/\1/p' "$f")"
  i="$(sed -n 's/^important=\([0-9][0-9]*\)$/\1/p' "$f")"
  [ -n "$a" ] && [ -n "$i" ] || return 1
  if [ "$i" -gt "$a" ]; then echo "purgeable_gb=$(( (i - a) / GB ))"; else echo "purgeable_gb=0"; fi
}

# Snapshot names are YYYY-MM-DD-HHMMSS; the header line above them may be translated.
probe_snapshots() {
  local f
  f="$(source_file DISK_SPACE_SNAPSHOTS tmutil listlocalsnapshotdates /)"
  [ -n "$f" ] || return 1
  echo "local_snapshots=$(grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$' "$f")"
}

# sysctl prints "total = 40960.00M  used = 36716.00M  free = ...", in MiB.
probe_swap() {
  local f gb
  f="$(source_file DISK_SPACE_SWAP sysctl -n vm.swapusage)"
  [ -n "$f" ] || return 1
  gb="$(awk -v gbytes="$GB" '{
          for (k = 1; k < NF; k++) if ($k == "used" && $(k+1) == "=") {
            v = $(k+2); m = 1048576
            if (v ~ /G$/) m = 1073741824
            sub(/[MG]$/, "", v)
            if (v ~ /^[0-9.]+$/) { printf "%d\n", v * m / gbytes; exit }
          }
        }' "$f")"
  [ -n "$gb" ] || return 1
  echo "swap_used_gb=$gb"
}

probe() {
  local result=ok
  probe_container || result=partial
  probe_purgeable || result=partial
  probe_snapshots || result=partial
  probe_swap || result=partial
  echo "probe_result=$result"
}

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

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
  validate)
    rc=0
    kb validate "$KB" "$LOCAL_KB" || rc=1
    candidates >/dev/null || rc=1
    [ "$rc" -eq 0 ] && echo "candidates are valid"
    exit $rc
    ;;
  candidates) candidates; exit 0 ;;
  *) usage ;;
esac
