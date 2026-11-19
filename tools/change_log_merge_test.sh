#!/usr/bin/env bash
# change_log_merge_test.sh — Tests for change_log.sh, built against contract v1:
# the upstream, what Git holds, and rules CL04 and CL05. The merge that
# sync makes is tested in change_log_sync_test.sh; the entries, the tag file, and the
# list in change_log_test.sh; the verbs new and render in change_log_new_test.sh.
#
# Coverage:
#   - Load-bearing (CL04): a change with no entry; with a new entry; with an edited entry;
#     with an entry the base holds unchanged; an untracked file; an ignored file; only
#     the list or the tag file changed; the base is the upstream when one is known; an
#     entry the base holds that is deleted, renamed, or dropped from the index.
#   - Load-bearing (CL05): the upstream not merged; merged; an unmerged path with and
#     without an upstream, in and outside a merge; an unmerged entry is read once.
#   - Load-bearing (the upstream): origin/HEAD; --upstream; no upstream and the hint; a
#     reference that is damaged is not read as absent; a shallow and a partial clone.
#   - Load-bearing (fails closed): each Git question that fails, and each answer the
#     script cannot read, is exit 2.
#   - Trust boundary: a hostile path in a change is printed without its control
#     characters.
#   - Capability boundary: check writes nothing in every state above; Git is given only
#     the commands the contract lists.
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
bad=1234567890123456789012345678901234567890

# --- No commit yet: CL04 is not applied -------------------------------------
repo="$work/unborn"
mkdir -p "$repo/docs" && g init -q && tags_file
{ empty_log && printf 'No entries yet.\n'; } >"$repo/$LOG"
put "$repo/x.txt" x
writes_nothing "check, no commit yet" check
exits "check, no commit yet" 0
clean "sync, no commit yet" sync
says "no commit yet: summary line" '^change-log: 0 entry\(ies\) checked, no upstream known, no violations$'
asked check for-each-ref
with GIT_TRACE=1 GIT_TRACE2=1 -- check
exits "no commit yet, with Git's trace switched on by the caller" 0
new_repo orphan
g checkout -q --orphan fresh
clean "a branch that is not born yet, in a repository with commits" check

# --- No upstream: the base of CL04 is HEAD -----------------------------------
new_repo cl04
clean "sync, no upstream" sync
put "$repo/f.txt" changed
writes_nothing "check, a change with no entry" check
rule "CL04 a tracked change with no entry" CL04 '^docs/change_log:1: CL04 files differ from HEAD \(the first: f.txt\) and no entry is new or changed'
says "CL04 says what to run" 'make change-log-entry TITLE="\.\.\." TAGS="\.\.\."'
recorded "$N1" "First change"
clean "CL04 a change with a new entry" check
says "an entry that Git does not track yet is named" "^change-log: 1 entry file\\(s\\) not tracked by Git yet \\(the first: $DIR/$E1\\); add them to the commit, with $LOG\$"
commit_all "recorded"
clean "CL04 nothing differs from HEAD" check
silent "a tracked entry is not named" 'not tracked by Git yet'
put "$repo/new.txt" x
rule "CL04 an untracked file, and an entry that HEAD holds unchanged" CL04 'the first: new.txt'
edit "$DIR/$E1" 's/^The gate checks.*/The gate checks more./'
clean "CL04 a change with an edited entry" check
g checkout -q -- "$DIR/$E1"
mkdir -p "$repo/.git/info" && printf 'new.txt\n' >"$repo/.git/info/exclude"
clean "CL04 an ignored file" check
tags_file "$ROWS"
clean "CL04 only the tag file changed" check
put "$repo/f.txt" again
rule "CL04 the tag file is not an entry" CL04 'the first: f.txt'
g checkout -q -- f.txt
printf 'by hand\n' >>"$repo/$LOG"
rule "only the list changed" CL03 "never edited by hand"
silent "CL04 does not count the list" ' CL04 '
g checkout -q -- "$LOG"
put "$repo/a${esc}[31m.txt" x
rule "CL04 a path with a control character" CL04 'the first: a\?\[31m\.txt\)'
silent "a control character from a path does not reach the output" "$esc"
g remote add origin "$work/nowhere"
run check
says "a remote with no default branch recorded" 'no upstream known \(the remote origin has no default branch recorded in this clone; git remote set-head origin <branch> records one\), [0-9]+ violation'

# --- An entry is a record: one the base holds is not deleted or renamed --------
missing() { rule "$1" CL04 "^$DIR/$E1:1: CL04 an entry that HEAD holds is missing \\(deleted or renamed\\)" "${@:2}"; }
new_repo gone
recorded "$N1" "First change" && commit_all "recorded"
rm "$repo/$DIR/$E1" && run render
writes_nothing "check, an entry deleted" check
missing "CL04 an entry deleted from the working tree"
missing "CL04 sync reports it too" sync
g checkout -q -- "$DIR/$E1" && g mv "$DIR/$E1" "$DIR/2026-03-01-101500-renamed.md" && run render
missing "CL04 an entry renamed"
g mv "$DIR/2026-03-01-101500-renamed.md" "$DIR/$E1" && g rm -q --cached "$DIR/$E1" && run render
missing "CL04 an entry dropped from the index"
g add "$DIR/$E1" && run render
clean "CL04 the entry put back" check
pair own
recorded "$N1" "First change" && commit_all "recorded"
rm "$repo/$DIR/$E1" && run render
clean "CL04 an entry the base does not hold is not a record yet" check

# --- An unmerged path, with no upstream ---------------------------------------
new_repo unmerged
g checkout -q -b side && ours put f.txt side
g checkout -q main && ours put f.txt main
g merge -q side >/dev/null 2>&1
rule "CL05 an unmerged path with no upstream" CL05 '^f.txt:1: CL05 unmerged; resolve the conflict in it and run git add on it'
silent "CL04 is not applied while CL05 fails" ' CL04 '
# Both branches made the same entry: it is unmerged, and Git lists it once for each stage.
new_repo twice
g checkout -q -b side && recorded "$N1" "First change" && commit_all "side"
g checkout -q main && entry "$N1" "First change" fix && run render && commit_all "main"
g merge -q side >/dev/null 2>&1
writes_nothing "check, an unmerged entry" check
says "an unmerged entry is read once" '^change-log: 1 entry\(ies\) checked'
says "CL05 the unmerged entry" "^$DIR/$E1:1: CL05 unmerged; resolve"
says "CL05 the list, unmerged in a merge" "^$LOG:1: CL05 unmerged; outside CI, make change-log regenerates the file and stages it"
# Unmerged with no merge in progress: the list is not staged.
new_repo pick
g checkout -q -b side && recorded "$N2" "Second change" && commit_all "side"
g checkout -q main && recorded "$N1" "First change" && commit_all "main"
g cherry-pick side >/dev/null 2>&1
rule "CL05 the list, unmerged outside a merge" CL05 "^$LOG:1: CL05 unmerged, and no merge is in progress; the file is generated: run make change-log, then git add on it" sync
is "outside a merge the list is not staged" test -n "$(g ls-files --unmerged -- "$LOG")"
isnt "and it is regenerated" grep -Eq '^(<<<<<<<|>>>>>>>)' "$repo/$LOG"

# --- The upstream is known: the base of CL04 is the upstream commit ------------
pair base
ours put f.txt ours
rule "CL04 against the upstream: a commit with no entry" CL04 "files differ from $(head_of origin/main) "
says "the summary names the upstream" "^change-log: 0 entry\\(ies\\) checked, upstream refs/remotes/origin/main at $(head_of origin/main), 1 violation"
recorded "$N1" "First change" && commit_all "recorded"
ours put g.txt more
clean "CL04 one entry new against the upstream covers every commit" check
pair held
upstream recorded "$N1" "First change"
g merge -q --ff-only origin/main
put "$repo/x.txt" x
rule "CL04 an entry the upstream holds unchanged records nothing" CL04 'the first: x.txt'

# --- Merged, and not merged ----------------------------------------------------
pair merged
before=$(state)
touch -t 202001010000 "$repo/f.txt"
writes_nothing "check, upstream already merged" check
clean "sync, upstream already merged" sync
says "merged: summary line" "upstream refs/remotes/origin/main at $(head_of origin/main), no violations$"
silent "merged: no merge is reported" 'merged [0-9a-f]|moved the branch'
unchanged "merged" "$before"
upstream put u.txt theirs
writes_nothing "check, upstream ahead" check
rule "CL05 the upstream is not merged" CL05 "^\\.:1: CL05 the upstream $(head_of origin/main) is not merged into HEAD; outside CI, commit the work in progress and run make commit, which merges the upstream into a clean working tree"
silent "CL04 is not applied while CL05 fails" ' CL04 '
g checkout -q --detach
writes_nothing "check, a detached HEAD" check
rule "CL05 on a detached HEAD" CL05 'is not merged into HEAD; no merge is made on a detached HEAD'

# --- --upstream ---------------------------------------------------------------
new_repo explicit
g branch base
put "$repo/x.txt" x && recorded "$N1" "First change" && commit_all "our change"
clean "check --upstream" check --upstream base
says "the summary names the given upstream" "upstream base at $(head_of base), no violations$"
run check --upstream nowhere
exits "--upstream that names no commit" 2
g checkout -q base && put "$repo/y.txt" y && commit_all "the base moves" && g checkout -q main
rule "CL05 against --upstream" CL05 "the upstream $(head_of base) is not merged into HEAD" check --upstream base
clean "sync --upstream merges it" sync --upstream base
is "the given upstream is being merged" test "$(head_of MERGE_HEAD)" = "$(head_of base)"

# --- What refs/remotes/origin/HEAD names ----------------------------------------
pair dangling
g update-ref -d refs/remotes/origin/main
clean "origin/HEAD names a branch that is gone: no upstream" check
says "and the summary says so" 'no upstream known \(the remote origin has no default branch recorded'
with GIT_TRACE=1 -- check
exits "the same, with Git's trace switched on by the caller" 0
pair outside
g symbolic-ref refs/remotes/origin/HEAD refs/heads/main
run check
exits "origin/HEAD names a reference outside refs/remotes/origin/" 2
pair plainref
g update-ref --no-deref refs/remotes/origin/HEAD "$(head_of HEAD)"
run check
exits "origin/HEAD is not a symbolic reference" 2
says "and the run does not say that it names no commit" '^change_log: the reference refs/remotes/origin/HEAD is not a symbolic reference, so it names no branch'
# A reference that exists and names no commit is damage: it is not read as absent.
pair damaged
mkdir -p "$repo/.git/refs/remotes/origin" && put "$repo/.git/refs/remotes/origin/main" "$bad"
run check
exits "the upstream branch names a missing object" 2
says "and the run says which reference" '^change_log: the reference refs/remotes/origin/main exists and '
new_repo damaged-head
put "$repo/f.txt" changed
put "$repo/.git/refs/heads/main" "$bad"
for verb in check sync; do
  run "$verb"
  exits "the branch names a missing object ($verb)" 2
done
says "and the run says which reference" '^change_log: the reference refs/heads/main exists and '
new_repo damaged-merge
put "$repo/.git/MERGE_HEAD" "$bad"
run check
exits "MERGE_HEAD names a missing object" 2
says "and the run says so" '^change_log: MERGE_HEAD exists and names no commit'

# --- A shallow clone with an upstream; a partial clone, with one or without ------
git clone -q --depth 1 "file://$up_repo" "$work/shallow"
repo="$work/shallow"
run check
exits "a shallow clone with an upstream" 2
for setting in remote.origin.promisor=true remote.origin.partialclonefilter=blob:none extensions.partialclone=origin; do
  pair "partial-${setting%%=*}"
  g config "${setting%%=*}" "${setting#*=}"
  for verb in check sync; do
    run "$verb"
    exits "a partial clone: $setting ($verb)" 2
  done
  says "the run names the setting" '^change_log: the Git configuration holds a partial-clone setting'
done
new_repo partial-alone
g config remote.elsewhere.promisor true
run check
exits "a partial clone with no upstream" 2
says "the run names the setting, with no upstream" '^change_log: the Git configuration holds a partial-clone setting'

# --- Fails closed: a Git question that fails, or an answer that cannot be read --
pair questions
upstream put u.txt theirs
asked check symbolic-ref
asked check 'refs/remotes/origin/main^{commit}'
asked check 'refs/remotes/origin/main^{commit}' not-a-hash
asked check --is-shallow-repository
asked check --is-shallow-repository maybe
asked check 'HEAD^{commit}'
asked check 'MERGE_HEAD^{commit}'
asked check 'MERGE_HEAD^{commit}' not-a-hash
asked check --unmerged
asked check --unmerged no-tab-in-this-line
asked check --is-ancestor
asked check --get-regexp
with ASK=HEAD NTH=1 SAY=refs/tags/v1 -- check
exits "HEAD names a reference outside refs/heads/" 2
g merge -q --ff-only origin/main
asked check --name-status
asked check --name-status not-a-change-line
asked check status
asked check status x
new_repo questions-alone
asked check --get-regexp
recorded "$N1" "First change" && commit_all "recorded"
rm "$repo/$DIR/$E1" && run render
asked check "HEAD:$DIR/$E1"

# --- Capability boundary: the commands Git was given -----------------------------
only_git_commands "every run of these tests" "$ASKS_SYNC"
isnt "git was never given a verb that contacts a remote or rewrites work" grep -Eq ' (fetch|pull|push|commit|rebase|reset|stash|checkout|switch|restore|clean|rm|mv|update-index|update-ref|maintenance|gc) ' "$shim_log"

printf 'change_log_merge_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
