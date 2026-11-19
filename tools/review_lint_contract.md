Contract version: v2

# review_lint.sh — Review record linter: Contract

Checks every file under `reviews/` of one repository against the form in
`docs/greenfield/adversarial-review.md` §6 and §7, and prints one line for each departure.
It reads files and asks Git questions. It changes nothing. The script is three files that
are one unit: `review_lint.sh` and the two awk programs it runs,
`review_lint_record.awk` and `review_lint_disposition.awk`, which parse one file each and
print what they find for the script to check. The unit is in `template/tools/` of the
greenfield repository and is placed under `tools/` of every new repository. This
contract and the tests (`review_lint_test.sh`, `review_lint_test_lib.sh`) are in
`tools/` of the greenfield repository and are not placed: `make test` there runs them.

## Inputs

- **`--repo DIR`** — optional command-line argument; default `.`. The directory that
  holds `reviews/`. Always taken as a path: a relative value is read as `./DIR`.
  **Trust:** operator-provided (trusted).
- **`-h`, `--help`** — optional. Prints usage and exits 0.
- **Files under `DIR/reviews/`** — the files Git lists there as tracked, or untracked and
  not ignored. **Trust:** external content (untrusted): a review record is written by
  another agent. Their text is read by `awk`, by `tr` and `wc` to count bytes, and by
  `git hash-object` to hash a committed record. The text is compared with fixed
  patterns and is never executed and never expanded by the shell. One thing taken from
  a file's text reaches a command as an argument: a commit hash, which is passed to Git
  only after it has been checked to be exactly 40 lowercase hexadecimal characters. The
  finding IDs passed to awk are not taken from the text: the record parser builds each
  one from the number in the file name and the position of the entry. A backlog path
  taken from a file is tested for existence only after it has been checked to match
  `backlog/R<NN>-F<MM>-<slug>.md`. File names are untrusted too: a name is printed as
  it is only after it has been found to hold nothing but printable ASCII, and otherwise
  with every other byte replaced by `?`.

## Outputs

- **stdout** — one line for each violation, `reviews/<file>:<line>: RL<nn> <message>`,
  then one summary line beginning `reviews-lint:`. Control characters other than tab
  and line feed are removed. A message is fixed text. Besides that text it carries at
  most: a finding ID, a review ID, or a review number that the script built or checked
  against its pattern; a commit hash that matched its pattern; a file name under
  `reviews/`, printed as the Inputs section says; a count the script made; and a word
  from one of the fixed lists of the form (a key, a section name, a state, a
  disposition).
  `Load-bearing: the Makefile target reviews-lint shows these lines to the agent that must
  correct the record.`
- **stderr** — a usage or environment error, one line beginning `review_lint:`. The
  shell, `awk`, or `git` may add a line of its own before it.
- **Exit code** — `0` no violations; `1` one or more violations; `2` anything that stops
  the check from being made: bad usage, `DIR` is not a directory or is not inside a Git
  work tree, `DIR/reviews/` is missing or is a symbolic link, `git` or `awk` is not
  found, `DIR` cannot be entered, the directory of the script cannot be found, an awk
  program is not beside the script, `sort` fails, or the failures of behavior 12.
  `Load-bearing: make reviews-lint, and through it make commit and CI, pass or fail on this
  code.`

## Behaviors

1. **Lists the files.** Asks Git for the files under `reviews/` that are tracked, or
   untracked and not ignored. A listed file that is missing from the working tree is
   left to RL09.
2. **RL01, file names.** Reports any file that is not `README.md`, `TEMPLATE-record.md`,
   `TEMPLATE-disposition.md`, a record `R<NN>-<slug>.md` (two digits; a slug of one to six
   lowercase words of letters and digits joined by hyphens, not `disposition`), or a
   disposition file `R<NN>-disposition.md`. Reports anything Git lists that is not a
   regular file (a symbolic link, a directory, a submodule entry), a name holding a
   character that is not printable ASCII, a file in a subdirectory, two records with
   one number, a disposition file with no record, and a gap in the numbers, which run
   from `01`.
   `Load-bearing: a misnamed record is reported, not silently skipped.`
3. **RL02, front matter of a record.** Line 1 is `---`. Then exactly these keys, one to a
   line, in this order, then `---`: `id` (`review-r<NN>`), `title` (`"R<NN>. <subject>"`),
   `is_source_of_truth` (`true`), `derives_from` (`[review-rubric]`), `status`
   (`current`), `review` (`R<NN>`), `form` (`1`), `reviewed_commit` (40 lowercase
   hexadecimal characters), `base_commit` (the same, or `none`; a hash when `scope` is
   `fix`), `scope` (`design-increment`, `whole-design`, `change`, `fix`, `milestone`),
   `passes` (`per-item`, `cross-item`, or `per-item, cross-item`), `date` (`YYYY-MM-DD`
   with a month from 01 to 12 and a day from 01 to 31), `reviewer` (not empty). `<NN>` is
   the number in the file name.
4. **RL03, commits exist.** Reports a `reviewed_commit`, a `base_commit`, or a hash in the
   `Where` cell of a `fixed` or `verified` row that Git does not have as a commit.
   A hash that names an annotated tag pointing at a commit is taken as that commit.
   `Load-bearing: this is the check that a review is pinned to a real commit.`
5. **RL04, structure of a record.** After the front matter: one `#` heading equal to the
   title without its quotes; then the `##` sections `Scope`, `Prior findings`, `Findings`,
   `Remarks`, `Verification and limits`, each once, in that order; no other heading
   outside a finding entry; no section empty (an empty `Prior findings` is reported
   under RL06 and an empty `Findings` under RL05). A heading is a line that starts in
   column 1 with `#` characters followed by a space, a tab, or the end of the line.
   Reported as well: a heading that is indented; a line of only `=` or only `-`, which
   would make the line above it a heading; and a fenced code block that is not closed. A
   line inside a fenced code block is not a heading. A fence opens with three or more
   backticks or tildes in column 1 (a backtick fence has no backtick after its opening
   run) and closes with a line of at least as many of the same character, with nothing
   after them but spaces or tabs.
   Reported too, because a Markdown renderer would read them as structure and this
   script would not: a fence line that is indented (inside a fence, only one that
   could close it; inside the field block of a finding it is reported under RL05); a
   line outside a fence that starts with `<`, indented or not (raw
   HTML); a quote or a list item that holds a heading, a fence, or a rule (a line of
   only `=` or only `-`); and, anywhere in the file, a control character other than tab
   and line feed (a carriage return, a NUL, an escape).
6. **Unfilled placeholders.** A front matter value, a title, a field value, a table cell,
   or a whole line outside a fence that is `<`, text without `<` or `>`, and `>` is what
   the blank forms hold. A file that holds one is never clean: the placeholder is
   reported under the rule for that part of the file, or the part is reported
   itself.
7. **RL05, finding entries.** `## Findings` holds `None.` alone, or one or more entries.
   An entry is `### R<NN>-F<MM> <title>` with `MM` running from `01` without gaps; then, as
   its first content, a fenced block with the info string `finding` holding exactly
   `axis`, `also`, `pass`, `location`, `touches` in that order; then `#### Observation`,
   `#### Evidence`, `#### Consequence`, `#### Resolved when`, in that order, none empty.
   `axis` is one of the per-item values `completeness`, `correctness`, `security`,
   `verification-integrity`, `scope`, `maintainability`, `documentation`, `reliability`;
   the cross-item values `consistency`, `composed-security`, `distributed-malice`,
   `style-coherence`, `coverage-adequacy`, `contract-coherence`; or `other`. `also` is
   `none` or a comma-separated list of those values, none repeated and none equal to
   `axis`. `pass` is `per-item` or `cross-item`, is one the front matter's `passes`
   names, and is the pass the axis belongs to (`other` belongs to either). `location` is
   not empty. `touches` is a comma-separated list, none repeated, of `interface`,
   `data-format`, `persisted-data`, `trust-boundary`, `component-boundary`,
   `test-harness`, `core-dependency`, `local`; `local` stands alone.
8. **RL06, prior findings.** `## Prior findings` holds `None.` alone, or a table with the
   header cells `Finding`, `Result`, `Evidence`, a separator row of three cells, and one
   or more rows whose first cell is a finding ID that exists in a lower-numbered record,
   whose second is `resolved`, `partly-resolved`, or `not-resolved`, and whose third is
   not empty. No
   finding has two rows. A table is required when `scope` is `fix`.
9. **RL07, disposition file.** Every record has `R<NN>-disposition.md`. Its front matter
   is exactly `id` (`review-r<NN>-disposition`), `title` (`"R<NN> disposition"`),
   `is_source_of_truth` (`true`), `derives_from` (`[review-r<NN>]`), `status`
   (`current`), `review` (`R<NN>`), `form` (`1`). Then `# R<NN> disposition`,
   `## Dispositions` with a table whose header is
   `| Finding | Blocks MVP | Expensive later | Disposition | State | Where |` and a
   separator row, then `## Reasons`, and no other heading except the `###` headings
   RL08 requires. Headings, fences, and the lines a renderer would read as structure
   are treated as in behavior 5, and reported under RL07. In both tables the cells of
   the header and of the separator may be spaced in any way, and a separator cell may
   carry alignment colons.
10. **RL08, disposition rows.** The table has exactly one row for each finding of the
    record, in the record's order. `Blocks MVP` and `Expensive later` are `yes` or `no`.
    `Disposition` is `fix-now`, `later`, or `declined`; `later` only when both answers are
    `no`. `State` is `open`, `fixed`, or `verified` for `fix-now`; `open`, `fixed`,
    `verified`, or `closed` for `later`; `closed` for `declined`. `Where` is `-` for
    `fix-now` and `open`; holds a 40-character commit hash for `fixed`; holds a hash and
    the ID of a review whose "Prior findings" judges this finding `resolved` for
    `verified`; holds the path of an existing regular file
    `backlog/<this finding's ID>-<slug>.md` for `later` and `open`; and is neither empty
    nor `-` for `closed`. `## Reasons` holds one `### <finding ID>` section for each row,
    in order, none empty; or `None.` alone when the record has no findings.
    `Load-bearing: this is the check that every finding is tracked.`
11. **RL09, a record does not change.** For each record, reads the history of `HEAD` for
    every content the file has had, comparing each merge with each of its parents, with
    the settings that could change what Git prints pinned. Reports a record that has
    had more than one content, and a committed record whose working copy differs from
    the committed content. Reports every record path that the history holds and that is
    not a regular file in the working tree now: deleted, renamed, or replaced, whether
    or not that change has been committed. A record not yet committed is not reported,
    and RL09 is not applied in a new repository: one where `HEAD` names no commit and
    Git lists no reference.
    `Load-bearing: adversarial-review.md rests on a record never changing after its
    first commit; this is the check that it has not.`
12. **Fails closed.** Exits `2`, having reported no result, when a record or a
    disposition file cannot be read; when awk exits with an error or does not reach the
    end of a file; when a Git question that must be answered fails, which includes
    Git not answering `false` to whether the clone is shallow, Git failing to read its
    configuration, and Git failing to say whether the repository has a commit; when
    `HEAD` names no commit and Git prints anything at all when asked for the
    references (a reference, as on an orphan branch; a complaint about a damaged one;
    any other line, a trace included), because a history may exist that cannot be read
    from there; when a parser or Git prints a line the script does not recognize; when
    the number of records it went through, reading the records or reading their
    disposition files, differs from the
    number it listed; and in a shallow or a partial clone, where the history or the
    objects the check needs may be missing.
    `Load-bearing: make commit and CI treat exit 0 as "the records were checked"; a run
    that could not check must never produce it.`
13. **Reports and exits.** Prints every violation, then the summary line, and exits `0` or
    `1` as the Outputs section says. It does not stop at the first violation.

Any behavior the script performs that is not listed here is undeclared and is drift.

## Declared capability surface

- **Filesystem reads:** the files under `DIR/reviews/` that Git lists; existence and type
  tests, with no read of content, on `DIR`, on `DIR/reviews`, on the listed files, on
  every record path the history of `HEAD` holds, on
  `DIR/backlog/R<NN>-F<MM>-<slug>.md` paths named in a `Where` cell, and on the two awk
  programs beside the script; and those two programs, which awk reads as its program.
  The script enters `DIR` and its own directory to resolve their paths. Git reads the
  repository and its own configuration. No other filesystem reads.
- **Filesystem writes:** No filesystem writes. No temporary files: the script uses no
  here-document and no here-string, which bash before 5.1 would implement with a file
  under `$TMPDIR`.
- **Network access:** No network access. A partial clone, in which Git could fetch a
  missing object, is refused: a repository whose configuration holds
  `extensions.partialclone`, or `promisor` or `partialclonefilter` on any remote, is
  taken for one, whatever the value of the setting. `GIT_NO_LAZY_FETCH=1` is set as
  well.
- **Subprocess invocation:** `git --no-optional-locks -c core.fsmonitor=false -C DIR` with
  `rev-parse`, `ls-files`, `config --get-regexp`, `for-each-ref`, `cat-file -e`,
  `log --raw` (with
  `log.showRoot`, `log.follow`, `log.showSignature`, and `log.diffMerges` pinned by
  `-c`), and `hash-object --no-filters` without `-w`: never a subcommand or an option
  that writes,
  refreshes the index, starts a file-system monitor, or runs a filter, a diff driver, or
  a hook. `awk`, running one of the two programs beside the script on one file at a time.
  `dirname`, to find those programs. `sort`, on the script's own list of record numbers
  and paths. `tr`, on the violation lines and the error line the script prints; and `tr`
  and `wc`, on one reviewed file at a time, to count its control characters. No other
  subprocess. Nothing read from a reviewed file is ever executed. Neither awk program
  calls `system`, opens a pipe, reads any file but its one operand, or writes anywhere
  but standard output.
- **Environment variables read:** none by the script itself, beyond `PATH` as used by the
  shell to find the commands above. For itself and the commands it runs, it unsets
  `CDPATH`, `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`,
  `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`, `GIT_NAMESPACE`, and
  `GIT_PREFIX`, and sets `LC_ALL=C` and `GIT_NO_LAZY_FETCH=1`. Git, as always, reads its
  remaining `GIT_*` variables and `HOME` to find its configuration.
- **Secrets handled:** No secrets handled.
- **Privilege escalation:** No privilege escalation.

## Assumptions for operation

- `bash` 3.2 or later with `/dev/fd` (process substitution without a named pipe), a POSIX
  `awk` (BSD awk, mawk, or gawk), `git`, and the POSIX utilities `dirname`, `sort`, `tr`,
  and `wc`, all on `PATH`. The script tests for `git` and `awk` before it starts, and
  not for the other four.
- Files are UTF-8 with LF line endings. A file with CRLF endings is reported as violating
  the form. Records are stored in Git as they are in the working tree: no filter and no
  line-ending conversion applies to `reviews/`.
- The repository uses SHA-1 object names. Git is 2.15 or later, which can say whether
  a clone is shallow; with an older Git the script exits `2` (behavior 12).
- `DIR` may be the root of a work tree or a directory beneath it; `reviews/` and
  `backlog/` are read beneath `DIR`.
- A file under `reviews/` that Git ignores is not checked. It cannot be committed without
  force, and once tracked it is listed.
- RL09 reads the history `HEAD` can reach. It does not see a record whose adding commit
  was amended or otherwise rewritten, or one removed by rewriting history.
- A changed record that was committed stays reported: restoring its text does not clear
  it, because the history then holds both contents. The gate reports the change before
  the commit is made; after it, the owner decides how the history is repaired.
- The script reads the working tree. `git commit` takes the index: the two can differ.
- One Git question is asked without a check of its own, because the same question was
  answered just before: the second listing of `reviews/`.
- A backlog file named in a `Where` cell is tested for existence only, not for being
  tracked.
- The form is plain Markdown read line by line. Raw HTML that does not start a line is
  content like any other, as is a date such as `2026-02-31`.
- A line that consists of one `<...>` and nothing else is taken for an unfilled
  placeholder, and any other line outside a fence that starts with `<` for raw HTML, in a
  record or a disposition file. An unfilled placeholder is reported as behavior 6
  says: under RL02, RL04, RL05, or RL06 in a record, and RL07 or RL08 in a
  disposition file. Write such text inside a fence or a sentence.

## Anti-patterns this script must not do

- Do **not** pass text from a reviewed file to `eval`, to a shell, or to `awk` as program
  text. Records are written by other agents and are untrusted.
- Do **not** correct a file. A reviewer's record is never edited, by this script or by
  the working agent.
- Do **not** stop at the first violation: the agent correcting a record before its first
  commit needs all of them.
- Do **not** skip a file it cannot classify or cannot read. An unknown file is a
  violation; an unreadable one stops the run.
- Do **not** grade. No rule may read, require, or print a severity, a rank, or a score.

## Revision rules

- Removing a behavior, an input, an output, or an assumption requires a deliberate
  version bump.
- Added assumptions never relax previous assumptions.
- Added capabilities require operator review.
- A version is ratified only after review; one change is one bump.
- The script's file header references the contract version it was built against.
- A change to the form a record or a disposition file takes changes the `form` value,
  the blank forms, and `docs/greenfield/adversarial-review.md` in the same change.
- The unit is greenfield-owned: it is changed in the greenfield repository, with this
  contract and the tests, not in a repository that greenfield stamped.

## Change log

- 2026-11-18: this contract and the tests moved from `template/tools/` to `tools/` in
  the greenfield repository, and are no longer placed in a new repository; the header
  of each file of the unit says where they are kept. No input, output, behavior,
  capability, or assumption changed, so the version did not.
- **v2** — 2026-11-18: Git questions that failed open now fail closed
  (behavior 12): a Git that fails to say whether the clone is shallow, or says anything
  but `false`; a Git that cannot read its configuration; a Git that cannot say whether
  the repository has a commit; `HEAD` naming no commit while a reference exists (an
  orphan or a damaged branch), asked with `for-each-ref`, a subcommand added to the
  capability surface; and a line of `git log` output that is not a raw line, an empty
  line, or a hash. A `promisor` or `partialclonefilter` setting of any value is taken
  for a partial clone, and the message says so. The usage text
  states exit code 2 as Outputs does, and the shallow-clone message says who fetches.
  Declared what the script already did and v1 left out or misdescribed: the existence
  tests on `DIR`, on the awk programs, and on record paths from the history; `dirname`,
  `sort`, `tr`, and `wc` as required utilities; what a message may carry; an annotated
  tag under RL03; the rule an unfilled placeholder is reported under; and eleven
  sentences corrected against the code (finding IDs are built by the parser; `tr`,
  `wc`, and `hash-object` read a reviewed file; names printed with `?`; the extra
  stderr line; `DIR` not a directory; empty sections under RL05 and RL06; a closing
  fence with trailing blanks; the `<` rule for indented lines; rule lines; behavior 12;
  operands of `sort`, `tr`, and `wc`). The v1 entry below gives the oldest Git that was
  run as 2.45; the Git that was run is 2.50.1, and nothing older has been run.
  Review: 2026-11-18, the second reviewer of v1, resumed over three rounds (a subagent
  that did not write the change), SAFE TO RUN each round; 9 flags, all LOW, none
  CRITICAL, HIGH, or MEDIUM. Resolved and confirmed by the same reviewer: a partial
  clone was claimed where only the setting was known; the `HEAD` question still failed
  open; the placeholder rule, the exit-2 list, and two sentences on tables and fences
  were inexact; eight statements had no test (tests added, one of which found that
  an unrecognized `git log` line was skipped); the change-log entry was incomplete; a
  damaged or orphan branch read as a new repository. Resolved by the reviewer's own
  second option, not re-reviewed: with Git tracing on, a new repository is refused,
  and the message and behavior 12 now say that anything Git prints is the cause.
  Accepted, untested: an unreadable disposition file; a parser that ends without its
  `E` line; `git` or `awk` missing from `PATH`; a `TMPDIR` that does not allow
  execution; a new repository with a remote fetched and nothing checked out is
  refused. Run by the reviewer: Git 2.50.1 only.
- **v1** — 2026-11-18: initial version.
  Review: 2026-11-18, fresh subagent, SAFE WITH CONDITIONS; 12 flags, all resolved
  before the next round: here-documents wrote temporary files on bash before 5.1; an
  awk or `git log` failure was ignored and the run could pass; fences and headings let
  a crafted record hide a finding (longer fences, tildes, indented and tab headings,
  underlines); inherited `GIT_DIR`; links and control characters in names; any backlog
  file satisfied a `later` row; RL09 could refresh the index; tests asserted rule
  numbers only and accepted an empty `also`, an impossible date, an axis under the wrong
  pass, duplicate rows, and unfilled forms. The `form` key was added in this round.
  Review: 2026-11-18, a second fresh subagent, three passes, SAFE WITH CONDITIONS, then
  no CRITICAL, HIGH, or MEDIUM flag open; 19 flags. HIGH, resolved: a record replaced
  by a non-file index entry passed RL09 (behaviors 2 and 11, tested); a partial clone
  was not refused as claimed (now detected by its promisor remote, tested). MEDIUM,
  resolved: an uncommitted deletion or rename of a committed record passed; a fence
  line inside an HTML block, an indented fence line, and a bare carriage return or NUL
  each hid a finding from the linter that a renderer would show. LOW, resolved: Git
  log settings pinned; headings in quotes and list items; non-ASCII file names; shallow
  clones refused; table spacing; test gaps; contract wording; a parser that ends early;
  indented fences inside a longer fence; code spans at the start of a list item; rules
  missing from adversarial-review.md §6. LOW, accepted and declared under Assumptions:
  a committed change to a record stays reported; the backlog file is tested for
  existence only; the working tree is read, not the index; two Git questions are not
  separately checked; raw HTML that does not start a line is content. Not run by any
  reviewer: mawk, gawk, Linux, and a Git older than 2.45 (backlog G002 in greenfield).
