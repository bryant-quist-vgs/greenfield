#!/usr/bin/env bash
# change_log.sh — record a change, generate docs/change_log.md, and check the change log.
# Built against contract v1. The contract and the tests of this tool are
# kept in the greenfield repository, under tools/, and not here. `make change-log` and
# `make change-log-entry` run it, and an agent may run both targets. The verb `check`
# writes nothing. The unit holds no here-document and no here-string, because bash
# before 5.1 implements both with a temporary file. Text from an entry, from tags.md, and
# from Git's answers is never executed.
#
# The unit is this file, the four files it sources (change_log_list.sh always,
# change_log_new.sh for `new`, change_log_upstream.sh for `check` and `sync`,
# change_log_merge.sh for `sync`), and two awk programs.

set -u
set -o pipefail
unset CDPATH
export LC_ALL=C
# The repository is the one --repo names, whatever the caller's environment says. A path
# given to Git is that path, never a pattern, and Git fetches no missing object.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX \
  GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS
export GIT_NO_LAZY_FETCH=1 GIT_LITERAL_PATHSPECS=1

# The baseline tags, the same in every repository (docs/greenfield/change-log.md §2). The
# tests compare this line with the table there.
baseline_tags='breaking design docs feature fix maintenance performance process refactor removal security test'

usage() {
  printf '%s\n' \
    'Usage: change_log.sh [--repo DIR] new --title TITLE --tags "TAG TAG" [--at YYYY-MM-DD-hhmmss]' \
    '       change_log.sh [--repo DIR] render' \
    '       change_log.sh [--repo DIR] check [--upstream REF]' \
    '       change_log.sh [--repo DIR] sync [--upstream REF]' \
    '       change_log.sh -h | --help' \
    '' \
    'new     create an entry under DIR/docs/change_log/ (default DIR: .), named from the' \
    '        UTC clock or --at and the first six words of the title, then regenerate' \
    '        docs/change_log.md. An entry is never overwritten.' \
    'render  regenerate docs/change_log.md from the entries.' \
    'check   check rules CL01 to CL06 and write nothing. One line for each violation:' \
    '          <path>:<line>: CL<nn> <message>' \
    'sync    merge the upstream, when it is not merged, into a working tree with no' \
    '        uncommitted change, where that merge is trivial; regenerate' \
    '        docs/change_log.md; then check. It never contacts a remote and never' \
    '        commits.' \
    '' \
    'The upstream is --upstream REF, or the branch refs/remotes/origin/HEAD names.' \
    'Exit codes: 0 done, or no violations; 1 violations; 2 bad usage, or anything that' \
    'stops the verb from doing its work.'
}

# What this run has written so far, for the message of a failure that comes after it.
wrote=""
die() {
  {
    printf 'change_log: %s\n' "$1"
    [ -z "$wrote" ] || printf 'change_log: before this failure the run had %s\n' "$wrote"
  } | tr -d '\000-\010\013-\037\177' >&2
  exit 2
}
# What a run that fails or is interrupted must not leave behind: the temporary file of
# the list, and an entry that was created and not yet written.
tmp_file="" partial=""
# shellcheck disable=SC2317 # called by the trap
cleanup() {
  [ -z "$tmp_file" ] || rm -f "$tmp_file"
  [ -z "$partial" ] || rm -f "$partial"
}
trap cleanup EXIT
trap 'exit 2' HUP INT TERM

repo=. verb="" title="" tags_arg="" at="" upstream_arg=""
has_repo=0 has_title=0 has_tags=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --repo | --title | --tags | --at | --upstream)
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1:$verb" in
        --repo:) repo=$2 has_repo=$((has_repo + 1)) ;;
        --title:new) title=$2 has_title=$((has_title + 1)) ;;
        --tags:new) tags_arg=$2 has_tags=$((has_tags + 1)) ;;
        --at:new) [ -z "$at" ] || die "--at is given twice"; at=$2 ;;
        --upstream:check | --upstream:sync)
          [ -z "$upstream_arg" ] || die "--upstream is given twice"
          upstream_arg=$2
          ;;
        *) die "$1 does not belong here (try --help)" ;;
      esac
      [ -n "$2" ] || die "$1 needs a value that is not empty"
      shift 2
      ;;
    new | render | check | sync)
      [ -z "$verb" ] || die "a second verb: $1 (try --help)"
      verb=$1
      shift
      ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done
[ -n "$verb" ] || die "no verb: new, render, check, or sync (try --help)"
[ "$has_repo" -le 1 ] || die "--repo is given twice"
if [ "$verb" = new ]; then
  [ "$has_title" -eq 1 ] || die "new needs --title, once"
  [ "$has_tags" -eq 1 ] || die "new needs --tags, once"
fi
case "$upstream_arg" in
  -* | *[!\ -~]* | *" "*) die "--upstream is a ref name: printable, no space, not starting with -" ;;
esac

command -v git >/dev/null 2>&1 || die "git is not on PATH"
command -v awk >/dev/null 2>&1 || die "awk is not on PATH"
case "$repo" in
  /*) ;;
  *) repo="./$repo" ;;
esac
[ -d "$repo" ] || die "not a directory: $repo"
root=$(cd "$repo" && pwd -P) || die "cannot enter: $repo"

# Every Git command goes through one of these two: no file-system monitor, no hook, and
# no maintenance process started behind the run. ask_git only reads and never refreshes
# the index; do_git runs the two commands of `sync` that write.
pins=(-c core.fsmonitor=false -c core.hooksPath=/dev/null -c maintenance.auto=false -c gc.auto=0)
ask_git() { git --no-optional-locks "${pins[@]}" -C "$root" "$@"; }
do_git() { git "${pins[@]}" -C "$root" "$@" </dev/null; }

LOG=docs/change_log.md
DIR=docs/change_log
TAGS=docs/change_log/tags.md

[ "$(ask_git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] ||
  die "not inside a Git work tree: $repo"
prefix=$(ask_git rev-parse --show-prefix 2>/dev/null) || die "git could not say where $repo lies in its work tree"
[ -z "$prefix" ] || die "not the root of the work tree: $repo"
# in_place: what the script reads and writes beneath is real, and no link leads out of
# the repository. Asked when the run begins, and again before the entries are read and
# the list is written, because a merge can change it.
in_place() {
  if [ ! -d "$root/docs" ] || [ -L "$root/docs" ]; then die "no docs/ directory in: $repo"; fi
  if [ -L "$root/$DIR" ] || { [ -e "$root/$DIR" ] && [ ! -d "$root/$DIR" ]; }; then
    die "$DIR is not a directory"
  fi
  if [ -L "$root/$LOG" ] || { [ -e "$root/$LOG" ] && [ ! -f "$root/$LOG" ]; }; then
    die "$LOG is not a regular file"
  fi
}
in_place

here=$(cd "$(dirname -- "$0")" && pwd -P) || die "cannot find this script's directory"
entry_awk="$here/change_log_entry.awk"
tags_awk="$here/change_log_tags.awk"
list_sh="$here/change_log_list.sh"
new_sh="$here/change_log_new.sh"
upstream_sh="$here/change_log_upstream.sh"
merge_sh="$here/change_log_merge.sh"
for file in "$entry_awk" "$tags_awk" "$list_sh" "$new_sh" "$upstream_sh" "$merge_sh"; do
  [ -f "$file" ] || die "the files of this tool (change_log_*.sh and change_log_*.awk) must be beside this script; missing: ${file##*/}"
done
# unit_sum: a checksum of each file of the unit. A merge can bring another version.
unit_sum() { cksum "$0" "$list_sh" "$new_sh" "$upstream_sh" "$merge_sh" "$entry_awk" "$tags_awk" 2>/dev/null; }

nl='
'
tab=$'\t'
re_hash='^[0-9a-f]{40}$'
re_entry='^[0-9]{4}-[0-9]{2}-[0-9]{2}-([0-9]{6})-[a-z0-9]+(-[a-z0-9]+){0,5}\.md$'
re_stamp='^[0-9]{4}-[0-9]{2}-[0-9]{2}-([0-9]{6})$'
re_tag='^[a-z][a-z0-9-]{0,29}(:[a-z][a-z0-9-]{0,29})?$'

# shown <path or ref>: the text for a message. Git prints an unusual name in quotes with
# an escape for each unusual byte; each escape becomes ?, and so does every other byte
# that is not printable ASCII. A name longer than 200 characters is cut there, and ...
# stands for the rest.
shown() {
  local p=$1
  case "$p" in
    \"*\")
      p=${p#\"}
      p=${p%\"}
      p=${p//\\[0-7][0-7][0-7]/?}
      p=${p//\\?/?}
      ;;
  esac
  p=${p//[! -~]/?}
  [ "${#p}" -le 200 ] || p="${p:0:200}..."
  printf '%s' "$p"
}

# add <path> <line> <rule and message>: one violation.
out=""
count=0
add() {
  out="${out}$(shown "$1"):$2: $3${nl}"
  count=$((count + 1))
}

# time_ok <hhmmss>: a time of day.
time_ok() {
  [ "$((10#${1:0:2}))" -le 23 ] && [ "$((10#${1:2:2}))" -le 59 ] && [ "$((10#${1:4:2}))" -le 59 ]
}

# plain <path> <rule>: the file holds no control character but tab and line feed. A
# carriage return or a NUL would be read one way by awk and another by a renderer.
plain() {
  local raw clean
  raw=$(wc -c <"$root/$1") || die "cannot read $1"
  clean=$(tr -d '\000-\010\013-\037\177' <"$root/$1" | wc -c) || die "cannot read $1"
  [ "$((raw))" -eq "$((clean))" ] && return 0
  add "$1" 1 "$2 the file holds a control character other than tab and line feed (a carriage return is one)"
  return 1
}

# parse <awk program> <path> <awk arguments...>: runs a parser on a file of the
# repository and leaves its lines in $parsed. The last line must be the parser's E.
parsed=""
parse() {
  local program=$1 path=$2
  shift 2
  # "$root" is absolute, so awk cannot take the operand for a variable assignment.
  parsed=$(awk "$@" -f "$program" "$root/$path") || die "awk failed on $path"
  [ "${parsed##*"$nl"}" = E ] || die "the parser did not finish $path"
}

# lines <text>: the number of lines in it.
lines() {
  local n
  n=$(printf '%s' "$1" | wc -l) || die "wc failed"
  printf '%d' "$((n))"
}

# The entries, the tag file, and the list: read_tags, scan, write_log.
# shellcheck source-path=SCRIPTDIR source=change_log_list.sh
. "$list_sh"

# --- The verbs. -----------------------------------------------------------------
# Everything from here on is one function that ends in exit, read whole before it runs,
# and every file it sources is read whole before a merge is made: a merge can replace
# these files, and bash must not read on from a file that changed.
notes=""  # the lines that begin change-log: and stand before the summary
main() {
  local upstream_note
  case "$verb" in
    new)
      # shellcheck source-path=SCRIPTDIR source=change_log_new.sh
      . "$new_sh"
      do_new
      exit 0
      ;;
    render)
      scan
      write_log
      say_log
      exit 0
      ;;
  esac

  # check and sync: the upstream, the merge, and rules CL04 and CL05.
  # shellcheck source-path=SCRIPTDIR source=change_log_upstream.sh
  . "$upstream_sh"
  find_upstream
  if [ "$verb" = sync ]; then
    # shellcheck source-path=SCRIPTDIR source=change_log_merge.sh
    . "$merge_sh"
    merge_upstream
    scan
    write_log
    [ "$log_written" -eq 0 ] || notes="${notes}change-log: $LOG written${nl}"
    stage_log
  else
    scan
  fi
  # CL03: the list is what the entries generate.
  if [ ! -f "$root/$LOG" ]; then
    add "$LOG" 1 "CL03 the file is missing; outside CI, make change-log generates it"
  elif ! log_current; then
    add "$LOG" 1 "CL03 not what the entries generate; outside CI, make change-log regenerates it (the file is never edited by hand)"
  fi
  check_merged
  check_recorded
  if [ -n "$untracked" ]; then
    notes="${notes}change-log: $(lines "$untracked") entry file(s) not tracked by Git yet (the first: $(shown "$DIR/${untracked%%"$nl"*}")); add them to the commit, with $LOG${nl}"
  fi

  if [ -n "$up" ]; then
    upstream_note="upstream $(shown "$up_ref") at $up"
  else
    upstream_note="no upstream known$no_upstream_why"
  fi
  printf '%s' "${out}${notes}" | tr -d '\000-\010\013-\037\177'
  if [ "$count" -gt 0 ]; then
    printf 'change-log: %d entry(ies) checked, %s, %d violation(s)\n' "$entry_count" "$upstream_note" "$count"
    exit 1
  fi
  printf 'change-log: %d entry(ies) checked, %s, no violations\n' "$entry_count" "$upstream_note"
  exit 0
}
main
