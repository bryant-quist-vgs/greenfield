# shellcheck shell=bash disable=SC2034,SC2154
# change_log_merge.sh — the merge that `sync` makes, for change_log.sh. Built against
# contract v1; the contract and the tests are kept in the greenfield
# repository, under tools/. Sourced by change_log.sh for `sync` after
# change_log_upstream.sh, never run on its own: it uses the variables of both
# ($root, $LOG, $nl, $tab, $re_hash, $up, $up_ref, $merged, $has_head, $head_hash,
# $head_ref, $on_branch, $merge_head, $unmerged, $merge_reported, $out, $notes, $wrote)
# and their functions (ask_git, do_git, add, die, shown, git_state, upstream_state,
# is_ancestor, unit_sum). merge_upstream and stage_log are the two functions of the unit
# that change what Git holds.
#
# The merge is made only into a clean working tree. Nothing that is not committed can
# then be in its way but a file Git ignores, and in_the_way looks for that.

# snapshot: HEAD, the merge in progress, the index, and what `git status` says, in the
# s_ variables. The status lists untracked files and no ignored ones.
s_head="" s_merge="" s_index="" s_status=""
snapshot() {
  git_state
  s_head=$head_hash s_merge=$merge_head
  s_index=$(ask_git ls-files -s -z 2>/dev/null | cksum) || die "git could not list the index"
  s_status=$(ask_git -c core.quotePath=true status --porcelain=v1 --untracked-files=all \
    --no-renames --ignore-submodules=dirty 2>/dev/null) ||
    die "git could not compare the working tree with the index"
}

# marks: sets $flagged, lines, each a path the index marks assume-unchanged or
# skip-worktree. Git does not look at the files of such paths, so `git status` says
# nothing of them. The first listing is read whole, to see whether there is any.
flagged=""
marks() {
  local line raw n=0 expected
  flagged=""
  raw=$(ask_git -c core.quotePath=true ls-files -v 2>/dev/null) || die "git could not list the index"
  case "${nl}${raw}" in
    *"${nl}"[!H]*) ;;
    *) return 0 ;;
  esac
  expected=$(ask_git ls-files -v -z 2>/dev/null | tr -cd '\000' | wc -c) || die "git could not list the index"
  while IFS= read -r -d '' line; do
    n=$((n + 1))
    case "$line" in
      "H "?*) ;;
      [a-zS]" "?*) flagged="${flagged}${line:2}${nl}" ;;
      *) die "git printed an index entry this script cannot read" ;;
    esac
  done < <(ask_git ls-files -v -z 2>/dev/null)
  if [ "$n" -ne "$((expected))" ] || [ -z "$flagged" ]; then die "git listed the index two ways"; fi
}

# name_all <lines of paths> <rule and message>: one violation for each path, ten at
# most; $named says how many there are.
named=""
name_all() {
  local line n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    [ "$n" -gt 10 ] || add "$line" 1 "$2"
  done < <(printf '%s\n' "$1")
  named="$n path(s), named above"
  [ "$n" -le 10 ] || named="$n path(s), the first 10 named above"
}

# gone <path>: the merge removes that path. $removed holds the paths the tested merge
# removes, each between line feeds; a name that holds a line feed is never taken for
# one of them.
removed=""
gone() {
  case "$1" in
    *"$nl"*) return 1 ;;
  esac
  case "$removed" in
    *"${nl}${1}${nl}"*) return 0 ;;
  esac
  return 1
}
# spare <directory>: it holds nothing but files the merge removes, so Git can take it
# away and lose nothing. A directory that cannot be read is not spare.
spare() {
  local f
  if [ ! -r "$root/$1" ] || [ ! -x "$root/$1" ]; then return 1; fi
  for f in "$root/$1"/* "$root/$1"/.[!.]* "$root/$1"/..?*; do
    if [ -d "$f" ] && [ ! -L "$f" ]; then
      spare "${f#"$root/"}" || return 1
    elif [ -e "$f" ] || [ -L "$f" ]; then
      gone "${f#"$root/"}" || return 1
    fi
  done
  return 0
}

# in_the_way <tree>: sets $inway, lines: what stands in the working tree where the
# tested merge adds a path, or is no directory where such a path needs one, unless the
# merge itself removes it; and the directory (named with a /) of a submodule that the
# merge replaces by a file or a link, if it holds anything. Git would write over each,
# or delete it with all it holds, and for a file it ignores it says nothing. Only the
# working tree is looked at: Git is not asked what stands there.
inway=""
re_raw='^:[0-7]{6} [0-7]{6} [0-9a-f]+ [0-9a-f]+ [ADMT]$'
in_the_way() {
  local meta path rest dir expected n=0 i=0 a_n=0 good="" bad=""
  local -a added
  inway="" removed=$nl
  expected=$(ask_git diff-tree -r -z --no-renames HEAD "$1" 2>/dev/null | tr -cd '\000' | wc -c) ||
    die "git could not list what the merge changes"
  while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
    n=$((n + 2))
    [[ $meta =~ $re_raw ]] || die "git printed a change of the merge that this script cannot read"
    case "${meta##* }" in
      A)
        added[a_n]=$path
        a_n=$((a_n + 1))
        ;;
      D)
        # Left out when its name holds a line feed, which would read as two names.
        case "$path" in
          *"$nl"*) ;;
          *) removed="${removed}${path}${nl}" ;;
        esac
        ;;
      T)
        if [ "${meta:1:6}" = 160000 ] && [ -d "$root/$path" ] && ! spare "$path"; then
          inway="${inway}${path}/${nl}"
        fi
        ;;
    esac
  done < <(ask_git diff-tree -r -z --no-renames HEAD "$1" 2>/dev/null)
  [ "$n" -eq "$((expected))" ] || die "git listed what the merge changes two ways"
  while [ "$i" -lt "$a_n" ]; do
    path=${added[i]}
    i=$((i + 1))
    case "$path" in
      "$bad"/*) continue ;;
    esac
    # The directories above the path, unless the last path proved them.
    if [ "${path%/*}" != "$path" ] && [ "${path%/*}" != "$good" ]; then
      rest=$path dir="" good=""
      while [ "${rest#*/}" != "$rest" ]; do
        dir="$dir${rest%%/*}"
        rest=${rest#*/}
        if [ -L "$root/$dir" ] || { [ -e "$root/$dir" ] && [ ! -d "$root/$dir" ]; }; then
          gone "$dir" || inway="${inway}${dir}${nl}"
          bad=$dir
          continue 2
        elif [ ! -e "$root/$dir" ]; then
          bad=$dir
          continue 2
        fi
        dir="$dir/"
      done
      good=${path%/*}
    fi
    if [ -d "$root/$path" ] && [ ! -L "$root/$path" ]; then
      spare "$path" || inway="${inway}${path}/${nl}"
    elif [ -e "$root/$path" ] || [ -L "$root/$path" ]; then
      inway="${inway}${path}${nl}"
    fi
  done
}

# run_merge: the merge. No commit, no stash of the caller's asking, no recorded
# resolution, no squash, a fast-forward where one is possible, and the strategy that
# was tested. The options a branch names in branch.<name>.mergeOptions are emptied: Git
# reads this setting last.
run_merge() {
  local n=${GIT_CONFIG_COUNT:-0}
  case "$n" in
    "" | *[!0-9]*) n=0 ;;
  esac
  (
    export "GIT_CONFIG_COUNT=$((n + 1))" "GIT_CONFIG_KEY_$n=branch.${head_ref#refs/heads/}.mergeoptions" \
      "GIT_CONFIG_VALUE_$n="
    do_git -c rerere.enabled=false -c submodule.recurse=false merge --no-commit --no-edit \
      --no-autostash --no-stat --no-squash --ff -s ort "$up"
  )
}

# index_is <tree>: the index holds that tree, docs/change_log.md apart.
index_is() {
  local names line
  names=$(ask_git -c core.quotePath=true diff --cached --name-only --no-renames --no-ext-diff "$1" -- 2>/dev/null) ||
    die "git could not compare the index with the tested merge"
  while IFS= read -r line; do
    if [ -n "$line" ] && [ "$line" != "$LOG" ]; then return 1; fi
  done < <(printf '%s\n' "$names")
  return 0
}

# --- sync merges the upstream into a clean working tree. -------------------------
merge_upstream() {
  local tested status tree names="" line list="" seen=0 conflicts="" text unit ff=0 made=0
  local b_head b_index changed="" more=0 not
  git_state
  [ -z "$merge_head" ] || notes="${notes}change-log: a merge is in progress; no merge was started${nl}"
  [ -n "$up" ] || return 0
  upstream_state
  [ "$merged" = no ] || return 0
  # Condition a. check_merged reports each of these; no merge is tried.
  if [ "$has_head" -eq 0 ] || [ "$on_branch" -eq 0 ] || [ -n "$merge_head" ] || [ -n "$unmerged" ]; then
    return 0
  fi
  merge_reported=1
  not="CL05 the upstream $up is not merged, and"

  # Condition b: the working tree is clean. The record of it is the one that is
  # compared after the merge.
  snapshot
  b_head=$s_head b_index=$s_index
  if [ -n "$s_status" ]; then
    while IFS= read -r line; do
      case "$line" in
        ??" "?*) list="${list}${line:3}${nl}" ;;
        *) die "git printed a status line this script cannot read" ;;
      esac
    done < <(printf '%s\n' "$s_status")
    name_all "$list" "CL05 not committed: staged, changed, deleted, or not tracked"
    add . 1 "$not the gate merges only into a working tree with no uncommitted change ($named); no merge was tried; commit the work in progress, then run make commit again"
    return 0
  fi
  # Condition c: no path is marked so that Git does not look at its file.
  marks
  if [ -n "$flagged" ]; then
    name_all "$flagged" "CL05 marked assume-unchanged or skip-worktree in the index: Git does not look at this file"
    add . 1 "$not Git cannot say that the working tree is clean while a path is marked ($named); no merge was tried; clear the mark (git update-index --no-assume-unchanged <path>, or --no-skip-worktree <path>), then run make commit again"
    return 0
  fi

  # Condition d, the test: a merge in the object database only. Exit 0 is no conflict, 1
  # is conflicts; any other exit, or no tree on the first line, is a Git that cannot
  # make the test.
  tested=$(ask_git -c core.quotePath=true merge-tree --write-tree --name-only --no-messages HEAD "$up" 2>/dev/null)
  status=$?
  tree=${tested%%"$nl"*}
  case "$tested" in
    *"$nl"*) names=${tested#*"$nl"} ;;
  esac
  if [ "$status" -eq 1 ] && [[ $tree =~ $re_hash ]]; then
    while IFS= read -r line; do
      [ -n "$line" ] || break
      seen=1
      [ "$line" = "$LOG" ] || conflicts="${conflicts}${line}${nl}"
    done < <(printf '%s\n' "$names")
  fi
  if [ "$status" -gt 1 ] || ! [[ $tree =~ $re_hash ]] || [ "$status:$seen" = 1:0 ]; then
    add . 1 "$not this Git could not test the merge (git merge-tree --write-tree, Git 2.38 or later); no merge was tried; look at git status --ignored, because a merge writes over an ignored file without a word; then run git merge $up, resolve every conflicted path other than $LOG, and run make commit again"
    return 0
  fi
  # Condition e, before the conflicts are named: no merge by hand is offered over a
  # file that it would write over.
  in_the_way "$tree"
  if [ -n "$inway" ]; then
    name_all "$inway" "CL05 in the way of a merge of the upstream, which would write over it, or delete it with all it holds"
    add . 1 "$not something stands where the merge adds a path or needs a directory ($named): a file Git ignores, which Git replaces without a word; a name that differs only in case from one the merge adds; or what the directory of a submodule holds; no merge was tried; move them away (out of the directory of a submodule, what it holds), then run make commit again"
    return 0
  fi
  if [ -n "$conflicts" ]; then
    name_all "$conflicts" "CL05 a merge of the upstream conflicts in this file"
    add . 1 "$not the merge conflicts ($named); no merge was tried; run git merge $up, resolve every conflicted path other than $LOG, and run make commit again"
    return 0
  fi

  unit=$(unit_sum) || die "cannot read the files of this tool"
  is_ancestor HEAD "$up" && ff=1
  text=$(run_merge 2>&1)
  status=$?
  # What Git says is not taken for what happened. A branch is moved forward when HEAD is
  # the upstream commit; a merge is made when it is in progress with the upstream as its
  # other side and the index holds the tested tree.
  wrote="run a merge of $up, whose result it had not read"
  snapshot
  if [ "$ff" -eq 1 ]; then
    if [ "$status" -eq 0 ] && [ "$s_head" = "$up" ] && [ -z "$s_merge" ]; then made=1; fi
  elif [ "$s_merge" = "$up" ] && [ "$s_head" = "$b_head" ] && [ "$status" -eq "$seen" ] && index_is "$tree"; then
    made=1
  fi
  if [ "$made" -eq 1 ]; then
    merge_reported=0
    if [ "$ff" -eq 1 ]; then
      wrote="moved the branch forward to $up"
      notes="${notes}change-log: moved the branch forward to $up ($(shown "$up_ref")): it had no commit of its own, and nothing is left to complete${nl}"
    else
      wrote="started a merge of $up, which is in the index and not committed"
      notes="${notes}change-log: merged $up ($(shown "$up_ref")) into the index and the working tree; not committed: when make commit passes, git commit --no-edit completes the merge${nl}"
    fi
    # A merge can bring another version of this tool. The run stops there: its shell
    # functions are the old ones, and the awk programs on disk are the new ones.
    [ "$unit" = "$(unit_sum)" ] ||
      die "the merge changed the files of this tool (change_log*); run make change-log again, which runs the merged tool"
    return 0
  fi

  # Not made, for a reason that was not foreseen. What was compared says whether Git
  # left changes behind; nothing more is claimed than what was compared. The working
  # tree was clean, so every line of the status is a change.
  wrote=""
  [ "$s_head" = "$b_head" ] || changed="$changed HEAD,"
  [ -z "$s_merge" ] || changed="$changed MERGE_HEAD,"
  [ "$s_index" = "$b_index" ] || changed="$changed the index,"
  # A file written where Git ignores the name is in no status: in_the_way finds it.
  in_the_way "$tree"
  names=""
  while IFS= read -r line; do
    [ -z "$line" ] || list="${list}${line:3}${nl}"
  done < <(printf '%s\n' "$s_status")
  while IFS= read -r line; do
    case "${nl}${names}" in
      *"${nl}${line}${nl}"*) continue ;;
    esac
    names="${names}${line}${nl}"
    more=$((more + 1))
    [ "$more" -gt 10 ] || changed="$changed $(shown "$line"),"
  done < <(printf '%s' "${list}${inway}")
  [ "$more" -le 10 ] || changed="$changed $((more - 10)) more path(s),"
  if [ -n "$changed" ]; then
    printf '%s\n' "$text" | tr -d '\000-\010\013-\037\177' | while IFS= read -r line; do
      printf 'change_log: git: %s\n' "${line//[! -~]/?}"
    done >&2
    die "git stopped part-way through the merge of $up (exit $status) and left changes behind:${changed%,}; this run undoes nothing: see git status"
  fi
  add . 1 "$not git refused the merge (exit $status); its message follows; HEAD, MERGE_HEAD, the index, and the answer of git status are the same as before the merge was tried, and nothing else was compared; act on the message and run make commit again"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    line=${line//"$tab"/ }
    out="${out}    git: ${line//[! -~]/?}${nl}"
  done < <(printf '%s\n' "$text")
}

# --- While a merge is in progress, the regenerated list is staged. --------------
# Staged whenever it is unmerged or differs from the copy the index holds, so that the
# merge can be completed, or abandoned with git merge --abort. Outside a merge the list
# is never staged.
stage_log() {
  git_state
  [ -n "$merge_head" ] || return 0
  ask_git cat-file blob ":$LOG" 2>/dev/null | cmp -s - "$root/$LOG" && return 0
  do_git add -- "$LOG" >/dev/null 2>&1 || die "git add failed for $LOG"
  wrote="${wrote:+$wrote, and }staged $LOG"
  notes="${notes}change-log: $LOG staged, for the merge in progress${nl}"
}
