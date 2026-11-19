#!/usr/bin/env bash
# change_log_test.sh — Tests for change_log.sh, built against contract v1:
# the entries, the tag file, and the generated list. The verbs new and render, usage, and
# what stops a run are tested in change_log_new_test.sh; the upstream and rules CL04 and
# CL05 in change_log_merge_test.sh; the merge that sync makes in change_log_sync_test.sh.
#
# Coverage:
#   - Happy path: no entries; one valid entry; the summary line.
#   - Load-bearing (CL01): a misnamed file is reported under its own name, not left out
#     silently; the names at the edge of the form pass.
#   - Load-bearing (CL02): each departure from the entry form is reported with its message;
#     an unknown tag, a duplicate, an unsorted list, five tags, no baseline tag, and an
#     empty list; a declared project tag passes, bare and namespaced.
#   - Load-bearing (CL06): each fault of docs/change_log/tags.md, and that a fault there
#     does not stop the other rules.
#   - Load-bearing (the list): the bytes for no entries are the bytes the template ships;
#     the bytes for three entries; a current file is not touched; CL03.
#   - The baseline tags held by the tool are those of docs/greenfield/change-log.md §2.
#   - Trust boundary: hostile tags, file names, and text are reported, never executed,
#     never printed; a long path is cut in a message.
# Everything is built in a temporary directory; the only repository files read are the
# unit under test, docs/greenfield/change-log.md, and the two files the template ships
# under docs/. `make test` runs these tests, and an agent may run that target.
# shellcheck disable=SC2016 # sed expressions and hostile text are written literally
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# The scripts under test are the placed ones: template/ lies beside this directory.
template=$(cd "$here/../template" && pwd -P) || exit 2
tool="$template/tools/change_log.sh"
# shellcheck source-path=SCRIPTDIR source=change_log_test_lib.sh
. "$here/change_log_test_lib.sh"
high=$(printf '\303\251') cr=$(printf '\r') tab=$(printf '\t')
ENTRY="$DIR/$E1"

# --- Happy path -------------------------------------------------------------
new_repo empty
clean "no entries" check
says "no entries: summary line" '^change-log: 0 entry\(ies\) checked, no upstream known, no violations$'
valid happy
clean "one valid entry" check
says "one entry: summary line" '^change-log: 1 entry\(ies\) checked, no upstream known, no violations$'

# --- The files the template ships; the baseline tags of the rules ------------
shipped="$template/docs" others=0
for file in "$shipped"/change_log/*; do [ "${file##*/}" = tags.md ] || others=1; done
if [ "$others" -eq 0 ]; then
  new_repo shipped
  cp "$shipped/change_log/tags.md" "$repo/$TAGS" && rm "$repo/$LOG"
  clean "render for the shipped tag file" render
  is "the shipped docs/change_log.md is what render writes for no entries" cmp "$repo/$LOG" "$shipped/change_log.md"
  clean "the shipped files pass" check
else
  printf 'SKIP: this repository has entries, so its docs/change_log.md is not the shipped one\n'
fi
rules="$template/docs/greenfield/change-log.md"
in_rules=$([ -f "$rules" ] && awk '/^\| Tag \| An entry carries it when \|$/ { t = 1; next }
  t && /^\|/ { if ($2 ~ /^`[a-z-]+`$/) { gsub(/`/, "", $2); printf "%s ", $2 }; next }
  t { exit }' "$rules")
in_tool=$(sed -n "s/^baseline_tags='\(.*\)'$/\1/p" "$tool")
if [ -n "$in_rules" ] && [ "$in_tool " = "$in_rules" ]; then ok
else fail "the baseline tags of the tool are not those of docs/greenfield/change-log.md" "$in_tool / $in_rules"; fi

# --- The generated list -----------------------------------------------------
new_repo list
tags_file "$ROWS"
entry "${E1%.md}" "First change"
entry "${E2%.md}" "Second change" "fix, security"
entry 2026-03-01-235959-later-that-day "Later that day" "docs, team:infra"
{
  empty_log
  printf '%s\n' '## 2026-03-02' '' "- [Second change](change_log/$E2) (\`fix\`, \`security\`)" '' '## 2026-03-01' '' \
    '- [Later that day](change_log/2026-03-01-235959-later-that-day.md) (`docs`, `team:infra`)' \
    "- [First change](change_log/$E1) (\`feature\`)"
} >"$work/expected.md"
rule "CL03 a list that lacks the entries" CL03 "not what the entries generate"
clean "render writes the list" render
says "render says it wrote" "^change-log: $LOG written, 3 entry\\(ies\\) listed$"
is "the list for three entries, byte for byte" cmp "$repo/$LOG" "$work/expected.md"
clean "the rendered list passes" check
before=$(ls -li "$repo/$LOG")
clean "render again" render
says "render says the file is current" "^change-log: $LOG is current, 3 entry"
is "render leaves a current file untouched" test "$before" = "$(ls -li "$repo/$LOG")"
printf 'edited by hand\n' >>"$repo/$LOG"
rule "CL03 a list edited by hand" CL03 "never edited by hand"
rm "$repo/$LOG"
rule "CL03 no list" CL03 "the file is missing"
clean "render writes a missing list" render
is "the list is the same bytes again" cmp "$repo/$LOG" "$work/expected.md"
# The list depends on the entries alone: an undeclared tag is reported and still shown.
tags_file
rule "CL02 a tag that is no longer declared" CL02 "tag 2 is not a baseline tag"
silent "the list is still current" ' CL03 '
# An entry whose title cannot be read is left out, and render says so.
edit "$DIR/$E2" 's/^title: .*/title: "a [b]"/'
clean "render with an unreadable title" render
says "render says a file is not listed" '^change-log: 1 file\(s\) under docs/change_log/ are not listed'
isnt "the unreadable entry is not in the list" grep -q "$E2" "$repo/$LOG"

# --- CL01: names. Load-bearing: a misnamed file is reported. ------------------
named() { # <slug> <file name>: a valid entry under a name that is not an entry's
  valid "$1"
  mv "$repo/$ENTRY" "$repo/$DIR/$2"
  rule "CL01 $2" CL01 "^$DIR/$2:1: CL01 not tags.md and not an entry"
}
named cl01-name Notes.md
named cl01-readme README.md
named cl01-seven 2026-03-01-101500-a-b-c-d-e-f-g.md
named cl01-hour 2026-03-01-246000-first-change.md
named cl01-minute 2026-03-01-236000-first-change.md
named cl01-second 2026-03-01-235960-first-change.md
named cl01-short 2026-03-01-1015-first-change.md
named cl01-upper 2026-03-01-101500-First.md
named cl01-under 2026-03-01-101500-first_change.md
named cl01-noslug 2026-03-01-101500-.md
# The names at the edge of the form are entries.
valid cl01-edge
entry 2026-03-01-235959-a-b-c-d-e-f "Six words"
entry 2026-03-01-000000-7 "A digit"
run render
clean "CL01 six words, a digit, and the last second of the day" check
says "the three are entries" '^change-log: 3 entry\(ies\) checked'
# A long path is cut to 200 characters in a message.
valid cl01-long
entry "2026-03-04-000000-$(printf '%0220d' 0 | tr 0 a)" "A long name" nonsense
rule "a long path is cut in a message" CL02 "^$DIR/2026-03-04-000000-a{166}\\.\\.\\.:8: CL02 tag 1 is not a baseline tag"
valid cl01-subdir
mkdir "$repo/$DIR/old" && mv "$repo/$ENTRY" "$repo/$DIR/old/"
rule "CL01 an entry in a subdirectory" CL01 "subdirectories"
valid cl01-link
ln -s "$E1" "$repo/$DIR/2026-03-03-000000-linked.md"
rule "CL01 a symbolic link" CL01 "a symbolic link"
valid cl01-bytes
cp "$repo/$ENTRY" "$repo/$DIR/2026-03-03-000000-${esc}[31mred.md"
cp "$repo/$ENTRY" "$repo/$DIR/2026-03-03-000000-${high}.md"
rule "CL01 a name that is not printable ASCII" CL01 "not printable ASCII"
silent "a byte from a file name does not reach the output" "$esc|$high"
valid cl01-hostile
cp "$repo/$ENTRY" "$repo/$DIR/-rf.md" && cp "$repo/$ENTRY" "$repo/$DIR/\$(touch PWNED).md"
rule "CL01 a name that looks like an option" CL01 "^$DIR/-rf.md:1: CL01 not tags.md"
isnt "a file name is not executed" test -e PWNED -o -e "$repo/PWNED"
run render
isnt "a misnamed file is not listed" grep -q -e '-rf' -e PWNED "$repo/$LOG"
valid cl01-nested
git init -q "$repo/$DIR/2026-03-03-000000-nested.md"
rule "CL01 a directory Git lists as a file" CL01 "^$DIR/2026-03-03-000000-nested.md:1: CL01 not a regular file"

# --- CL02: the entry form -----------------------------------------------------
defect cl02-dash CL02 "$ENTRY" '1s/.*/----/' "line 1" "^$ENTRY:1: CL02 line 1 must be ---"
defect cl02-id CL02 "$ENTRY" 's/^id: .*/id: change-other/' "id" "line 2 must be id: change-"
defect cl02-truth CL02 "$ENTRY" 's/^is_source_of_truth: true/is_source_of_truth: false/' "is_source_of_truth" "line 4 must be is_source_of_truth: true"
defect cl02-derives CL02 "$ENTRY" 's/^derives_from: .*/derives_from: [design]/' "derives_from" "line 5 must be derives_from"
defect cl02-status CL02 "$ENTRY" 's/^status: .*/status: draft/' "status" "line 6 must be status: current"
defect cl02-date CL02 "$ENTRY" 's/^date: .*/date: 2026-03-02/' "date of another day" "line 7 must be date:"
defect cl02-key CL02 "$ENTRY" '/^status: /d' "a missing key" "line 6 must be status"
defect cl02-end CL02 "$ENTRY" '9s/.*/extra: 1/' "an extra key" "line 9 must be ---"
defect cl02-short CL02 "$ENTRY" '4,$d' "a file that ends early" "front matter is incomplete"
for bad in 'a "b"' 'a\b' 'a `b`' 'a [b]' 'a <b>' 'a | b' ' a' 'a ' "a${tab}b" "$(printf '%0101d' 0)" ''; do
  valid cl02-title
  entry "${E1%.md}" "$bad"
  rule "CL02 the title '$bad'" CL02 "^$ENTRY:3: CL02 front matter line 3 must be title:"
done
defect cl02-quotes CL02 "$ENTRY" 's/^title: .*/title: First change/' "a title without quotes" "line 3 must be title:"
valid cl02-long
edit "$ENTRY" "s/First change/$(printf '%0100d' 0)/"
clean "CL02 a title of 100 bytes" sync
valid cl02-impossible
entry 2026-02-30-101500-no-such-day "No such day"
rule "CL02 a date that is not a calendar date" CL02 "^$DIR/2026-02-30-101500-no-such-day.md:7: CL02 .*not a calendar date"
entry 2026-02-29-101500-not-a-leap-year "Not a leap year"
rule "CL02 29 February of a common year" CL02 "2026-02-29.*not a calendar date"
rm "$repo/$DIR"/2026-02-*.md
entry 2028-02-29-101500-leap-day "Leap day"
clean "CL02 29 February of a leap year" sync
# Tags.
tagged() { # <slug> <tags line> <regex>, with the project tags of $ROWS declared
  valid "$1"
  tags_file "$ROWS"
  edit "$ENTRY" "s/^tags: .*/$2/"
  if [ -n "$3" ]; then rule "CL02 $2" CL02 "$3"; else clean "CL02 $2" sync; fi
}
tagged tag-unknown 'tags: [feature, nonsense]' "^$ENTRY:8: CL02 tag 2 is not a baseline tag and is not declared"
tagged tag-twice 'tags: [fix, fix]' "tag 2 repeats tag 1"
tagged tag-order 'tags: [security, fix]' "ascending byte order; tag 2 sorts before tag 1"
tagged tag-five 'tags: [docs, feature, fix, security, test]' "tags holds 1 to 4 tags"
tagged tag-none 'tags: [team:infra, urgent]' "at least one tag is a baseline tag"
tagged tag-empty 'tags: []' "tags holds 1 to 4 tags"
tagged tag-case 'tags: [Fix]' "tag 1 is not a tag"
tagged tag-space 'tags: [docs,fix]' "tag 1 is not a tag"
tagged tag-ns 'tags: [a:b:c, fix]' "tag 1 is not a tag"
tagged tag-long "tags: [fix, x$(printf '%030d' 0)]" "tag 2 is not a tag"
tagged tag-form 'tags: fix' "line 8 must be tags:"
tagged tag-missing 'date: 2026-03-01' "line 8 must be tags:"
tagged tag-bare 'tags: [fix, urgent]' ""
tagged tag-namespaced 'tags: [fix, team:infra]' ""
tagged tag-four 'tags: [breaking, fix, team:infra, urgent]' ""
tagged tag-hostile 'tags: [fix, $(touch PWNED) ZZTAG]' "tag 2 is not a tag"
silent "a tag is not printed" 'ZZTAG|PWNED'
isnt "a tag in an entry is not executed" test -e PWNED -o -e "$repo/PWNED"
# Structure.
defect cl02-h1 CL02 "$ENTRY" 's/^# First change$/# Another title/' "a heading that is not the title" "^$ENTRY:11: CL02 the # heading must be the title"
defect cl02-noh1 CL02 "$ENTRY" '/^# First change$/d' "no # heading" "expected the heading # <title>"
defect cl02-nowhat CL02 "$ENTRY" '/^## What changed$/d' "no What changed" "## Why appears once, after"
defect cl02-nowhy CL02 "$ENTRY" '/^## Why$/d' "no Why" "section ## Why is missing"
defect cl02-swap CL02 "$ENTRY" 's/^## What changed$/## Why/' "Why first" "## Why appears once, after"
defect cl02-again CL02 "$ENTRY" 's/^## Why$/## What changed/' "What changed twice" "appears once, before"
defect cl02-empty1 CL02 "$ENTRY" '/^The gate checks/d' "an empty What changed" "## What changed is empty"
defect cl02-empty2 CL02 "$ENTRY" '/^A change that is not/d' "an empty Why" "## Why is empty"
defect cl02-extra CL02 "$ENTRY" 's/^A change that is not.*/&\
\
## Files/' "a third section" "a heading the form does not have"
defect cl02-level CL02 "$ENTRY" 's/^## Why$/### Why/' "a section at another level" "a heading the form does not have"
defect cl02-hash CL02 "$ENTRY" 's/^The gate checks.*/# a comment in a code block/' "a line that starts with #" "a heading the form does not have"
defect cl02-indent CL02 "$ENTRY" 's/^## Why$/  ## Why/' "an indented heading" "starts in column 1"
defect cl02-quote CL02 "$ENTRY" 's/^The gate checks.*/> ## Why/' "a heading in a quote" "inside a quote or a list item"
defect cl02-list CL02 "$ENTRY" 's/^The gate checks.*/1. # Other/' "a heading in a list item" "inside a quote or a list item"
defect cl02-setext CL02 "$ENTRY" 's/^The gate checks.*/&\
====/' "an underlined heading" "only = or only -"
defect cl02-rule CL02 "$ENTRY" 's/^The gate checks.*/&\
\
---/' "a rule" "only = or only -"
defect cl02-html CL02 "$ENTRY" 's/^## Why$/<!--\
&\
-->/' "a section in an HTML comment" "raw HTML"
defect cl02-blank CL02 "$ENTRY" 's/^The gate checks.*/<what changed>/' "an unfilled placeholder" "^$ENTRY:15: CL02 an unfilled placeholder"
defect cl02-stray CL02 "$ENTRY" 's/^# First change$/&\
\
A summary./' "text before the sections" "text outside the two sections"
defect cl02-crlf CL02 "$ENTRY" "s/\$/$cr/" "CRLF line endings" "^$ENTRY:1: CL02 .*control character"
valid cl02-nul
printf 'a\000b\n' >>"$repo/$ENTRY"
rule "CL02 a NUL byte" CL02 "control character"
valid cl02-free
edit "$ENTRY" 's/^The gate checks.*/&\
#42 is closed. A list:\
\
- one\
  two <b>inline<\/b>/'
clean "CL02 text that only looks like structure" check
# Text from an entry stays out of the report, and is not executed.
valid cl02-text
edit "$ENTRY" 's/^status: .*/status: ZZTEXT $(touch PWNED)/; s/^## Why$/## ZZTEXT `touch PWNED`/; s/^The gate.*/<ZZTEXT>/'
rule "hostile text is reported" CL02 "line 6 must be status: current"
silent "text from an entry is not printed" 'ZZTEXT'
isnt "text from an entry is not executed" test -e PWNED -o -e "$repo/PWNED"
valid cl02-esc
edit "$ENTRY" "s/^A change that is not.*/red ${esc}[31m/"
rule "CL02 an escape character" CL02 "control character"
silent "a control character from an entry does not reach the output" "$esc"

# --- CL06: the project tag file -----------------------------------------------
tagfile() { # <slug> <regex> <sed expression>: one defect in a tag file with two rows
  valid "$1"
  tags_file "$ROWS"
  edit "$TAGS" "$3"
  rule "CL06 $1" CL06 "$2"
}
tagfile cl06-header "no table with the header" '/^| Tag | Meaning |$/d; /^|---|---|$/d; /^| `/d'
tagfile cl06-sep "^$TAGS:11: CL06 the line after the table header must be the separator" '/^|---|---|$/d'
tagfile cl06-last "the table header is the last line" '/^|---|---|$/,$d'
tagfile cl06-second "a second table with the header" '$s/$/\
\
| Tag | Meaning |\
|---|---|\
| `late` | Declared in a second table. |/'
tagfile cl06-cells "^$TAGS:13: CL06 a table row has two cells" 's/^| `urgent` .*/| `urgent` | a | b |/'
tagfile cl06-pipe "a table row starts and ends with" 's/^| `urgent` .*/| `urgent` | no closing pipe/'
tagfile cl06-ticks "the first cell is one tag in backticks" 's/^| `urgent` /| urgent /'
tagfile cl06-two "the first cell is one tag in backticks" 's/^| `urgent` /| `urgent` `more` /'
tagfile cl06-grammar "the first cell is one tag in backticks" 's/^| `urgent` /| `Urgent_1` /'
tagfile cl06-meaning "the meaning of the tag, is empty" 's/^| `urgent` .*/| `urgent` |  |/'
tagfile cl06-twice "declared a second time" 's/^| `urgent` .*/| `team:infra` | Again. |/'
tagfile cl06-baseline "declares a baseline tag" 's/^| `urgent` /| `security` /'
tagfile cl06-cr "control character" "s/^| \`urgent\` .*/&$cr/"
tagfile cl06-hostile "the first cell is one tag in backticks" 's/^| `urgent` .*/| `$(touch PWNED) ZZROW` | ZZROW |/'
silent "text from tags.md is not printed" 'ZZROW|PWNED'
isnt "text from tags.md is not executed" test -e PWNED -o -e "$repo/PWNED"
valid cl06-missing
rm "$repo/$TAGS"
rule "CL06 no tag file" CL06 "^$TAGS:1: CL06 the file is missing"
valid cl06-link
mv "$repo/$TAGS" "$repo/docs/tags.md" && ln -s ../tags.md "$repo/$TAGS"
rule "CL06 a tag file that is a link" CL06 "not a regular file"
silent "the tag file is left to CL06" ' CL01 '
# A fault in the tag file does not stop the other rules, and a row that fails declares
# nothing; the rows that pass still do.
valid cl06-goes-on
tags_file "$ROWS" '| `Bad` | Not a tag. |'
entry "${E2%.md}" "Second change" "fix, urgent"
edit "$ENTRY" 's/^tags: .*/tags: [bad, fix]/'
run render
rule "a fault in tags.md is reported" CL06 "^$TAGS:14: CL06 the first cell"
says "and the other rules are still checked" "^$ENTRY:8: CL02 tag 1 is not a baseline tag"
silent "and a row that passes still declares its tag" "^$DIR/$E2:"
# The rest of the file is the project's: prose, another table, other spacing.
valid cl06-prose
tags_file "$ROWS"
edit "$TAGS" 's/^| Tag | Meaning |$/|Tag|  Meaning  |/; s/^|---|---|$/| :-- | --: |/; s/^The tags of this project\.$/| Other | Table |\
|---|---|\
| x | y | z |\
\
# Any heading <b>and<\/b> text/'
entry "${E2%.md}" "Second change" "fix, team:infra"
clean "CL06 other prose, another table, other spacing" sync


printf 'change_log_test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
