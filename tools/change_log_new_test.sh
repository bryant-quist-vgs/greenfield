#!/usr/bin/env bash
# change_log_new_test.sh — Tests for change_log.sh, built against contract v1:
# the verbs new and render, usage, and everything that stops a run that has
# no upstream. The entries, the tag file, and the list are tested in change_log_test.sh;
# the upstream and rules CL04 and CL05 in change_log_merge_test.sh; the merge that sync
# makes in change_log_sync_test.sh.
#
# Coverage:
#   - Load-bearing (new): the entry it writes, byte for byte; the files it writes and no
#     others; never an overwrite, a dangling link included; bad titles, tags, and times
#     refused with nothing written; a failed write leaves no entry behind.
#   - Load-bearing (render): the one file it writes; an interrupted run leaves no
#     temporary file.
#   - Load-bearing (exit code, fails closed): 2 for each usage error, each misplaced
#     file, each Git question that fails, a listing that fails or stops short, awk that
#     fails or does not finish, and a parser line the script does not know.
#   - Trust boundary: hostile titles and tags are refused, never executed, never printed.
#   - Capability boundary: check writes nothing, needs no TMPDIR, ignores GIT_DIR; the
#     unit holds no here-document; with no upstream, Git is given only commands that read.
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
high=$(printf '\303\251') cr=$(printf '\r') tab=$(printf '\t') nl='
'
ENTRY="$DIR/$E1"
gitdir() { (cd "$repo/.git" && find . -type f -exec cksum {} + | sort -k 3); }

# --- new ----------------------------------------------------------------------
fill() { edit "$1" 's/^<what changed.*>$/The gate checks the change log./; s/^<why.*>$/A change that is not recorded cannot be found again./'; }
new_repo new
NEW=2026-03-01-101500-add-the-gate-now
before=$(files) git_before=$(gitdir)
clean "new" new --title "Add the gate: now!" --tags "security, feature" --at 2026-03-01-101500
changed_files "new writes the entry and the list, and no other file" "$before" "$DIR/$NEW.md" "$LOG"
is "new writes nothing in the Git directory" test "$git_before" = "$(gitdir)"
is "new prints the path of the entry first" test "${output%%"$nl"*}" = "$DIR/$NEW.md"
says "new says what to fill in" '^change-log: entry created; replace the placeholder line under "## What changed"'
is "new regenerates the list" grep -q "^- \\[Add the gate: now!\\](change_log/$NEW.md) (\`feature\`, \`security\`)$" "$repo/$LOG"
rule "a new entry is unfilled" CL02 "^$DIR/$NEW.md:15: CL02 an unfilled placeholder"
is "exactly its two placeholders are reported" test "$(printf '%s\n' "$output" | grep -c ' CL02 ')" -eq 2
fill "$DIR/$NEW.md"
clean "a new entry, filled in, passes" check
cp "$repo/$DIR/$NEW.md" "$work/made.md"
entry "$NEW" "Add the gate: now!" "feature, security"
is "new writes the form, byte for byte" cmp "$repo/$DIR/$NEW.md" "$work/made.md"
# What new refuses, it refuses before it writes.
refused() { # <label> <options of new...>
  local label=$1 before
  shift
  before=$(everything)
  run new "$@"
  if [ "$status" -eq 2 ] && [ "$before" = "$(everything)" ]; then ok; else fail "new refuses $label and writes nothing (exit $status)" "$output"; fi
}
# Twice in one second with one title: the second is refused and the first is intact.
refused "a second entry of the same name" --title "Add the gate: now!" --tags feature --at 2026-03-01-101500
says "new says an entry is never overwritten" 'the entry exists and is never overwritten'
# A dangling link at the entry's name: refused, and nothing is written through the link.
ln -s "$work/target-of-link" "$repo/$DIR/2026-03-08-000000-dangling.md"
refused "an entry where a dangling link stands" --title "Dangling" --tags fix --at 2026-03-08-000000
isnt "the target of the link is not created" test -e "$work/target-of-link"
rm "$repo/$DIR/2026-03-08-000000-dangling.md"
# The slug: six words at most, ASCII letters and digits only, and "change" for none.
slug() { # <title> <expected slug>
  run new --title "$1" --tags fix --at 2026-03-05-000000
  if [ "$status" -eq 0 ] && [ -f "$repo/$DIR/2026-03-05-000000-$2.md" ]; then ok; else fail "slug of '$1': expected $2" "$output"; fi
}
slug "One two THREE four five six seven" one-two-three-four-five-six
slug "v2.0: don't  panic" v2-0-don-t-panic
slug "caf${high} ${high}" caf
slug "!!! ???" change
slug '$(touch PWNED) ; touch PWNED' touch-pwned-touch-pwned
isnt "a title is not executed" test -e PWNED -o -e "$repo/PWNED"
run check
silent "an entry made by new has no fault but its placeholders" ' CL0[12] .*(front matter|heading|tag|title|not an entry)'
for bad in 'a "quote"' 'back\slash' 'a `tick`' 'a [link]' '<b>' 'a | b' ' lead' 'trail ' "two${nl}lines" "a${cr}b" "a${tab}tab" "$(printf '%0101d' 0)" "esc${esc}[31m"; do
  refused "the title '$bad'" --title "$bad" --tags fix --at 2026-03-06-000000
done
silent "a refused title is not printed with its control characters" "$esc"
refused "no title" --tags fix
refused "an empty title" --title "" --tags fix
refused "no tags" --title "A title"
refused "a title given twice" --title T --title U --tags fix
refused "tags given twice" --title T --tags fix --tags docs
refused "a time given twice" --title T --tags fix --at 2026-03-06-000000 --at 2026-03-06-000001
refused "an unknown tag" --title T --tags "fix nonsense" --at 2026-03-06-000000
says "new names the unknown tag and the baseline tags" 'nonsense is not a baseline tag .*breaking design docs'
refused "a tag given twice" --title T --tags "fix,fix" --at 2026-03-06-000000
refused "five tags" --title T --tags "docs feature fix security test" --at 2026-03-06-000000
refused "no baseline tag" --title T --tags "team:infra" --at 2026-03-06-000000
refused "an empty tag list" --title T --tags " , " --at 2026-03-06-000000
refused "a tag that does not fit the grammar" --title T --tags "Fix" --at 2026-03-06-000000
refused "a hostile tag" --title T --tags 'fix $(touch${IFS}PWNED)' --at 2026-03-06-000000
silent "a hostile tag is not printed" 'PWNED'
isnt "a tag is not executed" test -e PWNED -o -e "$repo/PWNED"
refused "a date that is not one" --title T --tags fix --at 2026-02-30-101500
refused "a time that is not one" --title T --tags fix --at 2026-03-06-240000
refused "a time in another form" --title T --tags fix --at 2026-03-06T10:15:00
refused "an option of another verb" --title T --tags fix --upstream main
for mode in fail silent garbage; do
  with AWK_MODE="$mode" -- new --title T --tags fix --at 2026-03-06-000000
  exits "new, when awk is $mode" 2
  isnt "new writes no entry when awk is $mode" test -e "$repo/$DIR/2026-03-06-000000-t.md"
done
tags_file "$ROWS"
clean "new with a declared project tag" new --title "Project tags" --tags "urgent team:infra fix" --at 2026-03-07-000000
is "new sorts the tags" grep -qx 'tags: \[fix, team:infra, urgent\]' "$repo/$DIR/2026-03-07-000000-project-tags.md"
# The clock, and a repository whose docs/change_log/ does not exist yet.
new_repo new-clock
rm -r "${repo:?}/$DIR" && commit_all "no directory"
clean "new makes docs/change_log/ and reads the clock" new --title "From the clock" --tags docs
is "the entry is named from a UTC date and time" test -f "$(printf '%s' "$repo/$DIR"/20[0-9][0-9]-[01][0-9]-[0-3][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-from-the-clock.md)"
rule "without tags.md the tag file is reported" CL06 "the file is missing"
new_repo new-ignored
mkdir -p "$repo/.git/info" && printf 'docs/change_log/2*\n' >"$repo/.git/info/exclude"
run new --title "Ignored" --tags fix --at 2026-03-01-101500
exits "new fails when Git ignores the entry it made" 2
says "and names what it wrote" "before this failure the run had created $DIR/2026-03-01-101500-ignored.md"
# A write that fails: with no room for a file, the entry is created and cannot be written.
new_repo new-full
if (ulimit -f 0) 2>/dev/null; then
  output=$(trap '' XFSZ && ulimit -f 0 && bash "$tool" --repo "$repo" new --title "No room" --tags fix --at 2026-03-09-000000 2>&1 </dev/null)
  status=$?
  exits "new, when the entry cannot be written" 2
  isnt "a failed write leaves no entry behind" test -e "$repo/$DIR/2026-03-09-000000-no-room.md"
else
  printf 'SKIP: this shell cannot limit the size of a file, so a failed write is not tested\n'
fi

# --- render: the one file it writes; an interrupted run ------------------------
new_repo render
entry "$N1" "First change"
before=$(files) git_before=$(gitdir)
clean "render" render
changed_files "render writes the list and no other file" "$before" "$LOG"
is "render writes nothing in the Git directory" test "$git_before" = "$(gitdir)"
entry "$N2" "Second change"
before=$(files)
with MV_MODE=term -- render
exits "render, interrupted before the list is in place" 2
is "an interrupted run leaves no temporary file" test -z "$(find "$repo/docs" -name 'change_log.md.tmp.*')"
changed_files "an interrupted run leaves the list as it was" "$before"

# --- Capability boundary: check writes nothing, and fails closed --------------
valid readonly
entry 2026-03-04-000000-bad "Bad" "nonsense"
touch -t 202001010000 "$repo/f.txt"
writes_nothing "check, with violations and a file whose time changed" check
exits "the run that was compared" 1
with TMPDIR="$work/absent" -- check
exits "check runs with no usable TMPDIR" 1
valid environment
with GIT_DIR="$work/absent" GIT_INDEX_FILE="$work/index" GIT_WORK_TREE="$work" -- sync
exits "ignores GIT_DIR, GIT_INDEX_FILE, and GIT_WORK_TREE" 0
isnt "a run does not write where the environment pointed" test -e "$work/index" -o -e "$work/absent"
output=$(cd "$repo" && bash "$tool" check 2>&1)
status=$?
exits "with no --repo, the current directory is checked" 0
valid unreadable
chmod 000 "$repo/$ENTRY"
run check
if [ "$(id -u)" -eq 0 ] || [ "$status" -eq 2 ]; then ok; else fail "an unreadable entry: expected exit 2, got $status" "$output"; fi
for file in "$tool" "$template"/tools/change_log_list.sh "$template"/tools/change_log_new.sh "$template"/tools/change_log_upstream.sh "$template"/tools/change_log_merge.sh "$template"/tools/change_log_*.awk; do
  isnt "$file holds no here-document and no here-string" grep -q '<<' "$file"
done
# A placed copy that lacks one of the seven files of the unit.
valid placed
for file in change_log_list.sh change_log_new.sh change_log_upstream.sh change_log_merge.sh change_log_entry.awk change_log_tags.awk; do
  mkdir "$work/unit" && cp "$tool" "$template"/tools/change_log_list.sh "$template"/tools/change_log_new.sh "$template"/tools/change_log_upstream.sh "$template"/tools/change_log_merge.sh "$template"/tools/change_log_*.awk "$work/unit" && rm "$work/unit/$file"
  output=$(bash "$work/unit/change_log.sh" --repo "$repo" check 2>&1)
  status=$?
  exits "a copy of the tool without $file" 2
  says "the run names the missing file ($file)" "^change_log: .*missing: $file\$"
  rm -r "$work/unit"
done

# --- Usage and environment: exit 2 --------------------------------------------
usage() { # <label> <code> <arguments...>
  bash "$tool" "${@:3}" >/dev/null 2>&1 </dev/null
  status=$?
  exits "$1" "$2"
}
valid usage
usage "--help" 0 --help
usage "no verb" 2 --repo "$repo"
usage "an unknown argument" 2 --repo "$repo" check --frobnicate
usage "two verbs" 2 --repo "$repo" check sync
usage "--repo with no value" 2 check --repo
usage "--repo after the verb" 2 check --repo "$repo"
usage "--repo given twice" 2 --repo "$repo" --repo "$repo" check
usage "--title for render" 2 --repo "$repo" render --title T
usage "--upstream that starts with -" 2 --repo "$repo" check --upstream -x
usage "--upstream with a space" 2 --repo "$repo" check --upstream "main other"
usage "--upstream with a byte that is not ASCII" 2 --repo "$repo" check --upstream "caf$high"
usage "--upstream given twice" 2 --repo "$repo" check --upstream main --upstream main
usage "--upstream that is empty" 2 --repo "$repo" check --upstream ""
usage "a missing directory" 2 --repo "$work/absent" check
mkdir -p "$work/plain/docs"
usage "not a Git work tree" 2 --repo "$work/plain" check
usage "a directory beneath the root of the work tree" 2 --repo "$repo/docs" check
cp "$tool" "$work/plain/"
bash "$work/plain/change_log.sh" --repo "$repo" check >/dev/null 2>&1
status=$?
exits "the copy with no sibling files" 2
placed() { # <slug> <label> <command...>: valid, then the command in the repository
  valid "$1"
  (cd "$repo" && "${@:3}")
  for verb in check render sync; do
    run "$verb"
    exits "$2 ($verb)" 2
  done
}
placed no-docs "no docs/ directory" mv docs elsewhere
placed docs-link "docs/ is a symbolic link" sh -c 'mv docs real && ln -s real docs'
placed dir-link "docs/change_log is a symbolic link" sh -c 'mv docs/change_log real && ln -s ../real docs/change_log'
placed log-link "docs/change_log.md is a symbolic link" sh -c 'echo stale >real.md && rm docs/change_log.md && ln -s ../real.md docs/change_log.md'
is "a linked list is not written through" test "$(cat "$repo/real.md")" = stale
placed log-dir "docs/change_log.md is a directory" sh -c 'rm docs/change_log.md && mkdir docs/change_log.md'

# --- Fails closed: Git, a listing, awk, and a parser ---------------------------
valid shim
asked check ls-files
asked check --show-prefix
asked check --is-inside-work-tree
asked check --show-prefix docs/
asked check 'HEAD^{commit}' not-a-hash
asked check --git-path
# The first question with the bare argument HEAD asks whether HEAD is a branch.
with ASK=HEAD NTH=1 -- check
exits "git fails the question whether HEAD is a branch" 2
says "and the run says which question" '^change_log: git could not say whether HEAD is a branch$'
# A listing of the entries that fails, or that stops short of the listing just counted,
# is never read as "no entries": nothing is written from it.
entry "$N2" "Second change"
before=$(files)
for nth in 1 2 3 4; do
  with ASK=-z NTH="$nth" -- render
  exits "render, when listing $nth of the entries fails" 2
done
with ASK=-z NTH=2 SAY=docs/change_log/2026-03-09-000000-short.md -- render
exits "render, when a listing stops short" 2
changed_files "a failed listing writes no list" "$before"
rule "a failed listing is no excuse: the list is still stale" CL03 "not what the entries generate"
for mode in fail silent garbage; do
  for program in change_log_tags.awk change_log_entry.awk; do
    with AWK_MODE="$mode" AWK_FOR="$program" -- check
    exits "check, when awk is $mode on $program" 2
  done
done
with AWK_MODE=fail AWK_FOR=change_log_entry.awk -- check
says "awk that fails is named" "^change_log: awk failed on $ENTRY\$"
with AWK_MODE=silent AWK_FOR=change_log_tags.awk -- check
says "a parser that does not finish is named" "^change_log: the parser did not finish $TAGS\$"
with AWK_MODE=garbage AWK_FOR=change_log_entry.awk -- check
says "a line the entry parser does not print" '^change_log: the entry parser printed a line this script cannot read$'
with AWK_MODE=garbage AWK_FOR=change_log_tags.awk -- check
says "a line the tag parser does not print" '^change_log: the tag parser printed a line this script cannot read$'
with AWK_MODE=badtag AWK_FOR=change_log_tags.awk -- check
says "a tag the tag parser cannot have printed" '^change_log: the tag parser printed a tag this script cannot read$'

# --- Capability boundary: the commands Git was given, with no upstream ---------
only_git_commands "every run of these tests" "${ASKS_CHECK/|merge-base --is-ancestor/}"
isnt "with no upstream, git was given no command that writes" grep -Eq ' (merge|merge-tree|diff-tree|cat-file|add) ' "$shim_log"

printf 'change_log_new_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
