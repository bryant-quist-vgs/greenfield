#!/usr/bin/env bash
# change_log_safe_test.sh — Tests for change_log.sh, built against contract v1:
# the conditions b to e of behavior 14, under which sync makes no merge,
# and what it then says to do. The merges sync makes are tested in
# change_log_sync_test.sh; the upstream and rules CL04 and CL05 in
# change_log_merge_test.sh.
#
# Coverage:
#   - Load-bearing (b, a clean working tree): a staged path, an edited tracked file, a
#     deleted one, an untracked file, and the list itself each stop the merge; ten paths
#     are named and all are counted.
#   - Load-bearing (c): a path marked assume-unchanged or skip-worktree, the list too.
#   - Load-bearing (e): an ignored file where the merge adds a path; an ignored file,
#     and a link, where it needs a directory; an ignored directory where it adds a file;
#     an ignored file in a directory the upstream replaces by a file; a stray file in the
#     directory of a submodule the upstream replaces by a file. With a conflict as well,
#     no merge by hand is offered.
#   - Load-bearing (in each of these): no git merge runs, the stand-in git proves it,
#     and the working tree, the index, and HEAD are as they were.
#   - Load-bearing (what is not in the way): an empty directory; a file the upstream
#     replaces by a directory and a directory it replaces by a file; a submodule the
#     upstream removes, whose directory Git leaves.
#   - Load-bearing (a merge by hand): git merge is offered for a conflict and for a Git
#     that cannot test, in a clean tree only; never by check or on a detached HEAD.
#   - Load-bearing (a refusal that is not foreseen): reported with Git's text and with
#     what was compared, and nothing more is claimed. Git does not reach into a
#     submodule.
#   - Limit: a rename upstream that changes only the case of a name is stopped where the
#     file system ignores case.
#   - Trust boundary: a path is a path, never a pattern, whatever the caller's
#     environment says.
#   - Capability boundary: Git is given only the commands the contract lists.
# Everything is built in a temporary directory. `make test` runs these tests, and
# an agent may run that target.
# shellcheck disable=SC2016 # the commands given to sh -c are written literally
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# The scripts under test are the placed ones: template/ lies beside this directory.
template=$(cd "$here/../template" && pwd -P) || exit 2
tool="$template/tools/change_log.sh"
# shellcheck source-path=SCRIPTDIR source=change_log_test_lib.sh
. "$here/change_log_test_lib.sh"
bad=1234567890123456789012345678901234567890
long=$(printf '%0300d' 0)
up_hash() { head_of origin/main; }
merges_made() { grep -c ' merge --no-commit ' "$shim_log"; }
dirt() { g status --porcelain --untracked-files=all; }
diverge() { put "$repo/l.txt" ours && recorded "$N1" "First change" && commit_all "our change"; }
# there <command...>: run the command in the upstream repository, where it commits by
# itself, and fetch into the clone.
there() { (cd "$up_repo" && "$@") && g fetch -q origin; }

# world <slug> <forward|merge>: both repositories hold d/x, t, au.txt, and keep.txt;
# then the upstream changes f.txt and au.txt and adds nd/a and solo. With merge, $repo
# has a commit of its own. Nothing is uncommitted.
world() {
  pair "$1"
  upstream sh -c 'mkdir d && echo x >d/x && echo t >t && echo au >au.txt && echo k >keep.txt'
  g merge -q --ff-only origin/main
  upstream sh -c 'echo theirs >f.txt && echo theirs >au.txt && mkdir nd && echo a >nd/a && echo s >solo'
  [ "$2" = forward ] || diverge
}
# refused <label> <regex of a CL05 line>: sync reports it, runs no merge, and every file
# of the working tree, the index, and HEAD are as they were.
refused() {
  local before made
  before=$(state) made=$(merges_made)
  rule "CL05 $1" CL05 "$2" sync
  unchanged "$1" "$before"
  is "$1: no merge was run" test "$(merges_made)" -eq "$made"
}
no_merge() { silent "$1: no merge by hand is offered" 'git merge [0-9a-f]'; }
commit_first='no merge was tried; commit the work in progress, then run make commit again$'
not_committed='CL05 not committed: staged, changed, deleted, or not tracked$'
# blocked <label> <path as reported>: condition e. The path is named, to be moved away.
blocked() {
  refused "$1" "^$2:1: CL05 in the way of a merge of the upstream, which would write over it, or delete it with all it holds\$"
  says "$1: what to do" "^\\.:1: CL05 the upstream $(up_hash) is not merged, and something stands where the merge adds a path or needs a directory \\([0-9]+ path\\(s\\), named above\\): a file Git ignores, which Git replaces without a word; a name that differs only in case from one the merge adds; or what the directory of a submodule holds; no merge was tried; move them away \\(out of the directory of a submodule, what it holds\\), then run make commit again\$"
  no_merge "$1"
}

# --- b: the working tree is clean ------------------------------------------------
for kind in forward merge; do
  world "dirty-$kind" "$kind"
  put "$repo/s.txt" staged && g add s.txt
  refused "a staged path ($kind)" "^s\\.txt:1: $not_committed"
  says "the work is to be committed ($kind)" "^\\.:1: CL05 the upstream $(up_hash) is not merged, and the gate merges only into a working tree with no uncommitted change \\(1 path\\(s\\), named above\\); $commit_first"
  no_merge "a staged path ($kind)"
  g rm -q --cached s.txt && rm "$repo/s.txt" && put "$repo/keep.txt" edited
  refused "an edited tracked file, which the upstream does not change ($kind)" "^keep\\.txt:1: $not_committed"
  g checkout -q -- keep.txt && rm "$repo/t"
  refused "a deleted tracked file ($kind)" "^t:1: $not_committed"
  g checkout -q -- t && put "$repo/scratch.txt" scratch
  refused "an untracked file ($kind)" "^scratch\\.txt:1: $not_committed"
  no_merge "an untracked file ($kind)"
  rm "$repo/scratch.txt"
  clean "with nothing uncommitted, the merge is made ($kind)" sync
done
# The list is a path like any other; and of twelve paths ten are named.
world list forward
recorded "$N1" "First change"
refused "the list and an entry that are not committed" "^docs/change_log\\.md:1: $not_committed"
says "both are counted" "\\(2 path\\(s\\), named above\\); $commit_first"
world many merge
for n in 1 2 3 4 5 6 7 8 9 10 11 12; do put "$repo/s$n.txt" work; done
refused "twelve untracked files" "^\\.:1: CL05 .* \\(12 path\\(s\\), the first 10 named above\\); $commit_first"
is "ten of them are named" test "$(printf '%s\n' "$output" | grep -c "^s[0-9]*\\.txt:1: $not_committed")" -eq 10

# --- c: no path is marked ----------------------------------------------------------
for kind in forward merge; do
  for mark in assume-unchanged skip-worktree; do
    world "$mark-$kind" "$kind"
    g update-index "--$mark" au.txt && put "$repo/au.txt" localau
    is "git status says nothing of the marked file ($mark, $kind)" test -z "$(dirt)"
    refused "a path marked $mark ($kind)" '^au\.txt:1: CL05 marked assume-unchanged or skip-worktree in the index: Git does not look at this file$'
    says "the run says how to clear the mark ($mark, $kind)" "^\\.:1: CL05 the upstream $(up_hash) is not merged, and Git cannot say that the working tree is clean while a path is marked \\(1 path\\(s\\), named above\\); no merge was tried; clear the mark \\(git update-index --no-assume-unchanged <path>, or --no-skip-worktree <path>\\), then run make commit again\$"
    no_merge "a marked path ($mark, $kind)"
    is "the file marked $mark holds its bytes ($kind)" test "$(cat "$repo/au.txt")" = localau
    g update-index "--no-$mark" au.txt && put "$repo/au.txt" au
    clean "with the mark cleared, the merge is made ($mark, $kind)" sync
  done
done
world marked-list merge
g update-index --assume-unchanged "$LOG"
refused "the list, marked" '^docs/change_log\.md:1: CL05 marked assume-unchanged or skip-worktree'
with ASK=-v NTH=2 -- sync
exits "git fails the second listing of the marked paths" 2

# --- e: nothing stands where the merge adds a path -----------------------------------
for kind in forward merge; do
  # Each of these is ignored, so the tree is clean, and Git itself would say nothing.
  pair "ignored-$kind"
  upstream sh -c 'echo theirs >x.log && git add -f x.log && echo theirs >build && mkdir cache linked && echo t >cache/a && echo t >linked/a && echo e >empty'
  [ "$kind" = forward ] || diverge
  mkdir -p "$repo/.git/info" "$repo/build" "$repo/empty" "$work/elsewhere-$kind"
  printf '%s\n' build/ cache linked >"$repo/.git/info/exclude"
  put "$repo/x.log" mine && put "$repo/build/object" mine && put "$repo/cache" mine && ln -s "$work/elsewhere-$kind" "$repo/linked"
  is "the working tree is clean to Git ($kind)" test -z "$(dirt)"
  blocked "an ignored file where the merge adds one ($kind)" 'x\.log'
  says "an ignored directory where the merge adds a file ($kind)" '^build/:1: CL05 in the way of a merge'
  says "an ignored file where the merge needs a directory ($kind)" '^cache:1: CL05 in the way of a merge'
  says "a link where the merge needs a directory ($kind)" '^linked:1: CL05 in the way of a merge'
  says "the four are counted ($kind)" '\(4 path\(s\), named above\)'
  silent "an empty directory is not in the way ($kind)" '^empty'
  rm -r "$repo/x.log" "$repo/build" "$repo/cache" "$repo/linked"
  clean "with them moved away, the merge is made, over the empty directory ($kind)" sync
  is "the upstream's files are written ($kind)" test "$(cat "$repo/x.log" "$repo/build" "$repo/cache/a" "$repo/empty" | tr '\n' ' ')" = 'theirs theirs t e '
  isnt "nothing is written through the link ($kind)" test -e "$work/elsewhere-$kind/a"

  # The upstream replaces a directory by a file and a file by a directory. What the
  # merge itself removes is not in its way; an ignored file in the directory is.
  pair "shapes-$kind"
  upstream sh -c 'mkdir d && echo x >d/x && echo t >t'
  g merge -q --ff-only origin/main
  upstream sh -c 'git rm -q -r d t && echo file >d && mkdir t && echo x >t/x'
  [ "$kind" = forward ] || diverge
  put "$repo/d/keep.log" mine
  blocked "an ignored file in a directory the upstream replaces by a file ($kind)" 'd/'
  rm "$repo/d/keep.log"
  clean "a directory replaced by a file, and a file by a directory ($kind)" sync
  is "both are as the upstream has them ($kind)" test "$(cat "$repo/d" "$repo/t/x" | tr '\n' ' ')" = 'file x '

  # A submodule that was never set up: its directory holds a stray file and no
  # repository, and git status says nothing of it. Replaced by a file, Git deletes the
  # directory with all it holds; removed, Git leaves the directory.
  for what in replace remove; do
    pair "module-$what-$kind"
    there sh -c 'git update-index --add --cacheinfo "160000,$1,sub" && git commit -q -m "a submodule"' sh "$bad"
    g merge -q --ff-only origin/main
    there sh -c 'git update-index --force-remove sub && { [ "$1" = remove ] || { echo file >sub && git add sub; }; } && git commit -q -m "no submodule"' sh "$what"
    [ "$kind" = forward ] || diverge
    mkdir -p "$repo/sub" && put "$repo/sub/stray.txt" mine
    is "git status says nothing of the stray file ($what, $kind)" test -z "$(dirt)"
    if [ "$what" = replace ]; then
      blocked "a stray file in the directory of a submodule the upstream replaces by a file ($kind)" 'sub/'
      rm "$repo/sub/stray.txt"
      clean "with the directory emptied, the merge is made ($kind)" sync
      is "the upstream's file stands where the submodule was ($kind)" test "$(cat "$repo/sub")" = file
    else
      run sync
      says "a submodule the upstream removes: the merge is made ($kind)" '^change-log: (merged|moved the branch forward to) [0-9a-f]{40} '
      isnt "the index no longer holds the submodule ($kind)" g ls-files --error-unmatch sub
      is "Git leaves its directory, and the stray file holds its bytes ($kind)" test "$(cat "$repo/sub/stray.txt")" = mine
    fi
  done

  # A path is a path, never a pattern, whatever the caller's environment says.
  pair "literal-$kind"
  upstream sh -c 'echo theirs >"a*" && echo theirs >":x"'
  [ "$kind" = forward ] || diverge
  mkdir -p "$repo/.git/info" "$repo/:x" "$repo/a*" && put "$repo/.git/info/exclude" ':x' && put "$repo/:x/mine" mine
  before=$(state)
  with GIT_LITERAL_PATHSPECS=0 GIT_GLOB_PATHSPECS=1 -- sync
  exits "an ignored directory whose name could be read as a pattern ($kind)" 1
  says "that directory is named as in the way ($kind)" '^:x/:1: CL05 in the way of a merge'
  unchanged "a directory whose name could be read as a pattern ($kind)" "$before"
  rm -r "$repo/:x"
  with GIT_LITERAL_PATHSPECS=0 GIT_GLOB_PATHSPECS=1 -- sync
  exits "a path that holds a pattern character, over an empty directory ($kind)" 0
  is "the upstream's files are written ($kind)" test "$(cat "$repo/a*" "$repo/:x" | tr '\n' ' ')" = 'theirs theirs '
done

# --- A merge by hand is offered only where following the words loses nothing ------
pair advice
upstream sh -c 'echo theirs >f.txt && mkdir out && echo theirs >out/x.log && git add -f out/x.log'
put "$repo/f.txt" ours && diverge
mkdir "$repo/out" && put "$repo/out/x.log" mine
blocked "a conflict, and an ignored file where the merge adds one" 'out/x\.log'
silent "the conflict is not reported before the file is moved away" 'conflicts'
is "the ignored file holds its bytes" test "$(cat "$repo/out/x.log")" = mine
rm -r "$repo/out"
refused "a conflict, nothing in the way" '^f\.txt:1: CL05 a merge of the upstream conflicts in this file$'
says "a merge by hand is offered for the conflict" "the merge conflicts \\(1 path\\(s\\), named above\\); no merge was tried; run git merge $(up_hash), resolve every conflicted path other than $LOG, and run make commit again\$"
put "$repo/scratch.txt" scratch
with ASK=merge-tree -- sync
says "a Git that cannot test, over work that is not committed" "$commit_first"
no_merge "a Git that cannot test, over work that is not committed"
rm "$repo/scratch.txt"
rule "CL05 check: the merge is left to make commit" CL05 "is not merged into HEAD; outside CI, commit the work in progress and run make commit, which merges the upstream into a clean working tree where the merge is trivial, and says what to do where it is not\$"
no_merge "check"
g checkout -q --detach
for verb in check sync; do
  rule "CL05 on a detached HEAD ($verb)" CL05 'no merge is made on a detached HEAD; switch to a branch and run make commit again$' "$verb"
  no_merge "a detached HEAD ($verb)"
done
# A branch with no commit: there is nothing to commit the work to.
g checkout -q main && g checkout -q --orphan fresh
for verb in check sync; do
  rule "CL05 on a branch with no commit ($verb)" CL05 "this branch has no commit; move away the work that is not committed, ignored files included \\(git status --ignored lists them\\), then run git merge $(up_hash) and make commit again\$" "$verb"
done

# --- Limit: two names that differ only in case -------------------------------------
pair case
upstream put Notes.txt notes
g merge -q --ff-only origin/main
upstream git mv Notes.txt notes.txt
if [ "$(g config core.ignorecase)" = true ]; then
  blocked "a rename upstream that changes only the case of a name" 'notes\.txt'
else
  clean "a rename upstream that changes only the case of a name" sync
  printf 'SKIP: this file system tells Notes.txt from notes.txt; the limit is not met here\n'
fi

# --- A refusal that was not foreseen; Git does not reach into a submodule ---------
for kind in forward merge; do
  world "locked-$kind" "$kind"
  : >"$repo/.git/index.lock"
  before=$(state) made=$(merges_made)
  rule "CL05 a merge Git refuses ($kind)" CL05 "^\\.:1: CL05 the upstream $(up_hash) is not merged, and git refused the merge \\(exit [0-9]+\\); its message follows; HEAD, MERGE_HEAD, the index, and the answer of git status are the same as before the merge was tried, and nothing else was compared; act on the message and run make commit again\$" sync
  unchanged "a merge Git refuses ($kind)" "$before"
  is "the merge was run, and Git refused it ($kind)" test "$(merges_made)" -eq "$((made + 1))"
  says "Git's refusal is shown ($kind)" '^    git: (error|fatal): '
  silent "nothing is claimed of the working tree ($kind)" 'as they were|as it was'
  no_merge "a refusal ($kind)"
  rm "$repo/.git/index.lock"
  clean "with the lock gone, the merge is made ($kind)" sync
done
# submodule.recurse: Git, stopping part-way through a merge, would revert the work in a
# submodule, which git status does not list here.
pair recurse
upstream sh -c 'git init -q sub && (cd sub && echo s >s.txt && git add s.txt && git commit -q -m sub) && printf "[submodule \"sub\"]\n\tpath = sub\n\turl = ./sub\n" >.gitmodules' 2>/dev/null
g merge -q --ff-only origin/main
rmdir "$repo/sub" 2>/dev/null
cp -R "$up_repo/sub" "$repo/sub"
g config submodule.recurse true && g config submodule.sub.url "$repo/sub" && g config submodule.sub.active true
there sh -c 'echo theirs >a.txt && git add a.txt && git update-index --add --cacheinfo "100644,$(git hash-object -w f.txt),m/$1" && git commit -q -m "a path no file system takes"' sh "$long"
diverge 2>/dev/null
put "$repo/sub/s.txt" work
run sync
exits "a merge Git cannot finish, with submodule.recurse set" 2
is "the work in the submodule is as it was" test "$(cat "$repo/sub/s.txt")" = work

# --- Capability boundary: the commands Git was given -----------------------------
is "the stand-in git saw the commands of these tests" grep -q ' merge-tree --write-tree ' "$shim_log"
only_git_commands "every run of these tests" "$ASKS_SYNC"
isnt "git was never given a verb that contacts a remote or rewrites work" grep -Eq ' (fetch|pull|push|commit|rebase|reset|stash|checkout|switch|restore|clean|rm|mv|update-index|update-ref|submodule|maintenance|gc) ' "$shim_log"

printf 'change_log_safe_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
