Contract version: v1

# change_log.sh — Change log recorder, generator, and gate: Contract

Keeps the change log of one repository: one entry file for each change under
`docs/change_log/`, and `docs/change_log.md`, which it generates from them. `new` creates
an entry. `render` regenerates the list. `check` checks rules CL01 to CL06 and writes
nothing. `sync` merges the upstream into a clean working tree where that merge is
trivial, regenerates the list, and then checks. The rules are stated in
`docs/greenfield/change-log.md`, cited here as "the rules"; this contract states what
the script does. The script is seven files that are one unit: `change_log.sh`; four
files it sources, `change_log_list.sh` (the tag file, the entries, the list; every
verb), `change_log_new.sh` (`new`), `change_log_upstream.sh` (the upstream, CL04, CL05;
`check` and `sync`), and `change_log_merge.sh` (the merge; `sync`); and two awk
programs, `change_log_entry.awk` and `change_log_tags.awk`, which parse one file each.
The unit is in `template/tools/` of the greenfield repository and is placed under
`tools/` of every new repository. This contract and the tests (`change_log_*test.sh`,
`change_log_test_lib.sh`) are in `tools/` of the greenfield repository and are not
placed: `make test` there runs them.

## Inputs

- **`--repo DIR`** — optional, once, before the verb; default `.`. The root of the work
  tree, always taken as a path. **Trust:** operator-provided (trusted).
- **`-h`, `--help`** — prints usage and exits 0.
- **Verb** — required, once: `new`, `render`, `check`, or `sync`.
- **`--title TITLE`** — `new`, required, once. **Trust:** given by the calling agent;
  validated before anything is written, because it becomes a file name, a line of the
  entry, and a line of the list. One line of 1 to 100 bytes, no control character, no
  space at either end, no backtick, none of `"` `\` `[` `]` `<` `>` `|`. A byte above
  0x7F is taken as part of a UTF-8 character and is not checked to be one.
- **`--tags "TAG TAG"`** — `new`, required, once; separated by spaces or commas.
  **Trust:** as `--title`. 1 to 4 tags by the rules §2. A tag is printed in an error only
  after it has fitted the grammar.
- **`--at YYYY-MM-DD-hhmmss`** — `new`, optional, once: the UTC date and time the entry
  is named from; a real date and time of day. Without it the clock is read once, with
  `date -u`. **Trust:** operator-provided.
- **`--upstream REF`** — `check` and `sync`, optional, once: the upstream, in place of
  the branch `refs/remotes/origin/HEAD` names. Printable ASCII, no space, not starting
  with `-`. **Trust:** operator-provided.
- **Entry files, `DIR/docs/change_log/*.md`** — the files Git lists there as tracked, or
  untracked and not ignored. **Trust:** external content (untrusted): an entry is
  written by another agent and can arrive through a merge. Their text is read by `awk`,
  `tr`, and `wc`, compared with fixed patterns, never executed, never expanded by the
  shell, and never printed. Two things from it are written elsewhere: the title and the
  tags go into the list, the title only after it has passed the rule of `--title` and
  each tag only after it has fitted the grammar.
- **`DIR/docs/change_log/tags.md`** — the project's tags. **Trust:** untrusted, read as
  an entry is. A tag declared there is used only after it has fitted the grammar.
- **`DIR/docs/change_log.md`** — compared byte for byte with the generated text; never
  interpreted.
- **What Git answers** — ref names, path names, and the text Git prints when a merge
  fails. **Trust:** untrusted for printing. A path or a ref name is printed with `?` for
  every byte that is not printable ASCII (an escape Git wrote for one becomes `?`), cut
  to 200 characters with `...` for the rest; Git's text likewise, line by line. A commit
  hash is used only after it matched 40 lowercase hexadecimal characters.
- **`GIT_CONFIG_COUNT`** — read, to add one setting to it for the merge (behavior 15).

## Outputs

- **stdout, `check` and `sync`** — one line for each violation,
  `<path>:<line>: CL<nn> <message>`; under a CL05 line for a merge Git refused, Git's
  lines, indented and prefixed `git:`; then lines beginning `change-log:` that say what
  `sync` wrote and merged, and whether an entry file is not tracked yet; then the
  summary line, `change-log:` with the number of entries checked, the upstream ref and
  hash or `no upstream known`, and the number of violations. `<path>` is `.` for the
  repository as a whole (CL05) and `docs/change_log` for an unrecorded session (CL04). A
  message is
  fixed text carrying at most a checked hash, a path or ref printed as above, a count,
  and a position. Control characters other than tab and line feed are removed.
  `Load-bearing: make change-log shows these lines to the agent that must act on them;
  the rules §5 state their form.`
- **stdout, `new`** — the path of the entry on the first line, then `change-log:` lines.
  `Load-bearing: the agent that ran make change-log-entry reads the path there.`
- **stdout, `render`** — `change-log:` lines: the list written or current, and how many
  files are left out of it.
- **stderr** — one line beginning `change_log:` for a usage or environment error; after
  a write, a second naming what the run had written; before both, when Git stopped
  part-way through a merge, Git's lines prefixed `change_log: git:`.
- **Exit code** — `0`: no violation; entry created; list written or current. `1`:
  violations, a merge that was not made among them. `2`: bad usage, or anything that
  stops the verb from doing its work (behavior 20).
  `Load-bearing: make commit and CI pass or fail on this code.`
- **Files** — as "Filesystem writes" says, and no others.

## Behaviors

1. **Reads the command line.** `change_log.sh [--repo DIR] <verb> [options]`. An unknown
   argument, a missing verb, a missing, empty, or repeated value, or an option the verb
   does not take is exit 2.
2. **Finds the repository.** `DIR` is the root of a Git work tree; `DIR/docs` is a
   directory, `DIR/docs/change_log` (if present) a directory, `DIR/docs/change_log.md`
   (if present) a regular file, and none is a symbolic link. Anything else is exit 2
   before any write. Tested again after a merge, before the list is written: a merge can
   put a link there that leads out of the repository.
3. **CL01, names.** Lists the files under `docs/change_log/` twice over, tracked and then
   untracked and not ignored, each listing counted first with Git's exit status checked;
   a listing that fails, or whose names do not number what was counted, is exit 2. A path
   Git lists once for each stage is read once. Each file is `tags.md` or must be an
   entry by the rules §1, with a time of day from `000000` to `235959`; a name with a
   byte that is not printable ASCII is reported. A listed file missing from the working
   tree is left to CL04.
   `Load-bearing: a misnamed file is reported, not left out; a failed listing is never
   written out as an empty list.`
4. **CL06, the tag file.** `tags.md` must be a regular file with no control character but
   tab and line feed. Its table is found by its header: a line of two cells, `Tag` and
   `Meaning`, that starts and ends with `|`, spaced in any way. The next line is a
   separator row of two cells (alignment colons allowed). The rows are the lines after
   it that start with `|`, up to the first that does not; each by the rules §5. Reported:
   no header, no separator, a second header (its rows are not read), a bad row, a tag
   twice, a baseline tag. The rows that pass declare the project tags; no other line is
   read. The baseline tags are held in `change_log.sh`.
5. **CL02, entry form.** Lines 1 to 9 are exactly the front matter of the rules §1, with
   `id`, `title`, `date`, and `tags` checked against the file name and the rules §2;
   then `# <title>`, `## What changed`, `## Why`, once each in that order, with text
   under each `##` heading and none elsewhere. Blank lines are free.
   `Load-bearing: the list is built from the title and tags lines.`
6. **Narrow Markdown.** In an entry a heading is any line that starts in column 1 with
   `#` characters and then a space, a tab, or the end of the line; a fenced block is not
   interpreted. Also reported under CL02: an indented heading; a heading in a quote or a
   list item; a line of only `=` or only `-`; a line that starts with `<` (called an
   unfilled placeholder when the whole line is one `<...>`); and a control character
   other than tab and line feed, after which the file is not parsed.
7. **Generates the list.** The text of the rules §3, under a fixed front matter and a
   fixed paragraph: `## YYYY-MM-DD` headings, newest first, and under each
   `- [<title>](change_log/<file>) (<tags>)`, tags in backticks in the entry's order,
   entries in descending order of file name; or `No entries yet.` LF only. An entry is
   listed when its name passes CL01, it holds no control character, its title passes,
   and each of its tags fits the grammar, declared or not: the list depends on the
   entries alone, and the same entries give the same bytes.
   `Load-bearing: the template ships the no-entries form, and CL03 compares bytes.`
8. **`render`.** Writes the list when the file differs from the generated text or is
   missing; a current file is not touched. Says how many files are not listed. Exits 0.
9. **`new`.** Validates the title, the tags (against the baseline tags and the project
   tags validly declared now), and the time; passes the entry text through the entry
   parser, which must find the two placeholders and nothing else; and requires that
   nothing stands at the entry's name, a dangling link included. Only then writes:
   makes `docs/change_log/` if missing, creates the entry with `noclobber`, writes it,
   and regenerates the list. The name is `<date>-<time>-<slug>.md`; the slug is the
   first six runs of ASCII letters and digits of the title, lowercased, or `change`. The
   tags are sorted. Exits 2 if Git does not list the entry it created.
   `Load-bearing: an entry is never overwritten (the rules §4).`
10. **CL03.** `docs/change_log.md` exists and equals the generated text byte for byte.
11. **Finds the upstream.** For `check` and `sync`, a clone whose configuration holds a
    partial-clone setting (`extensions.partialclone`, or `promisor` or
    `partialclonefilter` on a remote) is exit 2, with an upstream or without.
    `--upstream REF` must name a commit, or exit 2. Without it: the branch
    under `refs/remotes/origin/` that the symbolic ref `refs/remotes/origin/HEAD` names,
    if it names a commit. A `refs/remotes/origin/HEAD` that is not symbolic, or points
    elsewhere, is exit 2. With no upstream, the summary says so, and adds the
    `git remote set-head origin <branch>` hint when the configuration holds a remote
    `origin`; the base of CL04 is `HEAD`. With an upstream, a shallow clone is exit 2.
12. **A damaged reference is not an absent one.** A `HEAD` that is a symbolic reference
    outside `refs/heads/` is exit 2. When `HEAD` names no commit, `HEAD` must be a
    branch that `git for-each-ref` neither lists nor complains about; the same is asked
    of the upstream branch when it names no commit, and a
    `MERGE_HEAD` file that names no commit is refused. Git's complaint is read from its
    error output, with the caller's Git trace variables unset for that one question;
    anything else Git prints there is shown as printed. Each failure is exit 2.
    `Load-bearing: "no commit" switches CL04 off, and "no upstream" CL05.`
13. **CL05.** Every unmerged path is reported. With an upstream, it must be an ancestor
    of `HEAD`, or of the first commit of a merge in progress (`MERGE_HEAD`), or be that
    commit; otherwise reported, with why no merge is made and what to do: complete the
    merge in progress; resolve the unmerged paths; on a detached `HEAD`, switch to a
    branch; on a branch with no commit, move away the work that is not committed,
    ignored files included, and run `git merge <hash>`; under `check`, commit the work
    in progress and run `make commit` outside CI. Under `sync`, behavior 14 says why.
    `Load-bearing: the other gates of make commit judge the merged tree; and following
    the words of a message loses no file.`
14. **`sync` merges only into a clean working tree.** A merge is made only when all of
    these hold, asked in this order:
    - a: the upstream is not merged, `HEAD` is a branch with a commit, no merge is in
      progress, and no path is unmerged. Otherwise behavior 13 reports.
    - b: `git status`, untracked files included and ignored files not, lists nothing:
      nothing staged, no change to a tracked path, no untracked file.
      `docs/change_log.md` is a path like any other.
    - c: `git ls-files -v` lists no path marked assume-unchanged or skip-worktree. Git
      does not look at the file of such a path, so "clean" would not be known.
    - d: the test, `git merge-tree --write-tree`, which touches neither the index nor
      the working tree, names no conflicted path but `docs/change_log.md`.
    - e: nothing stands in the working tree at a path the tested tree adds to `HEAD`
      (`git diff-tree`), and nothing that is no directory stands where such a path
      needs a directory. What the merge itself removes is not in the way: a file it
      removes, or a directory that holds nothing but files it removes, an empty one
      included. And where the merge replaces a submodule (mode 160000 at `HEAD`) by a
      file or a link, the directory of the submodule holds nothing. In a clean tree,
      what stands in the way is a file Git ignores, which Git writes over without a
      word, or a name that differs only in case; the script looks at the working tree
      and does not ask Git which.

    When b, c, d, or e does not hold, or this Git cannot make the test, no `git merge`
    is run. CL05 reports which, the paths (ten at most by name, with their number), and
    what to do. For b: commit the work in progress and run `make commit` again. For c:
    clear the mark and run it again. For a Git that cannot test: look at `git status
    --ignored`, then run `git merge <hash>` by hand. For e: move the named paths away
    and run it again; a conflict is then not reported. For d: run `git merge <hash>` by
    hand and resolve every conflicted path other than `docs/change_log.md`. The one
    other message that offers `git merge <hash>` is behavior 13's, on a branch with no
    commit.
    `Load-bearing: a merge the gate makes meets no uncommitted work, and writes over no
    file Git does not track (the rules §6).`
15. **`sync` makes the merge and verifies it.** `HEAD`, `MERGE_HEAD`, a checksum of the
    index, and the answer of `git status` are recorded, and Git runs `merge --no-commit
    --no-edit --no-autostash --no-stat --no-squash --ff -s ort <upstream commit>`, with
    `branch.<name>.mergeOptions` set empty through `GIT_CONFIG_COUNT`. The exit status
    is read, and then what happened: moved forward (a branch with no commit of its
    own), when the status is 0 and `HEAD` is the upstream commit; merged, when
    `MERGE_HEAD` is the upstream commit, `HEAD` has not moved, the index equals the
    tested tree apart from `docs/change_log.md`, and the status is 0 (1 when the list
    conflicted). Otherwise the record is taken again, and condition e is asked again.
    If nothing differs, Git refused for a reason behavior 14 did not foresee: reported
    under CL05 with Git's text and with what was compared. If anything differs, Git
    stopped part-way, and the run exits 2 naming what changed (ten paths at most) and
    undoing nothing.
    `Load-bearing: the rules §6; a merge that half happened is never reported as a
    refusal.`
16. **A merge that changes the tool.** Every file of the unit is read before the merge.
    If a merge the script made changed any of them (`cksum`), the run exits 2 and says
    to run again.
17. **`sync` regenerates and stages the list.** After the merge step, whatever it did
    short of an exit 2, the list is regenerated from the directory, never from the copy
    a merge left. While a merge is in progress, the list is staged with
    `git add -- docs/change_log.md` if it is unmerged or differs from the index copy; a
    `git cat-file` that cannot print that copy is read as "unmerged", and the list is
    staged. No other path is staged, and outside a merge nothing is.
    `Load-bearing: this resolves the conflict two branches adding entries produce.`
18. **CL04.** Applied when `HEAD` names a commit and CL05 reported nothing. The base is
    the upstream commit, or `HEAD` with none. The changed paths are those where the index
    differs from the base (`git diff --cached --name-status`) and those where the
    working tree differs from the index, untracked files that are not ignored included
    (`git status`); neither command writes. If a changed path is other than the list and
    the paths under `docs/change_log/`, one entry that passes CL01 must be a changed
    path. And each entry the base holds that is gone from the index or the working tree
    is reported.
    `Load-bearing: a change is recorded, and an entry is a record (the rules §4).`
19. **Reports.** `check` and `sync` print every violation, never stopping at the first;
    a fault in `tags.md` does not stop the other rules. A note names the entry files Git
    does not track yet. Then the summary line, and exit `0` or `1`.
20. **Fails closed.** Exits `2`, having reported no result, when: `git` or `awk` is not
    found; `DIR` is not as behavior 2 says; a file of the unit is missing; a file to be
    checked cannot be read; `awk` fails or does not reach the end of a file; a parser or
    Git prints a line the script does not recognize; any Git question fails other than
    by the exit status that means "no" (the test of a merge apart, which behavior 14
    reports); a listing read twice does not number the same; the number of entries read
    differs from the number listed; behavior 3, 11, 12, 15, or 16 says so; `cmp`,
    `sort`, `wc`, `cksum`, `date`, a write, or `git add` fails; or the run is
    interrupted (`HUP`, `INT`, `TERM`). A run that ends this way leaves no temporary
    file and no entry it created and could not write.
    `Load-bearing: exit 0 means "the change log was checked".`
21. **Pins what Git may do.** Every Git command carries `-c core.fsmonitor=false
    -c core.hooksPath=/dev/null -c maintenance.auto=false -c gc.auto=0`: no file-system
    monitor, no hook, and no maintenance process left behind.
    `GIT_LITERAL_PATHSPECS=1`, with the caller's other pathspec settings unset: a path
    is never a pattern.
    The merge runs with `-c rerere.enabled=false` and `--no-autostash`: no resolution is
    recorded and no stash entry made; and with `-c submodule.recurse=false`: Git does
    not reach into a submodule, whose uncommitted work condition b does not see. Left on,
    because the merge would otherwise give content the repository does not mean: merge
    drivers and clean, smudge, and process filters of the Git configuration, which Git
    may run during the test, the merge, `git add`, and the comparisons.

Any behavior the script performs that is not listed here is undeclared and is drift.

## Declared capability surface

- **Filesystem reads:** the files Git lists under `DIR/docs/change_log/`;
  `DIR/docs/change_log.md`, by `cmp`; existence and type tests, with no read of content,
  on `DIR`, `DIR/docs`, the listed files, the path Git names for `MERGE_HEAD`, and,
  under `sync`, each path a tested merge adds, the directories above it, and the names
  a directory holds that stands at such a path or is that of a submodule the merge
  replaces; the files of the unit (the shell and `awk` read them as programs; `cksum`
  reads them around a merge). Git reads the repository and its configuration. No other
  filesystem reads.
- **Filesystem writes:** `check` writes nothing, temporary files included: the unit
  holds no here-document and no here-string. The other verbs write only these, all
  beneath `DIR`:
  - `new`: the directory `docs/change_log`, when missing; one entry, created with
    `noclobber`, and removed again if it cannot be written.
  - `new`, `render`, `sync`: `docs/change_log.md.tmp.<process ID>`, created with
    `noclobber`, then moved over `docs/change_log.md` with `mv -f`; removed if the run
    fails or is interrupted.
  - `sync`, through `git merge-tree`: objects in the object database.
  - `sync`, through `git merge`: the index; the working tree files of the merge;
    `MERGE_HEAD`, `MERGE_MODE`, `MERGE_MSG`, `AUTO_MERGE`, and `ORIG_HEAD`; objects; and,
    when the branch moves forward, the branch and the reflogs. A merge Git refuses may
    rewrite the index file with the same entries, and for diverged branches Git then
    resets the working tree, which was clean, to `HEAD`. A merge Git stops part-way
    through leaves what it wrote.
  - `sync`, through `git add -- docs/change_log.md`: the index and one blob.
  No other filesystem writes, and no other removal.
- **Network access:** No network access. The script never runs `fetch`, `pull`, `push`,
  or any command that contacts a remote. `GIT_NO_LAZY_FETCH=1` is set, and a partial
  clone is refused (behavior 11). A filter or merge driver of the
  operator's Git configuration is the operator's program; what it contacts is outside
  this contract.
- **Subprocess invocation:** `git --no-optional-locks`, with the options of behavior 21
  and `-C DIR`: `rev-parse` (`--is-inside-work-tree`, `--show-prefix`,
  `--is-shallow-repository`, `--git-path MERGE_HEAD`, `-q --verify` of
  `<name>^{commit}` and of `<base>:<entry path>`); `symbolic-ref -q <one name>`;
  `for-each-ref --count=1 --format <ref>`; `config --get-regexp`; `ls-files`
  (`-z --cached` and `-z --others --exclude-standard` on `docs/change_log/`;
  `--unmerged`); `merge-base --is-ancestor`;
  `diff --cached --name-status --no-renames --no-ext-diff <base>`; `status
  --porcelain=v1 --untracked-files=all --no-renames --ignore-submodules=dirty`; and,
  under `sync` only: `ls-files` (`-v`, `-v -z`, `-s -z`); `merge-tree --write-tree
  --name-only --no-messages`; `diff-tree -r -z --no-renames`; `diff --cached
  --name-only`; `cat-file blob :docs/change_log.md`. Without `--no-optional-locks`,
  under `sync` only: `merge` as behaviors 15 and 21 say, and
  `add -- docs/change_log.md`. Lists read as lines carry `-c core.quotePath=true`.
  Never `commit`, `fetch`, `pull`, `push`, `rebase`, `reset`, `stash`, `checkout`,
  `switch`, `restore`, `clean`, `rm`, `update-index`, `submodule`, or `merge --abort`.
  `awk`, running one of the two programs of the unit on one file or on the entry text
  `new` built. `dirname`; `sort`; `tr`; `wc`; `cmp`; `cksum`; `date -u`; `mkdir`; `mv`;
  `rm -f`, on the temporary file and on an entry this run created and could not write.
  No other subprocess. Nothing read from an entry,
  from `tags.md`, or from Git's answers is ever executed. Neither awk program calls
  `system`, opens a pipe, reads any file but its one input, or writes anywhere but
  standard output.
- **Environment variables read:** `GIT_CONFIG_COUNT`, and `PATH` as the shell uses it.
  The script unsets `CDPATH`, `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`,
  `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`,
  `GIT_NAMESPACE`, `GIT_PREFIX`, `GIT_GLOB_PATHSPECS`, `GIT_NOGLOB_PATHSPECS`, and
  `GIT_ICASE_PATHSPECS`, and sets `LC_ALL=C`, `GIT_NO_LAZY_FETCH=1`, and
  `GIT_LITERAL_PATHSPECS=1`; for the merge alone it sets `GIT_CONFIG_COUNT` and one
  `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>`; for the question of behavior 12
  alone it unsets `GIT_TRACE`, `GIT_TRACE2`, and the variables named `GIT_TRACE_*` and
  `GIT_TRACE2_*` that the script lists. Git reads its remaining `GIT_*`
  variables and `HOME`. The Makefile, not the script, reads `CI`, `TITLE`, `TAGS`, and
  `UPSTREAM`.
- **Secrets handled:** No secrets handled.
- **Privilege escalation:** No privilege escalation.

## Assumptions for operation

- `bash` 3.2 or later with `/dev/fd`, a POSIX `awk`, `git`, and the POSIX utilities
  `cksum`, `cmp`, `date`, `dirname`, `mkdir`, `mv`, `rm`, `sort`, `tr`, and `wc`, on
  `PATH`. `sync` needs Git 2.38 or later to test a merge; an older Git makes none. The
  repository uses SHA-1 object names.
- Files are UTF-8 with LF line endings. No filter and no line-ending conversion applies
  to `docs/change_log/` or `docs/change_log.md`.
- Lengths are counted by `awk` under `LC_ALL=C`: bytes, with an awk that counts bytes
  there.
- The script reads the working tree; `git commit` takes the index. The entry `new`
  creates, and a list rewritten outside a merge, are not staged by the script.
- The script trusts Git in three things: that `git status` and `git ls-files -v`
  between them name every path whose file may differ from `HEAD`, ignored files apart;
  that the test and the merge agree; and that `git status` and the index name every
  tracked file a stopped merge wrote.
- When Git refuses a merge for a reason behavior 14 cannot foresee, its reset runs in a
  clean tree: nothing tracked or untracked was there to lose. Ignored files are not
  compared.
- Where two names differ only in case and the file system does not tell them apart,
  condition e stops a merge that adds one beside the other, a rename upstream that
  changes only the case of a name among them. For that rename the advice to move the
  path away is wrong, since the path is the tracked file: the rules §6 say to merge by
  hand in the clean tree. A merge that only changes such paths is Git's affair.
- A sparse checkout, or any marked path, gets no merge from the gate.
- A submodule is judged by the commit it is at: `git status` is asked without the work
  inside it. A merge that moves its commit leaves its working tree at the old one. One
  that the merge removes, or replaces by a directory, keeps its directory, which Git
  leaves with a warning; the paths added beneath it are judged as any added path is.
- A merge in progress is judged by its first `MERGE_HEAD` commit, and CL05 by ancestry:
  a merge by hand that discards what the upstream changed still passes.
- The operator runs `git fetch`; the script judges what the clone holds.
- A file under `docs/change_log/` that Git ignores is not checked and not listed.
- CL04 counts a path, not its meaning: an entry that is new or changed meets the rule
  whatever it says. A submodule counts when the commit it is at differs.
- The table of `tags.md` is found by its header line wherever that line stands, a fenced
  block or an HTML comment included.
- The placed Makefile gives `TITLE`, `TAGS`, and `UPSTREAM` to the script unexpanded.

## Anti-patterns this script must not do

- Do **not** pass text from an entry, from `tags.md`, or from Git's answers to `eval`, to
  a shell, or to `awk` as program text, and do not print text from the two files.
- Do **not** contact a remote: no `fetch`, no `pull`, no `push`.
- Do **not** commit, abort a merge, stash, reset, rebase, or check out, and do not stage
  any path but `docs/change_log.md` during a merge.
- Do **not** merge into a working tree that holds a change that is not committed, an
  untracked file, or a marked path, or over a file that stands where the merge adds one.
- Do **not** offer `git merge <hash>` in a message of `sync` unless conditions b, c, and
  e of behavior 14 hold, or b and c with a Git that cannot test, or the branch has no
  commit and the message says to move the uncommitted work away first.
- Do **not** say that nothing changed without having compared, or of more than was
  compared.
- Do **not** build the list from the working copy of `docs/change_log.md`.
- Do **not** overwrite or correct an entry.
- Do **not** start a merge while one is in progress, and do not make a merge the test
  did not find trivial.
- Do **not** grade. No rule may read, require, or print a severity, a rank, or a score.

## Revision rules

- Removing a behavior, an input, an output, or an assumption requires a deliberate
  version bump.
- Added assumptions never relax previous assumptions.
- Added capabilities require operator review.
- A version is ratified only after review; one change is one bump.
- Each file of the unit names in its header the contract version it was built against.
- The unit is greenfield-owned: it is changed in the greenfield repository, with this
  contract and the tests, not in a repository that greenfield stamped.
- A change to the entry form, the tag grammar, the baseline tags, or the rules changes
  `docs/greenfield/change-log.md` in the same change.

## Change log

- **v1** — 2026-11-18: initial version. Run by its author under bash 3.2,
  BSD awk 20200816, GNU make 3.81, and Git 2.50.1 on macOS; not run under mawk or gawk,
  on Linux, or with an older Git. Before ratification the merge was simplified: `sync`
  merges only into a clean working tree. And this contract and the tests moved from
  `template/tools/` to `tools/` in the greenfield repository: they are no longer placed
  in a new repository.
  Review: 2026-11-18, two subagents that did not write the change, six rounds each: one
  read the code against this contract, the other ran the script's Git command lines in
  scratch repositories. Verdict of both on the last round: may be ratified, no flag
  above LOW open. Rounds 1 to 5 found ways for a merge made over uncommitted work to
  destroy what Git does not track (an ignored file written over; untracked work lost
  to the stash and reset Git runs when it refuses a merge of diverged branches; an
  edited assume-unchanged file; a stray file in a submodule's directory; names
  differing only in case), and messages whose advice lost a file when followed. Those
  were resolved by code until the owner chose the simpler merge, which removed that
  code: conditions b to e of behavior 14 stand in its place. Last round, 7 LOW flags,
  resolved by wording here or in the rules: which messages offer a merge by hand; the
  advice for a rename upstream that changes only case; the advice for a sparse
  checkout; "makes it" without "when trivial"; what the merge does in a submodule's
  directory; staging a fix before `git commit --no-edit`. Recorded and left: after a
  merge that moves a submodule's commit, its working tree is at the old one. Neither
  reviewer could run the script directly (the sandbox refuses `bash <script>`); both
  ran the suites through `make`.
