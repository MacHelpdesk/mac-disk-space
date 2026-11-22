#!/bin/bash
# disk-space — measure where the space of this Mac's internal disk went, and look the
# result up in a knowledge base of known problems.
#
#   disk-space.sh probe              print what can be measured, one signal=value per line
#   disk-space.sh sizes [MIN_GB]     size of each candidate location in whole GB, tab
#                                    separated: size (or not-measured), kind, path,
#                                    command, reason, origin, online-only GB (cloud-sync
#                                    rows only), printed as measured in candidate-list
#                                    order. Each location gets at most 60 s, the run
#                                    at most 300 s; a path holding a shell metacharacter
#                                    or a control character is printed with printf %q and
#                                    its kind prefixed with unsafe_
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
#   disk-space.sh online-only PATH   make the downloaded files under PATH online-only.
#                                    PATH must be inside iCloud Drive or a Dropbox folder,
#                                    the two services verified on macOS 27.3. Prints
#                                    online_only_done, online_only_failed and
#                                    online_only_skipped. Exit 64: refused, 2: a file failed
#
# Every subcommand except online-only only reads; none deletes a file, changes a
# setting or starts a backup. online-only removes local copies whose cloud copy stays.
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
CURRENT_PID=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
# A run stopped from outside (the caller's time limit, Ctrl-C) stops the measurement in
# progress too, instead of leaving it to finish on its own.
stop_child() { [ -n "$CURRENT_PID" ] && kill "$CURRENT_PID" 2>/dev/null; CURRENT_PID=""; }
trap cleanup EXIT
trap 'stop_child; exit 143' TERM
trap 'stop_child; exit 130' INT
# One temporary directory per run, created in the main shell before any subcommand runs:
# a directory created inside $(...) or a pipeline would live only in that subshell and
# the EXIT trap would never see it. An explicit template makes mktemp honour TMPDIR.
tmpdir() { [ -n "$TMPD" ] || TMPD="$(mktemp -d "${TMPDIR:-/tmp}/disk-space.XXXXXX")"; }

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

LOCATION_LIMIT="${DISK_SPACE_LOCATION_LIMIT:-60}"
RUN_LIMIT="${DISK_SPACE_RUN_LIMIT:-300}"

# run_limited SECONDS OUTFILE CMD...: run the external command CMD in the background,
# writing OUTFILE, and stop it after SECONDS. Returns 0 when it finished in time with
# exit status 0, 1 when it was stopped, 2 when it finished with another status (du
# that could not read part of a folder). CMD must be an external command, not a shell
# function: a function runs in a subshell, and stopping the subshell would leave its
# children running. Bash 3.2 and macOS have no timeout(1), so this polls: every 0.1 s
# for the first second, then every second.
run_limited() {
  local limit="$1" out="$2" pid tenths=0 status; shift 2
  "$@" > "$out" 2>/dev/null &
  pid=$!
  CURRENT_PID="$pid"
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$tenths" -ge $((limit * 10)) ]; then
      kill "$pid" 2>/dev/null
      local w=0
      while kill -0 "$pid" 2>/dev/null && [ "$w" -lt 20 ]; do sleep 0.1; w=$((w + 1)); done
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      CURRENT_PID=""
      return 1
    fi
    if [ "$tenths" -lt 10 ]; then sleep 0.1; tenths=$((tenths + 1))
    else sleep 1; tenths=$((tenths + 10)); fi
  done
  wait "$pid"
  status=$?
  CURRENT_PID=""
  [ "$status" -eq 0 ] && return 0
  return 2
}

# Online-only files have the dataless flag; their size is never used to decide that.
# One find process prints the byte size of each, so stopping it stops the scan.
DATALESS_CMD="find -x"

# emit_row SIZE KIND PATH COMMAND REASON ORIGIN ONLINE_ONLY
emit_row() {
  local kind="$2" path="$3"
  case "$path" in
    *[\$\`\;\|\&\<\>\\\"\'\!\*\?\[\]\(\)\{\}]*|*[[:cntrl:]]*)
      kind="unsafe_$kind"; path="$(printf '%q' "$path")" ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$kind" "$path" "$4" "$5" "$6" "$7"
}

sizes() {
  local min="${1:-1}" started="$SECONDS" origin pattern kind command reason p left
  local kb gb online oldifs du="${DISK_SPACE_DU:-du}" dl="${DISK_SPACE_DATALESS:-}" n=0 t0
  candidates > "$TMPD/candidates"
  oldifs="$IFS"
  local line TAB='	'
  # Split on single tabs by hand: read with IFS set to a tab merges consecutive tabs,
  # which would move the reason into the empty command field.
  while IFS= read -r line; do
    origin="${line%%"$TAB"*}"; line="${line#*"$TAB"}"
    pattern="${line%%"$TAB"*}"; line="${line#*"$TAB"}"
    kind="${line%%"$TAB"*}"; line="${line#*"$TAB"}"
    command="${line%%"$TAB"*}"; reason="${line#*"$TAB"}"
    case "$pattern" in '~'*) pattern="$HOME${pattern#\~}" ;; esac
    IFS='
'
    for p in $pattern; do
      IFS="$oldifs"
      [ -e "$p" ] || continue
      n=$((n + 1)); online=""; t0=$SECONDS
      # one budget per location, shared by du and the online-only scan
      left=$((RUN_LIMIT - (SECONDS - started)))
      [ "$left" -gt "$LOCATION_LIMIT" ] && left="$LOCATION_LIMIT"
      if [ "$left" -le 0 ] || ! run_limited "$left" "$TMPD/du.$n" "$du" -sxk "$p" 2>/dev/null; then
        emit_row not-measured "$kind" "$p" "$command" "$reason" "$origin" ""
        continue
      fi
      kb="$(tail -1 "$TMPD/du.$n" | cut -f1)"
      case "$kb" in ''|*[!0-9]*) emit_row not-measured "$kind" "$p" "$command" "$reason" "$origin" ""; continue ;; esac
      gb=$(( kb * 1024 / GB ))
      [ "$gb" -ge "$min" ] || continue
      if [ "$kind" = cloud-sync ]; then
        left=$((LOCATION_LIMIT - (SECONDS - t0)))
        [ "$left" -gt $((RUN_LIMIT - (SECONDS - started))) ] && left=$((RUN_LIMIT - (SECONDS - started)))
        if [ "$left" -gt 0 ] && { if [ -n "$dl" ]; then run_limited "$left" "$TMPD/dl.$n" "$dl" "$p" 2>/dev/null
             else run_limited "$left" "$TMPD/dl.$n" $DATALESS_CMD "$p" -type f -flags +dataless -exec stat -f %z {} + 2>/dev/null; fi; }; then
          online="$(awk -v g="$GB" '{ s += $1 } END { printf "%d\n", s / g }' "$TMPD/dl.$n")"
        else
          online="not-measured"
        fi
      fi
      emit_row "$gb" "$kind" "$p" "$command" "$reason" "$origin" "$online"
    done
    IFS="$oldifs"
  done < "$TMPD/candidates"
}

# physical PATH: the path with every symlink resolved, or nothing
physical() {
  if [ -d "$1" ]; then (cd "$1" 2>/dev/null && pwd -P)
  elif [ -f "$1" ] && [ ! -L "$1" ]; then
    local d; d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" && printf '%s/%s\n' "$d" "$(basename "$1")"
  fi
}

# The roots whose online-only mechanism was verified (spike 1.2). This list is closed.
online_only_roots() {
  physical "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  local d
  for d in "$HOME/Library/CloudStorage/Dropbox" "$HOME/Library/CloudStorage/Dropbox-"*; do
    [ -d "$d" ] && physical "$d"
  done
}

online_only() {
  local target real root inside="" f done=0 failed=0 skipped=0 listed
  target="${1:-}"
  [ -n "$target" ] || { echo "usage: $0 online-only PATH" >&2; return 64; }
  real="$(physical "$target")"
  [ -n "$real" ] || { echo "online-only: not a folder or plain file: $target" >&2; return 64; }
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    case "$real/" in "$root/"*) inside=yes ;; esac
  done <<EOF_ROOTS
$(online_only_roots)
EOF_ROOTS
  [ -n "$inside" ] || { echo "online-only: refused, not inside iCloud Drive or Dropbox: $target" >&2; return 64; }
  tmpdir
  # find decides which files are already online-only (one process for the whole folder,
  # not one stat per file). The test hook stands in for the dataless flag by file name.
  local is_dl not_dl
  if [ -n "${DISK_SPACE_DATALESS_TEST:-}" ]; then
    is_dl=(-name "$DISK_SPACE_DATALESS_TEST"); not_dl=(! -name "$DISK_SPACE_DATALESS_TEST")
  else
    is_dl=(-flags +dataless); not_dl=(! -flags +dataless)
  fi
  skipped=$(find -x "$real" -type f "${is_dl[@]}" -print0 2>/dev/null | tr -dc '\000' | wc -c | tr -d ' ')
  : > "$TMPD/evict-list"
  while IFS= read -r -d '' f; do
    # one path per line goes to evict.js, so a name holding a newline cannot be sent
    case "$f" in *'
'*) failed=$((failed + 1)); continue ;; esac
    printf '%s\n' "$f" >> "$TMPD/evict-list"
  done < <(find -x "$real" -type f "${not_dl[@]}" -print0 2>/dev/null)
  if [ -s "$TMPD/evict-list" ]; then
    if [ -n "${DISK_SPACE_EVICT:-}" ]; then
      "$DISK_SPACE_EVICT" < "$TMPD/evict-list" > "$TMPD/evict-out" 2>/dev/null
    else
      osascript -l JavaScript "$HERE/evict.js" < "$TMPD/evict-list" > "$TMPD/evict-out" 2>/dev/null
    fi
    # A file counts as done only when evict.js reported "ok" for that exact listed path,
    # once. Every other listed file (reported "fail", not reported, or the step crashed)
    # counts as failed; lines for paths that were not listed are ignored.
    listed=$(grep -c . "$TMPD/evict-list")
    local ok_n
    ok_n=$(awk 'NR == FNR { want[$0] = 1; next }
      /^ok / { p = substr($0, 4); if ((p in want) && !(p in seen)) { seen[p] = 1; n++ } }
      END { print n + 0 }' "$TMPD/evict-list" "$TMPD/evict-out")
    done=$((done + ok_n))
    failed=$((failed + listed - ok_n))
  fi
  echo "online_only_done=$done"
  echo "online_only_failed=$failed"
  echo "online_only_skipped=$skipped"
  [ "$failed" -eq 0 ] || return 2
}

probe() {
  local result=ok
  probe_container || result=partial
  probe_purgeable || result=partial
  probe_snapshots || result=partial
  probe_swap || result=partial
  echo "probe_result=$result"
}

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

tmpdir
case "${1:-}" in
  probe) probe ;;
  # Rows are printed as each location is measured, in the order of the candidate list,
  # so that a run stopped part-way still has the rows it measured. The skill sorts them.
  sizes) sizes "${2:-1}" ;;
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
  online-only) online_only "${2:-}"; exit $? ;;
  *) usage ;;
esac
