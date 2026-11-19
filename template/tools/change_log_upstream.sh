# shellcheck shell=bash disable=SC2034,SC2154
# change_log_upstream.sh — the upstream, what Git holds, and rules CL04 and CL05 of
# change_log.sh. Built against contract v1; the contract and the tests are
# kept in the greenfield repository, under tools/. Sourced by change_log.sh for `check`
# and `sync`, never run on its own: it uses that script's
# variables ($root, $upstream_arg, $LOG, $DIR, $nl, $tab, $re_hash, $re_entry, $entries,
# $count) and functions (ask_git, add, die, shown). Nothing here writes.

# absent <reference> [<what it is, when it exists>]: nothing of that name exists. A
# reference that exists and names no commit is damage, not absence: Git prints a
# reference it holds, and complains about one it cannot read. Git's complaint is read
# from its error output, so the caller's trace settings are not passed on to this one
# question; anything else Git prints there is shown as it is, not explained.
absent() {
  local refs
  refs=$(
    unset GIT_TRACE GIT_TRACE_SETUP GIT_TRACE_REFS GIT_TRACE_PERFORMANCE GIT_TRACE_PACK_ACCESS \
      GIT_TRACE_PACKET GIT_TRACE_PACKFILE GIT_TRACE_SHALLOW GIT_TRACE_FSMONITOR GIT_TRACE_CURL \
      GIT_TRACE2 GIT_TRACE2_EVENT GIT_TRACE2_PERF
    ask_git for-each-ref --count=1 --format='%(refname)' "$1" 2>&1
  ) || die "the reference $(shown "$1") exists and cannot be read; the repository is damaged"
  # A reference beneath that name (a branch a/b, asked for a) is another reference.
  case "$refs" in
    "" | "$1"/*) ;;
    "$1") die "the reference $(shown "$1") ${2:-exists and names no commit}" ;;
    *) die "git did not say that the reference $(shown "$1") is absent; it said: $(shown "${refs%%"$nl"*}")" ;;
  esac
}

# --- The upstream. --------------------------------------------------------------
up=""               # the upstream commit, or empty when no upstream is known
up_ref=""           # the name it was found under
no_upstream_why=""  # for the summary line
find_upstream() {
  local status shallow
  # A partial clone is marked in the configuration, whatever the value of the setting.
  # It lacks objects, with an upstream or without one. Git exits 0 when a setting
  # matches and 1 when none does.
  ask_git config --get-regexp \
    '^(extensions\.partialclone|remote\..*\.(promisor|partialclonefilter))$' >/dev/null 2>&1
  case $? in
    0) die "the Git configuration holds a partial-clone setting (extensions.partialclone, or promisor or partialclonefilter on a remote); a partial clone lacks objects this check needs" ;;
    1) ;;
    *) die "git could not read its configuration" ;;
  esac
  if [ -n "$upstream_arg" ]; then
    up_ref=$upstream_arg
    up=$(ask_git rev-parse -q --verify "$up_ref^{commit}" 2>/dev/null)
    case $? in
      0) ;;
      1) die "--upstream names no commit in this clone: $up_ref" ;;
      *) die "git could not resolve --upstream: $up_ref" ;;
    esac
  else
    up_ref=$(ask_git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)
    status=$?
    case "$status:$up_ref" in
      0:refs/remotes/origin/?*)
        up=$(ask_git rev-parse -q --verify "$up_ref^{commit}" 2>/dev/null)
        case $? in
          0) ;;
          1)
            up=""
            absent "$up_ref"
            ;;
          *) die "git could not resolve the branch refs/remotes/origin/HEAD names" ;;
        esac
        ;;
      0:*) die "refs/remotes/origin/HEAD names a reference outside refs/remotes/origin/" ;;
      # Not a symbolic reference: there is none of that name, or one that names no branch.
      1:*) absent refs/remotes/origin/HEAD "is not a symbolic reference, so it names no branch; git remote set-head origin <branch> records the default branch" ;;
      *) die "git could not say what refs/remotes/origin/HEAD names" ;;
    esac
  fi
  if [ -z "$up" ]; then
    ask_git config --get-regexp '^remote\.origin\.' >/dev/null 2>&1
    case $? in
      0) no_upstream_why=" (the remote origin has no default branch recorded in this clone; git remote set-head origin <branch> records one)" ;;
      1) ;;
      *) die "git could not read its configuration" ;;
    esac
    return 0
  fi
  [[ $up =~ $re_hash ]] || die "git did not print a commit hash for the upstream"
  # A clone without its full history cannot say what is merged. Only the answer "false"
  # lets the run go on.
  shallow=$(ask_git rev-parse --is-shallow-repository 2>/dev/null) ||
    die "git could not say whether the clone is shallow"
  case "$shallow" in
    false) ;;
    true) die "a shallow clone lacks the history a merge needs; the operator fetches the full history (git fetch --unshallow)" ;;
    *) die "git did not say whether the clone is shallow (Git 2.15 or later answers)" ;;
  esac
}

# --- What Git holds now: asked again after every step that can change it. ------
has_head=0     # 1 when HEAD names a commit
head_hash=""   # that commit
head_ref=""    # the branch HEAD is, refs/heads/<name>, or empty when HEAD is detached
on_branch=0    # 1 when HEAD is a branch
merge_head=""  # the first commit of a merge in progress, or empty
unmerged=""    # lines: each path Git lists as unmerged, as Git prints it
git_state() {
  local raw line path file
  # Git exits 0 for yes and 1 for no; any other exit is no answer.
  head_hash=$(ask_git rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)
  case $? in
    0)
      has_head=1
      [[ $head_hash =~ $re_hash ]] || die "git did not print a commit hash for HEAD"
      ;;
    1) has_head=0 head_hash="" ;;
    *) die "git could not say whether the repository has a commit" ;;
  esac
  head_ref=$(ask_git symbolic-ref -q HEAD 2>/dev/null)
  case "$?:$head_ref" in
    0:refs/heads/?*) on_branch=1 ;;
    0:*) die "HEAD names a reference outside refs/heads/" ;;
    1:*) on_branch=0 head_ref="" ;;
    *) die "git could not say whether HEAD is a branch" ;;
  esac
  if [ "$has_head" -eq 0 ]; then
    # No commit: a branch that is not born yet, in a new repository or an old one.
    # Anything else that names no commit is damage, and must not read as "no commit".
    [ "$on_branch" -eq 1 ] || die "HEAD names no commit and is not a branch; the repository is damaged"
    absent "$head_ref"
  fi
  merge_head=$(ask_git rev-parse -q --verify 'MERGE_HEAD^{commit}' 2>/dev/null)
  case $? in
    0) [[ $merge_head =~ $re_hash ]] || die "git did not print a commit hash for MERGE_HEAD" ;;
    1)
      merge_head=""
      file=$(ask_git rev-parse --git-path MERGE_HEAD 2>/dev/null) || die "git could not say where MERGE_HEAD is kept"
      case "$file" in
        /*) ;;
        *) file="$root/$file" ;;
      esac
      if [ -e "$file" ] || [ -L "$file" ]; then die "MERGE_HEAD exists and names no commit; the repository is damaged"; fi
      ;;
    *) die "git could not say whether a merge is in progress" ;;
  esac
  raw=$(ask_git -c core.quotePath=true ls-files --unmerged 2>/dev/null) ||
    die "git could not list the unmerged paths"
  unmerged=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      *"$tab"?*) path=${line#*"$tab"} ;;
      *) die "git printed an unmerged path this script cannot read" ;;
    esac
    case "${nl}${unmerged}" in
      *"${nl}${path}${nl}"*) ;;
      *) unmerged="${unmerged}${path}${nl}" ;;
    esac
  done < <(printf '%s\n' "$raw")
}

is_ancestor() { # <commit> <commit>
  ask_git merge-base --is-ancestor "$1" "$2" 2>/dev/null
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) die "git could not say whether $1 is an ancestor of $2" ;;
  esac
}

# upstream_state: sets $merged to yes (the upstream is an ancestor of HEAD), merging (a
# merge in progress holds it), or no. Call git_state first.
merged=no
upstream_state() {
  merged=no
  [ "$has_head" -eq 1 ] || return 0
  if is_ancestor "$up" HEAD; then
    merged=yes
  elif [ -n "$merge_head" ]; then
    if [ "$merge_head" = "$up" ] || is_ancestor "$up" "$merge_head"; then merged=merging; fi
  fi
}

# --- CL05: no path is unmerged, and the upstream is merged. --------------------
merge_reported=0  # 1 when `sync` has reported under CL05 a merge it did not make
cl05=0            # 1 when CL05 reported anything
check_merged() {
  local path why before=$count
  git_state
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ "$path" != "$LOG" ]; then
      add "$path" 1 "CL05 unmerged; resolve the conflict in it and run git add on it"
    elif [ -n "$merge_head" ]; then
      add "$LOG" 1 "CL05 unmerged; outside CI, make change-log regenerates the file and stages it (it is never resolved by hand)"
    else
      add "$LOG" 1 "CL05 unmerged, and no merge is in progress; the file is generated: run make change-log, then git add on it"
    fi
  done < <(printf '%s\n' "$unmerged")
  if [ -n "$up" ] && [ "$merge_reported" -eq 0 ]; then
    upstream_state
    if [ "$merged" = no ]; then
      if [ -n "$merge_head" ]; then
        why="another merge is in progress; complete it, then run make commit again"
      elif [ -n "$unmerged" ]; then
        why="unmerged paths stand in the way; resolve them, then run make commit again"
      elif [ "$has_head" -eq 1 ] && [ "$on_branch" -eq 0 ]; then
        why="no merge is made on a detached HEAD; switch to a branch and run make commit again"
      elif [ "$has_head" -eq 0 ]; then
        # There is nothing to commit the work to, so it is moved away.
        why="this branch has no commit; move away the work that is not committed, ignored files included (git status --ignored lists them), then run git merge $up and make commit again"
      else
        # `check`, which makes no merge. `sync` reports its own reasons.
        why="outside CI, commit the work in progress and run make commit, which merges the upstream into a clean working tree where the merge is trivial, and says what to do where it is not"
      fi
      add . 1 "CL05 the upstream $up is not merged into HEAD; $why"
    fi
  fi
  if [ "$count" -ne "$before" ] || [ "$merge_reported" -eq 1 ]; then cl05=1; fi
}

# --- CL04: the session is recorded, and no entry the base holds is missing. -----
check_recorded() {
  local base=HEAD staged status line st path name first="" recorded=0 changed="" gone=""
  if [ "$has_head" -eq 0 ] || [ "$cl05" -eq 1 ]; then return 0; fi
  [ -z "$up" ] || base=$up
  # Two questions, neither of which writes: what the index holds that the base does not,
  # and what the working tree holds that the index does not, untracked files included.
  # `git diff <base>` would answer both at once, and rewrites the index when a file's
  # time has changed and its content has not.
  staged=$(ask_git -c core.quotePath=true diff --cached --name-status --no-renames --no-ext-diff \
    "$base" -- 2>/dev/null) || die "git could not compare the index with $base"
  status=$(ask_git -c core.quotePath=true status --porcelain=v1 --untracked-files=all \
    --no-renames --ignore-submodules=dirty 2>/dev/null) ||
    die "git could not compare the working tree with the index"
  # A line of the first answer is a letter, a tab, and a path; D is a path the base holds
  # and the index does not.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      [A-Z]"$tab"?*) ;;
      *) die "git printed a change this script cannot read" ;;
    esac
    changed="${changed}${line:2}${nl}"
    [ "${line:0:1}" != D ] || gone="${gone}${line:2}${nl}"
  done < <(printf '%s\n' "$staged")
  # A line of the second is two letters, a space, and a path. The second letter is a
  # space when the working tree holds what the index holds, and D when the file is gone.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      ??" "?*) ;;
      *) die "git printed a status line this script cannot read" ;;
    esac
    [ "${line:1:1}" = " " ] || changed="${changed}${line:3}${nl}"
    [ "${line:1:1}" != D ] || gone="${gone}${line:3}${nl}"
  done < <(printf '%s\n' "$status")
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    # A name Git prints in quotes holds an unusual byte: it is no entry and not the list.
    case "$path" in
      "$LOG") ;;
      "$DIR"/*)
        case "${nl}${entries}" in
          *"${nl}${path#"$DIR"/}${nl}"*) recorded=1 ;;
        esac
        ;;
      *) [ -n "$first" ] || first=$path ;;
    esac
  done < <(printf '%s\n' "$changed")
  if [ -n "$first" ] && [ "$recorded" -eq 0 ]; then
    add "$DIR" 1 "CL04 files differ from $base (the first: $(shown "$first")) and no entry is new or changed against it; run make change-log-entry TITLE=\"...\" TAGS=\"...\" and fill in the entry it creates"
  fi
  # An entry is a record: one that the base holds is still there, in the index and in
  # the working tree, under its name. A name that fits the form of an entry is safe to
  # give to Git as <base>:<path>.
  first=""
  while IFS= read -r path; do
    name=${path#"$DIR"/}
    if [ "$DIR/$name" != "$path" ] || ! [[ $name =~ $re_entry ]]; then continue; fi
    case "${nl}${first}" in *"${nl}${path}${nl}"*) continue ;; esac
    first="${first}${path}${nl}"
    ask_git rev-parse -q --verify "$base:$path" >/dev/null 2>&1
    case $? in
      0) add "$path" 1 "CL04 an entry that $base holds is missing (deleted or renamed); an entry is a record: put it back as it was" ;;
      1) ;;
      *) die "git could not say whether $base holds an entry" ;;
    esac
  done < <(printf '%s\n' "$gone")
}
