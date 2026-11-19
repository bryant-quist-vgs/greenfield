#!/usr/bin/env bash
# review_lint_test.sh — Tests for review_lint.sh, built against contract v2.
#
# Coverage:
#   - Happy path: no records; one valid record with its disposition file.
#   - Load-bearing (RL01): a misnamed record is reported, not skipped.
#   - Load-bearing (RL03): a review pinned to a commit Git does not have is reported.
#   - Load-bearing (RL08): a finding with no disposition row is reported.
#   - Load-bearing (RL09): a committed record that is changed, removed, renamed, or
#     replaced is reported.
#   - Load-bearing (fails closed): a run that cannot make the check exits 2: an
#     unreadable record, a shallow clone, a partial clone, a Git that does not say
#     whether the clone is shallow, that cannot read its configuration, that cannot
#     say whether there is a commit, or that prints a line the script does not
#     recognize; an orphan branch or a damaged branch in a repository with commits.
#   - Load-bearing (exit code): 0 clean, 1 violations, 2 usage or environment.
#   - Load-bearing (output): every violation is printed as reviews/<file>:<line>: RL<nn>.
#   - Each rule RL01 to RL09: one planted defect in a valid file must be reported under
#     that rule with the expected message, and the valid file itself must pass.
#   - The blank forms reviews/TEMPLATE-*.md fail as they are and pass filled in.
#   - Trust boundary: hostile text and hostile file names are reported, never executed,
#     never printed with control characters; a path out of backlog/ is not followed.
#   - Capability boundary: a run writes nothing, needs no TMPDIR, and ignores GIT_DIR.
# Everything is built in a temporary directory; the only repository files read are the
# scripts under test and the two blank forms. `make test` runs these tests, and an
# agent may run that target.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# The script under test and the blank forms are the placed ones: template/ lies beside
# this directory.
template=$(cd "$here/../template" && pwd -P) || exit 2
lint="$template/tools/review_lint.sh" forms="$template/reviews"
# shellcheck source-path=SCRIPTDIR source=review_lint_test_lib.sh
. "$here/review_lint_test_lib.sh"

# --- Happy path -------------------------------------------------------------
new_repo empty
expect_clean "no records"
printf '%s\n' "$output" | grep -q '^reviews-lint: 0 record(s) checked, no violations$' ||
  fail "no records: summary line" "$output"
valid happy
expect_clean "valid record and disposition"

# --- The blank forms fail as they are, and pass filled in -------------------
new_repo forms
sed 's/<NN>/01/g' "$forms/TEMPLATE-record.md" >"$repo/reviews/R01-from-template.md"
sed 's/<NN>/01/g' "$forms/TEMPLATE-disposition.md" >"$repo/$DIS"
expect_rule "a blank record is not a record" RL04 "unfilled placeholder"
expect_rule "a blank disposition is not a disposition" RL08 "unfilled placeholder"
edit reviews/R01-from-template.md "s/<subject>/Goal and MVP/
  s/<reviewed-commit>/$base/; s/<base-commit>/none/; s/<scope>/design-increment/
  s/<passes>/per-item/; s/<YYYY-MM-DD>/2026-01-31/; s/<reviewer>/a person/
  s/<title>/A finding/; s/<axis>/correctness/; s/<pass>/per-item/
  s/<path:line>/docs\/design.md:1/; s/<touches>/local/; s/^<[^<>]*>\$/Filled in./"
edit "$DIS" 's/<yes-or-no>/no/g; s/<disposition>/declined/; s/<state>/closed/
  s/<where>/the owner judged it wrong/; s/^<[^<>]*>$/Filled in./'
cp "$forms/TEMPLATE-record.md" "$forms/TEMPLATE-disposition.md" "$repo/reviews/"
printf '# Reviews\n' >"$repo/reviews/README.md"
expect_clean "blank forms filled in"

# --- RL01: file names. Load-bearing: a misnamed record is reported. ----------
acted rl01-name RL01 "misnamed record" "Review-1.md" mv "$REC" reviews/Review-1.md
valid rl01-subdir
mkdir "$repo/reviews/old" && printf 'x\n' >"$repo/reviews/old/R09-x.md"
expect_rule "RL01 subdirectory" RL01 "subdirectories"
valid rl01-gap
mv "$repo/$REC" "$repo/reviews/R02-goal-and-mvp.md"
mv "$repo/$DIS" "$repo/reviews/R02-disposition.md"
expect_rule "RL01 gap in numbers" RL01 "without gaps; R01 is missing"
acted rl01-orphan RL01 "disposition with no record" "R05-disposition.md" cp seed.txt reviews/R05-disposition.md
acted rl01-twice RL01 "two records with one number" "second record" cp "$REC" reviews/R01-again.md
acted rl01-slug RL01 "slug of seven words" "six words" mv "$REC" reviews/R01-a-b-c-d-e-f-g.md
acted rl01-link RL01 "symbolic link" "symbolic link" ln -s R01-goal-and-mvp.md reviews/R02-linked.md
valid rl01-escape
esc=$(printf '\033')
high=$(printf '\303\251')
printf 'x\n' >"$repo/reviews/R02-${esc}[31mred.md"
printf 'x\n' >"$repo/reviews/R03-${high}.md"
expect_rule "RL01 a name that is not printable ASCII" RL01 "not printable ASCII"
if printf '%s' "$output" | LC_ALL=C grep -q -e "$esc" -e "$high"; then fail "a byte from a file name reached the output"; else ok; fi
valid rl01-hostile
# shellcheck disable=SC2016
printf 'x\n' | tee "$repo/reviews/-rf.md" >"$repo/reviews/\$(touch PWNED).md"
expect_rule "RL01 a name that looks like an option" RL01 "^reviews/-rf.md:1: RL01 not a record"
if [ -e PWNED ] || [ -e "$repo/PWNED" ]; then fail "a file name was executed"; else ok; fi
valid rl01-nested
git init -q "$repo/reviews/R02-nested"
expect_rule "RL01 a directory Git lists as a file" RL01 "^reviews/R02-nested:1: RL01 not a regular file"

# --- RL02: front matter -----------------------------------------------------
defect rl02-missing RL02 "$REC" '/^scope: /d' "missing key" "missing front matter key"
defect rl02-id RL02 "$REC" 's/^id: review-r01$/id: review-r02/' "wrong id" "id must be"
defect rl02-hash RL02 "$REC" 's/^reviewed_commit: .*/reviewed_commit: abc1234/' "short hash" "40 lowercase"
defect rl02-fix RL02 "$REC" 's/^scope: .*/scope: fix/' "scope fix with base none" "base_commit must be a hash"
defect rl02-order RL02 "$REC" 's/^date: .*/passes: per-item/' "repeated key" "repeated"
defect rl02-noform RL02 "$REC" '/^form: /d' "no form key" "before this one: form"
defect rl02-form RL02 "$REC" 's/^form: 1$/form: 2/' "another form version" "form must be 1"
defect rl02-date RL02 "$REC" 's/^date: .*/date: 2026-99-99/' "impossible date" "date must be"
defect rl02-blank RL02 "$REC" 's/^reviewer: .*/reviewer: <reviewer>/' "unfilled key" "unfilled"
defect rl02-title RL02 "$REC" 's/^title: .*/title: "R02. Other"/' "title of another review" "title must be"
defect rl02-truth RL02 "$REC" 's/^is_source_of_truth: .*/is_source_of_truth: false/' "not a source of truth" "must be true"
defect rl02-derives RL02 "$REC" 's/^derives_from: .*/derives_from: []/' "wrong derives_from" "derives_from must be"
defect rl02-status RL02 "$REC" 's/^status: .*/status: draft/' "wrong status" "status must be"
defect rl02-review RL02 "$REC" 's/^review: .*/review: R02/' "wrong review" "review must be R01"
defect rl02-scope RL02 "$REC" 's/^scope: .*/scope: everything/' "scope outside the list" "scope must be"
defect rl02-passes RL02 "$REC" 's/^passes: .*/passes: both/' "passes outside the list" "passes must be"
defect rl02-reviewer RL02 "$REC" 's/^reviewer: .*/reviewer:  /' "empty reviewer" "reviewer must not be empty"

# --- RL03: commits exist. Load-bearing: a review is pinned to a real commit. --
defect rl03 RL03 "$REC" "s/^reviewed_commit: .*/reviewed_commit: $NOHASH/" "reviewed commit Git lacks" "$NOHASH"
rowdefect rl03-where RL03 row1 "yes | yes | fix-now | fixed | $NOHASH" "fixing commit Git lacks" "$NOHASH"

# --- RL04: structure --------------------------------------------------------
tab=$(printf '\t')
defect rl04-missing RL04 "$REC" '/^## Remarks$/d' "missing section" "missing section"
defect rl04-h1 RL04 "$REC" 's/^# R01\. Goal and MVP$/# Another title/' "heading is not the title" "title"
defect rl04-empty RL04 "$REC" '/^Read docs\/design.md at the reviewed commit\.$/d' "empty Scope" "Scope is empty"
defect rl04-level RL04 "$REC" 's/^## Remarks$/### Remarks/' "section at the wrong level" "before this one: ## Remarks"
defect rl04-indent RL04 "$REC" 's/^## Remarks$/ ## Remarks/' "indented heading" "column 1"
defect rl04-tab RL04 "$REC" "s/^## Remarks\$/##${tab}Extra/" "heading with a tab" "unexpected"
defect rl04-setext RL04 "$REC" 's/^Read docs.*/&\
=====/' "underlined heading" "line of = or -"
defect rl04-fence RL04 "$REC" 's/^Ran make docs-lint.*/&\
```/' "unclosed fence" "not closed"
defect rl04-dashes RL04 "$REC" 's/^Read docs.*/&\
-----/' "heading underlined with dashes" "line of = or -"
# What a renderer would show as structure and this linter would read as text is refused:
# an HTML block (a fence line inside one is not a fence), an indented fence line (it
# closes a fence for a renderer), a heading in a quote or a list, a bare carriage return.
defect rl04-html RL04 "$REC" 's/^## Remarks$/<!--\
````\
-->\
&/' "fence inside an HTML comment" "raw HTML"
defect rl04-div RL04 "$REC" 's/^Lines 12 and 40\.$/<div> /' "HTML block with a trailing space" "raw HTML"
defect rl04-fence1 RL04 "$REC" 's/^Lines 12 and 40\.$/ ````/' "indented fence line" "fence line starts in column 1"
defect rl04-fence2 RL04 "$REC" 's/^### R01-F09 inside.*/  ~~~~/' "indented line that would close a fence" "fence line starts in column 1"
defect rl04-quote RL04 "$REC" 's/^Lines 12 and 40\.$/> ### R01-F03 Quoted/' "heading in a quote" "inside a quote or a list item"
defect rl04-list RL04 "$REC" 's/^Lines 12 and 40\.$/- ## Appendix/' "heading in a list item" "inside a quote or a list item"
cr=$(printf '\r')
defect rl04-cr RL04 "$REC" "s/^Lines 12 and 40\\.\$/Lines${cr}### R01-F03 Hidden/" "bare carriage return" "control character"
valid rl04-nul
printf 'security\000 severity: critical\n' >>"$repo/$REC"
expect_rule "RL04 NUL byte" RL04 "control character"
valid rl04-extra
printf '\n## Appendix\n\nMore.\n' >>"$repo/$REC"
expect_rule "RL04 extra section" RL04 "unexpected"

# --- RL05: finding entries --------------------------------------------------
defect rl05-number RL05 "$REC" 's/^### R01-F02 /### R01-F03 /' "gap in finding numbers" "expected the finding ID R01-F02"
defect rl05-axis RL05 "$REC" 's/^axis: completeness$/axis: critical/' "axis outside the rubric" "not a rubric value"
defect rl05-severity RL05 "$REC" 's/^also: none$/severity: high/' "a key the form does not have" "expected the key also"
defect rl05-also RL05 "$REC" 's/^also: none$/also: /' "empty also" "also must be"
defect rl05-local RL05 "$REC" 's/^touches: local$/touches: local, interface/' "local is not alone" "stands alone"
defect rl05-touches RL05 "$REC" 's/^touches: test-harness, interface$/touches: interface, interface/' "touches repeats a value" "touches repeats"
defect rl05-also2 RL05 "$REC" 's/^also: verification-integrity$/also: scope, scope/' "also repeats a value" "also repeats a value"
defect rl05-also3 RL05 "$REC" 's/^also: verification-integrity$/also: completeness/' "also repeats the axis" "also repeats the axis"
defect rl05-pass RL05 "$REC" 's/^passes: .*/passes: per-item/' "pass the front matter does not name" "not among"
defect rl05-cross RL05 "$REC" 's/^pass: cross-item$/pass: per-item/' "cross-item axis in the per-item pass" "cross-item pass"
defect rl05-per RL05 "$REC" 's/^pass: per-item$/pass: cross-item/' "per-item axis in the cross-item pass" "per-item pass"
defect rl05-block RL05 "$REC" '/^axis: consistency$/d' "field block lacks a key" "expected the key axis"
defect rl05-blank RL05 "$REC" 's/^location: docs\/design.md:30$/location: <path:line>/' "unfilled field" "unfilled"
defect rl05-sub RL05 "$REC" '/^One meaning, defined once\.$/d' "empty Resolved when" "Resolved when is empty"
defect rl05-order RL05 "$REC" 's/^#### Consequence$/#### Impact/' "wrong section name" "expected #### Consequence"
# A line that looks like a fence and is not one must not hide the heading after it.
# shellcheck disable=SC2016
defect rl05-hidden RL05 "$REC" 's/^Lines 12 and 40\.$/```a`b\
### R01-F03 Hidden\
```/' "finding behind a false fence" "field block"
valid rl05-none
edit "$REC" 's/^## Findings$/## Findings\
\
None./'
expect_rule "RL05 None. with entries" RL05 "both None"

# --- RL06: prior findings ---------------------------------------------------
setup=fix_review
fix_review rl06-valid
expect_clean "RL06 valid fix review"
defect rl06-none RL06 "$FIX" '/^| R01-F01 | resolved /d' "fix review with an empty table" "no rows"
defect rl06-result RL06 "$FIX" 's/^| R01-F01 | resolved /| R01-F01 | fixed /' "result outside the vocabulary" "Result must be"
defect rl06-unknown RL06 "$FIX" 's/^| R01-F01 | resolved /| R01-F09 | resolved /' "finding no record holds" "no record holds"
defect rl06-self RL06 "$FIX" 's/^| R01-F01 | resolved /| R02-F01 | resolved /' "finding of the same review" "lower-numbered"
defect rl06-twice RL06 "$FIX" 's/^| R01-F01 | resolved .*/&\
&/' "two rows for one finding" "second row"
defect rl03-base RL03 "$FIX" "s/^base_commit: .*/base_commit: $NOHASH/" "base commit Git lacks" "$NOHASH"
defect rl06-nosep RL06 "$FIX" 's/^|---|---|---|$/|---|---|/' "separator of two cells" "separator row"
defect rl06-fixnone RL06 "$FIX" '/^| Finding | Result /d; /^|---|---|---|$/d; s/^| R01-F01 | resolved .*/None./' "fix review with None." "needs a prior findings table"
fix_review rl06-spaced
edit "$FIX" 's/^|---|---|---|$/| --- | :-- | --- |/; s/^| Finding | Result | Evidence |$/|Finding|Result|Evidence|/'
expect_clean "RL06 a table with other spacing"
setup=valid

# --- RL07: disposition file -------------------------------------------------
acted rl07-missing RL07 "no disposition file" "no disposition file" rm "$DIS"
defect rl07-header RL07 "$DIS" 's/^| Finding | Blocks MVP | .*/| Finding | Severity | Disposition |/' "wrong table header" "table header"
defect rl07-front RL07 "$DIS" 's/^derives_from: .*/derives_from: []/' "wrong front matter" "expected the line derives_from"
defect rl07-form RL07 "$DIS" '/^form: 1$/d' "no form key" "front matter ends before the key form"
defect rl07-indent RL07 "$DIS" 's/^### R01-F02$/  ### R01-F02/' "indented heading" "column 1"
defect rl07-html RL07 "$DIS" 's/^Wording only\..*/<div> /' "HTML block" "raw HTML"
defect rl07-fence RL07 "$DIS" 's/^Wording only\..*/  ~~~/' "indented fence line" "fence line starts in column 1"
defect rl07-cr RL07 "$DIS" "s/^Wording only\\..*/Wording${cr}### R01-F03/" "bare carriage return" "control character"

# --- RL08: disposition rows. Load-bearing: every finding is tracked. ---------
defect rl08-row RL08 "$DIS" '/^| R01-F02 | /d' "finding with no row" "no row for the finding R01-F02"
defect rl08-reason RL08 "$DIS" '/^Wording only\. Decided by the owner\.$/d' "empty reason" "reason is empty"
rowdefect rl08-later RL08 row2 "no | yes | later | open | backlog/R01-F02-two-meanings.md" "later with a yes" "both no"
rowdefect rl08-state RL08 row1 "yes | yes | declined | open | -" "declined and open" "not allowed"
rowdefect rl08-dash RL08 row1 "yes | yes | fix-now | open | soon" "open fix-now with a Where" "must be -"
rowdefect rl08-fixed RL08 row1 "yes | yes | fix-now | fixed | soon" "fixed with no hash" "40-character hash"
rowdefect rl08-closed RL08 row1 "no | no | declined | closed | -" "closed with no reason" "why the finding is closed"
rowdefect rl08-blank RL08 row1 "<yes-or-no> | yes | fix-now | open | -" "unfilled cell" "unfilled"
acted rl08-backlog RL08 "later with no backlog file" "does not exist" rm backlog/R01-F02-two-meanings.md
rowdefect rl08-noreview RL08 row1 "yes | yes | fix-now | verified | $NOHASH" "verified with no review" "must name the review"
defect rl08-swap RL08 "$DIS" 's/^| R01-F01 | .*/| R01-F02 | no | no | declined | closed | wrong |/' "rows out of order" "expected the row for R01-F01"
defect rl08-extra RL08 "$DIS" 's/^| R01-F02 | .*/&\
| R01-F03 | no | no | declined | closed | wrong |/' "row for no finding" "not a finding of the record"
acted rl08-link RL08 "backlog file that is a link" "does not exist" ln -sf ../seed.txt backlog/R01-F02-two-meanings.md
# Where names only this finding's own file under backlog/, however real another file is.
valid rl08-where
printf 'x\n' | tee "$repo/backlog/README.md" "$repo/backlog/R01-F01-other.md" >"$repo/R01-F02-up.md"
for where in backlog/README.md backlog/R01-F01-other.md backlog/../R01-F02-up.md; do
  row2 "no | no | later | open | $where"
  expect_rule "RL08 Where is $where" RL08 "must name the finding file"
done

fix_review rl08-verified
row1 "yes | yes | fix-now | verified | $base, R02"
expect_clean "RL08 verified by a review that judges it resolved"
edit "$FIX" 's/^| R01-F01 | resolved /| R01-F01 | not-resolved /'
expect_rule "RL08 verified but the review says not-resolved" RL08 "does not judge R01-F01 resolved"

valid rl08-nofindings
edit "$REC" '/^### R01-F01 /,/^One meaning, defined once\.$/d'
edit "$REC" 's/^## Findings$/## Findings\
\
None./'
edit "$DIS" '/^| R01-F0[12] | /d'
# shellcheck disable=SC2016
edit "$DIS" '/^### R01-F01$/,$d'
printf 'None.\n' >>"$repo/$DIS"
expect_clean "RL08 a record with no findings"

# --- RL09: a record does not change -----------------------------------------
valid rl09
# Settings that would change what git log prints are pinned by the script.
g config log.follow true && g config log.diffMerges combined && g config log.showSignature true
commit_all "review R01"
expect_clean "RL09 committed and unchanged"
trunk=$(g rev-parse --abbrev-ref HEAD)
g checkout -q -b side
record 02 second-look design-increment none
disposition 02
commit_all "review R02"
g checkout -q "$trunk"
printf 'more\n' >>"$repo/seed.txt"
commit_all "other work"
g merge -q --no-ff -m "merge side" side
expect_clean "RL09 a record that arrived through a merge commit"
edit "$REC" 's/^Nothing shows the MVP works\.$/It is probably fine./'
expect_rule "RL09 working copy differs" RL09 "working copy differs"
commit_all "soften a finding"
expect_rule "RL09 changed in a second commit" RL09 "changed after it was committed"
# A record the history holds is a regular file now: not removed, not renamed, not
# replaced by something else, whether or not the change has been committed.
setup=committed
acted rl09-rm RL09 "a committed record removed, not yet committed" "it is gone" rm "$REC" "$DIS"
acted rl09-mv RL09 "a committed record renamed, not yet committed" "^$REC:1: RL09 .*it is gone" mv "$REC" reviews/R01-renamed.md
setup=valid
committed rl09-gitlink
g rm -q --cached "$REC" && mv "$repo/$REC" "$repo/reviews/R01-other.md" && mkdir "$repo/$REC"
g update-index --add --cacheinfo "160000,$base,$REC" && g add reviews/R01-other.md && g commit -q -m swap
expect_rule "RL09 a record replaced by a submodule entry" RL09 "^$REC:1: RL09 .*it is gone"
expect_rule "RL01 a submodule entry under reviews/" RL01 "^$REC:1: RL01 not a regular file"
valid rl09-deleted
printf '# Reviews\n' >"$repo/reviews/README.md"
commit_all "review R01"
g rm -q "$REC" "$DIS" && g commit -q -m "drop the review"
expect_rule "RL09 a deleted record" RL09 "it is gone"

# --- Reports every violation, with file and line ----------------------------
valid all
edit "$REC" 's/^axis: completeness$/axis: critical/'
edit "$DIS" '/^| R01-F02 | /d'
run
if [ "$status" -eq 1 ] &&
  printf '%s\n' "$output" | grep -q "^$REC:[0-9]*: RL05 " &&
  printf '%s\n' "$output" | grep -q "^$DIS:[0-9]*: RL08 "; then
  ok
else
  fail "does not stop at the first violation" "$output"
fi

# --- Trust boundary: hostile text is reported and never executed ------------
valid hostile
edit "$REC" "s|^location: docs/design.md:30\$|location: \$(touch $work/PWNED) \`touch $work/PWNED\`; touch $work/PWNED|"
edit "$REC" "s|^### R01-F02 .*|### R01-F02 \$(touch $work/PWNED)|"
edit "$REC" "s|^reviewed_commit: .*|reviewed_commit: \$(touch $work/PWNED)|"
row2 "no | no | later | open | backlog/../../../etc/passwd.md \$(touch $work/PWNED)"
expect_rule "hostile text is reported" RL08 "must name the finding file"
if [ -e "$work/PWNED" ]; then fail "hostile text was executed" "$output"; else ok; fi
valid control-chars
edit "$REC" "s/^scope: .*/scope: ${esc}[31mred/"
run
if printf '%s' "$output" | grep -q "$esc"; then fail "a control character from a record reached the output"; else ok; fi

# --- Capability boundary: a run writes nothing, and fails closed ------------
valid readonly
commit_all "review R01"
edit "$REC" 's/^Nothing shows the MVP works\.$/Changed./'
listing() { (cd "$repo" && find . -exec ls -ld {} + && find . -type f -exec cksum {} + | sort); }
before=$(listing)
expect_rule "the run to compare" RL09
if [ "$before" = "$(listing)" ]; then ok; else fail "a run changed the repository, .git included"; fi
valid environment
output=$(cd "$repo" && bash "$lint" 2>&1)
status=$?
if [ "$status" -eq 0 ]; then ok; else fail "with no --repo, the current directory is checked" "$output"; fi
expect_clean "runs with no usable TMPDIR" TMPDIR="$work/absent"
expect_clean "ignores GIT_DIR and GIT_INDEX_FILE" GIT_DIR="$work/absent" GIT_INDEX_FILE="$work/index"
if [ -e "$work/index" ] || [ -e "$work/absent" ]; then fail "a run wrote where the environment pointed"; else ok; fi
valid unreadable
chmod 000 "$repo/$REC"
run
if [ "$(id -u)" -eq 0 ] || [ "$status" -eq 2 ]; then ok; else fail "an unreadable record: expected exit 2, got $status" "$output"; fi

# --- Usage and environment: exit 2 ------------------------------------------
check_exit() { # <label> <code> <command...>
  "${@:3}" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$2" ]; then ok; else fail "$1: expected exit $2, got $got"; fi
}
# A directory beneath the root of the work tree; a repository with no commit; a clone
# without its history, which cannot be checked and must not pass.
new_repo beneath
repo="$repo/sub"
mkdir -p "$repo/reviews" "$repo/backlog"
record 01 goal-and-mvp design-increment none
disposition 01
commit_all "review R01"
expect_clean "a directory beneath the work-tree root"
edit "$REC" 's/^Nothing shows the MVP works\.$/Changed./'
expect_rule "RL09 beneath the work-tree root" RL09 "working copy differs"
repo="$work/repo.unborn"
mkdir -p "$repo/reviews" && g init -q
expect_clean "a repository with no commit"
committed shallow-source
git clone -q --depth 1 "file://$repo" "$work/shallow"
check_exit "a shallow clone" 2 bash "$lint" --repo "$work/shallow"
g config uploadpack.allowFilter true
git clone -q --filter=blob:none "file://$repo" "$work/partial"
check_exit "a partial clone" 2 bash "$lint" --repo "$work/partial"
# A git on PATH that fails one question, or answers it as a Git older than 2.15 does.
committed shim
mkdir "$work/shim"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'for a in "$@"; do' '  [ "$a" = "${ASK:-}" ] || continue' \
  '  [ -z "${SAY:-}" ] || { echo "$SAY"; exit 0; }' '  exit 3' 'done' \
  "exec '$(command -v git)' \"\$@\"" >"$work/shim/git"
chmod +x "$work/shim/git"
shim() { # <label> <exit> [<NAME=value>...]
  local label=$1 want=$2; shift 2
  run PATH="$work/shim:$PATH" "$@"
  if [ "$status" -eq "$want" ]; then ok; else fail "$label: expected exit $want, got $status" "$output"; fi
}
shim "the stand-in git changes nothing by itself" 0
shim "git fails to say whether the clone is shallow" 2 ASK=--is-shallow-repository
shim "git does not know the shallow question" 2 ASK=--is-shallow-repository SAY=--is-shallow-repository
shim "git cannot read its configuration" 2 ASK=--get-regexp
shim "git cannot say whether the repository has a commit" 2 ASK=--verify
shim "git prints a line the script does not recognize" 2 ASK=log SAY=garbage
# HEAD names no commit, and a history exists: an orphan branch, a damaged branch.
committed orphan && g checkout -q --orphan elsewhere
check_exit "an orphan branch in a repository with commits" 2 bash "$lint" --repo "$repo"
committed damaged && printf 'garbage\n' >"$repo/.git/$(g symbolic-ref HEAD)"
check_exit "a damaged branch" 2 bash "$lint" --repo "$repo"
repo="$work/repo.unborn"; shim "git cannot list the references" 2 ASK=for-each-ref
repo="$work/repo.shim"
g config remote.origin.promisor false
check_exit "a promisor setting of any value is taken for a partial clone" 2 bash "$lint" --repo "$repo"
# RL03 takes a hash that names an annotated tag of a commit as that commit.
valid rl03-tag
g tag -a -m "the reviewed commit" reviewed "$base"
edit "$REC" "s/^reviewed_commit: .*/reviewed_commit: $(g rev-parse reviewed)/"
expect_clean "RL03 a hash that names an annotated tag of a commit"
# More of what behaviors 5 and 9 say about fences, raw HTML, quotes, lists, and tables.
setup=valid
defect rl04-lt RL04 "$REC" 's/^Lines 12 and 40\.$/   <div>/' "indented raw HTML line" "raw HTML"
defect rl04-qfence RL04 "$REC" 's/^Lines 12 and 40\.$/> ~~~/' "fence in a quote" "inside a quote or a list item"
defect rl04-lrule RL04 "$REC" 's/^Lines 12 and 40\.$/- ---/' "rule in a list item" "inside a quote or a list item"
valid rl04-close
edit "$REC" '/^### R01-F09 inside/{n;s/^~~~$/~~~  /;}'
expect_clean "RL04 a closing fence followed by spaces"
valid rl07-spaced
edit "$DIS" 's/^|---|---|---|---|---|---|$/| :-- | --- | --- | --- | --- | --: |/; s/^| Finding | Blocks MVP | .*/|Finding|Blocks MVP|Expensive later|Disposition|State|Where|/'
expect_clean "RL07 a dispositions table with other spacing"
# Text from a record stays out of the report.
valid quoted-text
edit "$REC" 's/^axis: completeness$/axis: ZZTEXTFROMRECORD/; s/^Section 3 lists features.*/ZZTEXTFROMRECORD/'
edit "$DIS" 's/^| R01-F01 | yes | yes | fix-now /| R01-F01 | ZZTEXTFROMRECORD | yes | fix-now /'
run
if [ "$status" -eq 1 ] && ! printf '%s\n' "$output" | grep -q ZZTEXTFROMRECORD; then ok
else fail "text from a record is not printed (exit $status)" "$output"; fi
check_exit "the script holds no here-document" 1 grep -q '<<' "$lint"
check_exit "--help" 0 bash "$lint" --help
check_exit "unknown argument" 2 bash "$lint" --frobnicate
check_exit "--repo with no value" 2 bash "$lint" --repo
check_exit "missing directory" 2 bash "$lint" --repo "$work/absent"
mkdir -p "$work/plain/reviews" "$work/alone"
check_exit "not a Git work tree" 2 bash "$lint" --repo "$work/plain"
valid alone
cp "$lint" "$work/alone/"
check_exit "the awk programs are missing" 2 bash "$work/alone/review_lint.sh" --repo "$repo"
new_repo noreviews && rmdir "$repo/reviews"
check_exit "no reviews directory" 2 bash "$lint" --repo "$repo"

printf 'review_lint_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
