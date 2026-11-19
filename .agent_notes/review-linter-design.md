---
name: review-linter-design
description: Why template/tools/review_lint works the way it does; the choices a later change is most likely to undo by accident.
type: design
date: 2026-11-18
---

The contract, `tools/review_lint_contract.md`, says what the linter does. This
note says why, for the choices that are not obvious from it.

- **No here-document and no here-string, in either script.** Bash before 5.1 (macOS ships
  3.2) implements both with a temporary file under `$TMPDIR`. A script that uses one
  breaks its "writes nothing" claim and fails where `$TMPDIR` is unusable. Loops read
  from a process substitution, as in `< <(printf '%s\n' "$var")`. The tests may use
  here-documents; the scripts may not.
- **RL09 compares content, not commit counts.** The linter collects the distinct blob IDs
  the path has had (`git log --full-history -m --raw`), and reports more than one. Do
  not count the commits that touch a record: a record that arrives through a merge
  commit is counted twice under `--full-history`, so every pull request merged with a
  merge commit would fail. The test "a record that arrived through a merge commit"
  guards this.
- **`hash-object --no-filters`, not `git diff --quiet`.** `diff` can refresh the index,
  which is a write. Filters are off so that Git never runs a configured clean filter on a
  file an untrusted reviewer wrote.
- **Fail closed.** An awk error, a failed Git question, or a line the script does not
  recognize is exit 2, never a pass. A gate that cannot check must not look green.
  Read a Git question as exit 0, exit 1, or anything else, and make "anything else"
  exit 2: `if git ...; then` and `[ "$(git ...)" = true ]` both read a failing Git as
  "no". The tests put a stand-in `git` on `PATH` that fails or misanswers one question
  (`shim` in `review_lint_test.sh`); use it for every new question.
- **`HEAD` naming no commit is not "a new repository".** An orphan branch and a damaged
  branch give the same answer while a history exists. The linter takes a repository for
  new only when `for-each-ref` prints nothing at all.
- **Fences and headings are deliberately narrower than CommonMark.** A fence opens only
  in column 1; an indented heading and a setext underline are violations, not headings.
  The aim is that the linter and a Markdown renderer can never disagree about where a
  finding starts: a finding hidden from one of them is the attack.
- **Messages are fixed text.** Nothing read from a record is printed except an ID or a
  hash that already matched its pattern, and control characters are stripped from all
  output: a record must not be able to write to the terminal of the agent reading the
  report.
- **What a renderer and the linter could read differently is refused outright:** raw
  HTML at the start of a line (a fence line inside an HTML block is not a fence), an
  indented fence line (it closes a fence for a renderer), a heading in a quote or a
  list item, a carriage return or a NUL. Each is a way to show a reader a finding the
  linter never sees. Expect more of the kind. Answer one by narrowing the form, not by
  making the parser cleverer.
- **RL09 asks "is every record the history ever held still a regular file here",
  not "was a record deleted in a commit".** The second question misses uncommitted
  deletions and a record replaced by a submodule entry.
- **A shallow or a partial clone is exit 2.** The placed CI fetches the full history
  for this reason; do not remove `fetch-depth: 0` from it.
- **`form: 1`** exists so that a later form can be told from this one. How the linter
  carries two forms is open: `backlog/G004-upgrade-path.md`.
- **The tests are two files:** `review_lint_test.sh` holds the cases and sources
  `review_lint_test_lib.sh`, which holds the fixtures and helpers. As one file they pass
  the 500-line warning level. Add cases as one-line `defect`, `rowdefect`, or `acted`
  calls.

**How to apply:** before changing the linter, read this and the contract's assumptions.
A change to the form moves the contract, both blank forms, both awk programs, the tests,
and `adversarial-review.md` together.
