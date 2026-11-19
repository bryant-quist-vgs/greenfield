#!/usr/bin/env bash
# change_log_sync_test.sh — Tests for change_log.sh, built against contract v1:
# the merge that sync makes. The conditions under which it makes none are
# tested in change_log_safe_test.sh; the upstream and rules CL04 and CL05 in
# change_log_merge_test.sh; the entries, the tag file, and the list in
# change_log_test.sh; the verbs new and render in change_log_new_test.sh.
#
# Coverage:
#   - Load-bearing (the ordinary session): the work is made and not committed, and no
#     merge is made; the work is committed, the upstream has diverged with only the list
#     in common, and the gate merges, regenerates and stages the list; git commit
#     --no-edit completes the merge, and a second run passes. A branch with no commit of
#     its own is moved forward. The files that changed, and no others.
#   - Load-bearing (sync merges only where the merge is trivial): a conflict in
#     docs/change_log.md alone is regenerated and staged; a conflict in another file and
#     a Git that cannot test a merge leave the tree, the index, and HEAD alone.
#   - Load-bearing (what happened is verified): a merge Git cannot finish writing is exit
#     2 with the paths that changed, never a refusal.
#   - Load-bearing (Git is pinned): branch.<name>.mergeOptions has no effect; no hook, no
#     file-system monitor, no maintenance process, no recorded resolution, no stash.
#   - Load-bearing (a merge in progress): no second merge; the list is staged; outside a
#     merge it is not.
#   - Trust boundary: a hostile path in a conflict is printed without its control
#     characters.
#   - Capability boundary: check writes nothing in every state; Git is given only the
#     commands the contract lists, and add for no path but the list.
# Everything is built in a temporary directory. `make test` runs these tests, and
# an agent may run that target.
# shellcheck disable=SC2016 # sed expressions and hostile text are written literally
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# The scripts under test are the placed ones: template/ lies beside this directory.
template=$(cd "$here/../template" && pwd -P) || exit 2
tool="$template/tools/change_log.sh"
# shellcheck source-path=SCRIPTDIR source=change_log_test_lib.sh
. "$here/change_log_test_lib.sh"
ODD="b${esc}[31m.txt"
up_hash() { head_of origin/main; }
merges_made() { grep -c ' merge --no-commit ' "$shim_log"; }
dirt() { g status --porcelain --untracked-files=all; }
hooks() { # <marker>: hooks in $repo that would leave the marker
  mkdir -p "$repo/.git/hooks"
  for hook in post-merge post-checkout reference-transaction post-index-change; do
    printf '%s\n' '#!/bin/sh' "touch '$1'" >"$repo/.git/hooks/$hook"
    chmod +x "$repo/.git/hooks/$hook"
  done
}
# diverge: a commit of our own in $repo, with an entry, so that the upstream is merged
# and not moved forward to.
diverge() { put "$repo/l.txt" ours && recorded "$N1" "First change" && commit_all "our change"; }

# --- The ordinary session: the work is committed, and then the gate merges --------
pair usual
upstream recorded "$N2" "Second change"
put "$repo/w.txt" work
run new --title "First change" --tags feature --at 2026-03-01-101500
edit "$DIR/$E1" 's/^<what changed.*>$/The gate checks the change log./; s/^<why.*>$/A change that is not recorded cannot be found again./'
writes_nothing "check, the ordinary session" check
before=$(state)
rule "the work is not committed: no merge is made" CL05 "^\\.:1: CL05 the upstream $(up_hash) is not merged, and the gate merges only into a working tree with no uncommitted change \\(3 path\\(s\\), named above\\); no merge was tried; commit the work in progress, then run make commit again\$" sync
unchanged "the work that is not committed" "$before"
is "no merge was run over it" test "$(merges_made)" -eq 0
commit_all "our work"
before=$(files) refs=$(g for-each-ref | grep -v 'refs/heads/main$') branch=$(head_of HEAD)
clean "the work is committed: the gate merges" sync
changed_files "the upstream's entry and the list changed, and no other file" "$before" "$DIR/$E2" "$LOG"
is "the list holds our entry" grep -q "change_log/$E1" "$repo/$LOG"
is "the list holds the upstream's entry" grep -q "change_log/$E2" "$repo/$LOG"
is "no reference is touched" test "$refs" = "$(g for-each-ref | grep -v 'refs/heads/main$')"
says "sync says it merged, and what completes the merge" "^change-log: merged $(up_hash) \\(refs/remotes/origin/main\\) into the index and the working tree; not committed: when make commit passes, git commit --no-edit completes the merge\$"
is "the merge is in progress" test "$(head_of MERGE_HEAD)" = "$(up_hash)"
is "HEAD has not moved" test "$(head_of HEAD)" = "$branch"
says "sync says it staged the list" "^change-log: $LOG staged, for the merge in progress\$"
is "nothing is left outside the index" test -z "$(dirt | grep -v '^[MA]  ')"
is "no stash was made" test -z "$(g stash list)"
is "git commit --no-edit completes the merge" g commit -q --no-edit
is "that commit merges the upstream" test "$(head_of 'HEAD^2')" = "$(up_hash)"
is "and holds the merge alone: its first parent is our commit" test "$(head_of 'HEAD^1')" = "$branch"
clean "a second run passes" sync
silent "and makes no merge" 'merged [0-9a-f]|moved the branch'
is "and leaves the working tree clean" test -z "$(dirt)"
# A branch with no commit of its own is moved forward, and nothing is left to complete.
pair forward
upstream recorded "$N2" "Second change"
before=$(files)
clean "a branch with no commit of its own" sync
says "sync says it moved the branch forward" "^change-log: moved the branch forward to $(up_hash) \\(refs/remotes/origin/main\\): it had no commit of its own, and nothing is left to complete\$"
changed_files "the upstream's entry and the list changed, and no other file (forward)" "$before" "$DIR/$E2" "$LOG"
is "HEAD is the upstream commit" test "$(head_of HEAD)" = "$(up_hash)"
isnt "moving forward leaves no merge in progress" g rev-parse -q --verify MERGE_HEAD
is "and nothing to commit" test -z "$(dirt)"
# The list is staged, so the merge the tool made can also be abandoned.
pair abandon
upstream recorded "$N2" "Second change"
diverge
clean "sync merges" sync
is "the merge can be abandoned" g merge --abort
isnt "and then no merge is in progress" g rev-parse -q --verify MERGE_HEAD
is "and the working tree is clean again" test -z "$(dirt)"

# --- Moved forward: no hook, no file-system monitor, no maintenance process -----
pair pinned
hooks "$work/HOOKED"
printf '%s\n' '#!/bin/sh' "touch '$work/MONITORED'" >"$work/fsmon" && chmod +x "$work/fsmon"
upstream put u.txt theirs
g config core.fsmonitor "$work/fsmon"
with GIT_TRACE="$work/trace" -- sync
exits "sync moves the branch forward" 0
is "the upstream's file is in the working tree" test -f "$repo/u.txt"
is "the trace saw the merge" grep -q 'merge --no-commit' "$work/trace"
isnt "no maintenance process was started" grep -q 'maintenance' "$work/trace"
isnt "no hook ran" test -e "$work/HOOKED"
isnt "no file-system monitor ran" test -e "$work/MONITORED"
git -C "$repo" update-ref refs/heads/probe HEAD
is "the hooks of this test do run when they are not switched off" test -e "$work/HOOKED"
git -C "$repo" status >/dev/null 2>&1
is "the monitor of this test does run when it is not switched off" test -e "$work/MONITORED"

# --- A merge with no conflict; then a merge in progress -------------------------
pair plain
hooks "$work/HOOKED2"
upstream put u.txt theirs
diverge
made=$(merges_made)
writes_nothing "check, a merge to make" check
clean "sync merges" sync
is "the merge is in progress" test "$(head_of MERGE_HEAD)" = "$(up_hash)"
is "the upstream's file is staged" g ls-files --error-unmatch u.txt
is "one merge was made" test "$(merges_made)" -eq "$((made + 1))"
isnt "no hook ran for a merge" test -e "$work/HOOKED2"
silent "a list that is as the index holds it is not staged" 'staged'
writes_nothing "check, a merge in progress" check
exits "CL05 a merge of the upstream in progress, nothing unmerged" 0
# A merge found in progress: no second merge, and the list is staged when it changes.
entry 2026-03-03-000000-third "Third" fix
clean "sync again, the merge in progress" sync
says "sync says no merge was started" '^change-log: a merge is in progress; no merge was started$'
is "sync does not merge again" test "$(merges_made)" -eq "$((made + 1))"
is "the list, regenerated in a merge, is staged" g diff --quiet -- "$LOG"
is "and it holds the new entry" grep -q 'change_log/2026-03-03-000000-third.md' "$repo/$LOG"

# --- A conflict in docs/change_log.md alone: regenerated and staged -------------
pair logs
g config rerere.enabled true
upstream sh -c 'echo theirs >u.txt'
upstream recorded "$N2" "Second change"
diverge
recorded 2026-03-03-000000-third "Third" && commit_all "a second change of ours"
writes_nothing "check, a merge that conflicts in the list" check
clean "sync merges where only the list conflicts" sync
says "sync says it staged the list" "^change-log: $LOG staged, for the merge in progress\$"
is "the list holds the three entries" test "$(grep -c 'change_log/2026' "$repo/$LOG")" -eq 3
isnt "the list holds no conflict marker" grep -Eq '^(<<<<<<<|>>>>>>>)' "$repo/$LOG"
is "nothing is unmerged" test -z "$(g ls-files --unmerged)"
is "the list is staged as it stands" g diff --quiet -- "$LOG"
is "the upstream's file is as Git merged it" test "$(cat "$repo/u.txt")" = theirs
is "the merge is in progress" g rev-parse -q --verify MERGE_HEAD
isnt "no resolution was recorded" test -n "$(ls "$repo/.git/rr-cache" 2>/dev/null)"

# --- A conflict in another file: nothing is changed, the paths are named --------
conflict() { # <slug>: both sides change f.txt and add $ODD, and each records an entry
  pair "$1"
  upstream sh -c "echo theirs >f.txt; echo theirs >'$ODD'"
  upstream recorded "$N2" "Second change"
  put "$repo/f.txt" ours && put "$repo/$ODD" ours && recorded "$N1" "First change" && commit_all "our change"
}
conflict other
writes_nothing "check, a merge that conflicts in another file" check
before=$(state) made=$(merges_made)
rule "CL05 a conflict in another file" CL05 '^f.txt:1: CL05 a merge of the upstream conflicts in this file$' sync
says "the merge is left to a person, and the command is given" "^\\.:1: CL05 the upstream $(up_hash) is not merged, and the merge conflicts \\(2 path\\(s\\), named above\\); no merge was tried; run git merge $(up_hash), resolve every conflicted path other than $LOG, and run make commit again\$"
says "a hostile path is named without its control character" '^b\?\[31m\.txt:1: CL05 a merge of the upstream conflicts'
silent "a control character from a path does not reach the output" "$esc"
silent "the list is not named as a conflict" "^$LOG:1: CL05"
silent "CL04 is not applied" ' CL04 '
unchanged "a merge that conflicts" "$before"
is "no merge was run that conflicts" test "$(merges_made)" -eq "$made"

# --- branch.<name>.mergeOptions has no effect ------------------------------------
n=0
for options in --squash "-s ours" --no-ff; do
  for kind in forward merge; do
    n=$((n + 1))
    pair "options-$n-$kind"
    upstream put u.txt theirs
    [ "$kind" = forward ] || diverge
    g config branch.main.mergeOptions "$options"
    clean "sync with branch.main.mergeOptions $options ($kind)" sync
    is "the upstream's file is there ($options, $kind)" test "$(cat "$repo/u.txt")" = theirs
    isnt "nothing was squashed ($options, $kind)" test -e "$repo/.git/SQUASH_MSG"
    if [ "$kind" = forward ]; then
      is "the branch moved forward ($options)" test "$(head_of HEAD)" = "$(up_hash)"
    else
      is "the upstream is being merged ($options)" test "$(head_of MERGE_HEAD)" = "$(up_hash)"
    fi
  done
done
pair options-name
upstream put u.txt theirs
g checkout -q -b 'a=b.c' && diverge
g config 'branch.a=b.c.mergeOptions' --squash
clean "sync on a branch whose name holds = and a dot" sync
is "the upstream is being merged" test "$(head_of MERGE_HEAD)" = "$(up_hash)"

# --- Git stops part-way -----------------------------------------------------------
# The upstream holds a path no file system takes: Git writes some files and stops.
long=$(printf '%0300d' 0)
for kind in forward merge; do
  pair "half-$kind"
  (cd "$up_repo" && put a.txt theirs && put z.txt theirs && git add a.txt z.txt &&
    git update-index --add --cacheinfo "100644,$(git hash-object -w f.txt),m/$long" &&
    git -c core.hooksPath=/dev/null commit -q -m "a path no file system takes") && g fetch -q origin
  [ "$kind" = forward ] || diverge
  run sync
  exits "a merge Git cannot finish writing ($kind)" 2
  says "the run says Git stopped part-way, and names what changed ($kind)" "^change_log: git stopped part-way through the merge of $(up_hash) \\(exit [0-9]+\\) and left changes behind:.* a\\.txt[,;]"
  says "the run undoes nothing ($kind)" 'this run undoes nothing: see git status$'
  says "Git's own text is shown ($kind)" '^change_log: git: error: unable to create file m/'
  silent "it is not called a refusal ($kind)" 'refused|CL05'
  is "the list is not generated again on an exit 2 ($kind)" g diff --quiet -- "$LOG"
done

# --- A merge in progress with unmerged paths, made by hand ----------------------
conflict hand
g config rerere.enabled true
g merge -q --no-commit origin/main >/dev/null 2>&1
is "a merge by hand does record a resolution: the setting of this test works" test -n "$(ls "$repo/.git/rr-cache" 2>/dev/null)"
made=$(merges_made)
writes_nothing "check, unmerged paths" check
rule "CL05 an unmerged path" CL05 '^f.txt:1: CL05 unmerged; resolve the conflict in it and run git add on it$'
says "CL05 the list, unmerged, is not resolved by hand" "^$LOG:1: CL05 unmerged; outside CI, make change-log regenerates the file and stages it"
rule "sync with unmerged paths" CL05 '^f.txt:1: CL05 unmerged' sync
says "sync says no merge was started" '^change-log: a merge is in progress; no merge was started$'
is "sync starts no merge" test "$(merges_made)" -eq "$made"
is "sync stages the list" test -z "$(g ls-files --unmerged -- "$LOG")"
is "sync stages no other path" test -n "$(g ls-files --unmerged -- f.txt)"
is "the list holds both entries" test "$(grep -c 'change_log/2026' "$repo/$LOG")" -eq 2
put "$repo/f.txt" resolved && put "$repo/$ODD" resolved && g add -A
clean "sync once the paths are resolved" sync

# --- Another merge in progress; a detached HEAD; a Git that cannot test ---------
pair another
upstream put u.txt theirs
g checkout -q -b side && ours put s.txt side
g checkout -q main && ours put l.txt ours
g merge -q --no-commit --no-ff side >/dev/null 2>&1
made=$(merges_made)
rule "CL05 another merge in progress" CL05 'is not merged into HEAD; another merge is in progress; complete it' sync
is "sync starts no second merge" test "$(merges_made)" -eq "$made"
pair detached
upstream put u.txt theirs
g checkout -q --detach
before=$(state)
rule "CL05 no merge on a detached HEAD" CL05 'is not merged into HEAD; no merge is made on a detached HEAD' sync
unchanged "a detached HEAD" "$before"
pair old-git
upstream put u.txt theirs
ours put l.txt ours
before=$(state) made=$(merges_made)
with ASK=merge-tree -- sync
exits "a Git without merge-tree --write-tree" 1
says "CL05 the merge cannot be tested" '^\.:1: CL05 the upstream [0-9a-f]{40} is not merged, and this Git could not test the merge \(git merge-tree --write-tree, Git 2\.38 or later\); no merge was tried; look at git status --ignored, because a merge writes over an ignored file without a word; then run git merge [0-9a-f]{40}, resolve every conflicted path other than docs/change_log\.md, and run make commit again$'
unchanged "a merge that cannot be tested" "$before"
is "no merge was run that was not tested" test "$(merges_made)" -eq "$made"

# --- What a merge can bring: a link in place of the list; another tool ----------
pair linked
upstream sh -c 'rm docs/change_log.md && ln -s ../../outside.md docs/change_log.md'
run sync
exits "a merge that makes the list a symbolic link" 2
says "the failure says what the run had done" "^change_log: before this failure the run had moved the branch forward to $(up_hash)\$"
isnt "nothing is written through the link" test -e "$work/outside.md"
pair tool
upstream sh -c 'mkdir tools && cp "$1"/change_log* tools/' sh "$template/tools"
g merge -q --ff-only origin/main
upstream sh -c 'echo "# another version" >>tools/change_log_tags.awk'
placed_tool() { output=$(bash "$repo/tools/change_log.sh" --repo "$repo" sync 2>&1 </dev/null); status=$?; }
placed_tool
exits "a merge that changes the tool itself" 2
says "the run says to run the merged tool" '^change_log: the merge changed the files of this tool .*run make change-log again'
placed_tool
exits "the next run, with the merged tool" 0

# --- Fails closed: a Git question of the merge that fails is exit 2 --------------
pair questions
upstream recorded "$N2" "Second change"
diverge
asked sync diff-tree
asked sync diff-tree 'Q\0path\0'
asked sync --porcelain=v1
asked sync --porcelain=v1 'XYpath'
asked sync HEAD
asked sync -v
asked sync -v 'x'
before=$(state)
with ASK=-s NTH=1 -- sync
exits "git fails the listing of the index" 2
unchanged "a question that fails before the merge" "$before"
# After the merge, a question that fails says that a merge was run.
with ASK=--porcelain=v1 NTH=2 -- sync
exits "git fails the second answer about the working tree" 2
says "a failure after the merge says that a merge was run" "^change_log: before this failure the run had run a merge of $(up_hash), whose result it had not read\$"
conflict questions-add
g merge -q --no-commit origin/main >/dev/null 2>&1
asked sync add
pair questions-wrote
upstream recorded "$N2" "Second change"
diverge
asked sync add
says "a failure after a write says what was written" "^change_log: before this failure the run had started a merge of $(up_hash), which is in the index and not committed, and written $LOG"

# --- Capability boundary: the commands Git was given -----------------------------
is "the stand-in git saw the commands of these tests" grep -q ' merge-tree --write-tree ' "$shim_log"
only_git_commands "every run of these tests" "$ASKS_SYNC"
isnt "git was never given a verb that contacts a remote or rewrites work" grep -Eq ' (fetch|pull|push|commit|rebase|reset|stash|checkout|switch|restore|clean|rm|mv|update-index|update-ref|maintenance|gc) ' "$shim_log"

printf 'change_log_sync_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
