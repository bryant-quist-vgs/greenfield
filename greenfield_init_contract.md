Contract version: v4

# greenfield_init.sh — Place the default repository: Contract

Copies the greenfield default repository (the `template/` directory beside the script)
into a new project's directory, replacing five tokens with the project's name, its owner,
a date, and the greenfield version and commit, and records what was placed in
`.greenfield-stamp`. It never overwrites a file, never follows a symbolic link in the
target, and runs nothing from the template or the target.

## Inputs

- **`--target DIR`** — required. The new project's directory; created if absent. It is
  always taken as a path: a relative value is read as `./DIR`, so `-` and names that
  begin with a hyphen are directories, and `CDPATH` is not consulted.
  A value holding a control character is a usage error. A target that is itself a
  symbolic link to a directory is followed: the operator named it.
  **Trust:** operator-provided (trusted). Its existing contents are **untrusted**: they
  are tested for existence and type, and one file (`.gitignore`) is searched for a marker
  line; nothing in the target is executed or sourced.
- **`--name NAME`** — required. The project name written into the documents. **Trust:**
  operator-provided, and validated because it is written into files and passed to `sed`:
  1 to 80 bytes; letters, digits, space, `.`, `_`, `-`; starting with a letter or digit.
- **`--owner OWNER`** — required. The owner's name written into the documents. **Trust:**
  operator-provided, and validated for the same reason: 1 to 80 bytes; no control
  character; none of `\`, `|`, `&`, `"`, `` ` ``, `$`, `<`, `>`; not containing `@@`.
- **`--date YYYY-MM-DD`** — optional; default today's local date. Validated by shape.
- **`--template DIR`** — optional; default `template/` beside the script. **Trust:**
  operator-provided (trusted): it is greenfield's own content. It is still checked, as
  behavior 2 says, because a mistake there would be copied into every new repository.
- **`--keep-existing`** — optional flag. Keep files that already exist in the target and
  place the rest.
- **`--dry-run`** — optional flag. Print the plan and write nothing.
- **`-h`, `--help`** — optional. Prints usage and exits 0.
- **`VERSION`** — the file beside the script. Its first line is the greenfield version,
  `N.N.N`.

## Outputs

- **Files under the target** — every file of the template at the same relative path, with
  the tokens replaced.
  `Load-bearing: the stamped repository's gates (make change-log, docs-lint,
  llm-size-guard, reviews-lint) expect these files as placed; make template-check in
  this repository verifies that they pass on a fresh stamp.`
- **`<target>/.greenfield-stamp`** — six lines: a comment, then `greenfield_version`,
  `greenfield_commit`, `project`, `owner`, and `date`, each as `key = "value"`.
  `Load-bearing: the stamped repository's documents cite this file as the record of what
  it was started from, and its presence is how a second run is refused.`
- **stdout** — one line for each file: `wrote`, `appended`, or `kept` and the relative
  path, then the next steps. In a dry run: `would write`, `would append`, or `would keep`
  for each file, then the line `dry run: nothing was written`, and no next steps.
- **stderr** — a refusal or an error. The script's own messages begin
  `greenfield_init:`; the shell or a command it runs may add a line of its own. A
  refusal over the target lists every blocked path and every conflicting path.
- **Exit code** — `0` placed, or a dry run that found nothing to refuse; `1` refused
  (nothing was written); `2` bad usage or environment.
  `Load-bearing: make template-check and any operator script branch on this code.`

## Behaviors

1. **Validates the values it will write.** `--name`, `--owner`, and `--date` are checked
   as the Inputs section says, before anything else is read. A value that fails is a
   usage error (exit 2).
   `Load-bearing: the validation is what makes the sed replacement safe; the values reach
   sed unescaped.`
2. **Checks the template.** Refuses (exit 1) a template that holds a symbolic link or
   any other non-regular file; a path with a control character in it; a file
   `.greenfield-stamp` at its top; an unknown `@@NAME@@` token, in a text or a binary
   file; or no files. Stops (exit 2) when the template directory is missing, or a
   directory or a file in it cannot be read. Files named `.DS_Store` are ignored and
   never copied.
   `Load-bearing: the plan is kept as lines with tab-separated fields, so a path with a
   newline or a tab in it could otherwise forge a line of the plan.`
3. **Reads the version and the commit.** The version is the first line of `VERSION`; a
   file that is missing or unreadable, or a line that is not `N.N.N`, is an error
   (exit 2). The commit is `git rev-parse HEAD` of
   the script's directory when that directory is the root of a Git work tree and the
   answer is 40 hexadecimal characters, with `+dirty` appended when
   `git status --porcelain` prints anything. Otherwise it is `unknown`: no Git, not a
   work tree, no commit yet, or a repository whose hashes are not SHA-1.
4. **Refuses a target that is not a directory, or is already stamped.** A target that
   exists and is not a directory is refused. A target holding `.greenfield-stamp`, as
   a file or a link, is refused whatever the flags.
5. **Plans every file before writing any.** For each template file:
   - a parent directory in the target that is a symbolic link or not a directory, or a
     destination that is a symbolic link or exists and is not a regular file: **refused**,
     whatever the flags;
   - an existing `.gitignore` without the marker line: the rules will be **appended**;
     with the marker line: refused;
   - any other existing file: a **conflict**, refused unless `--keep-existing`, in which
     case the file is **kept**;
   - otherwise the file will be **written**.
   A refusal lists the blocked paths and the conflicts, and writes nothing.
   `Load-bearing: no file in the target is ever overwritten or replaced.`
6. **Writes.** Creates the target and the directories it needs, and writes each planned
   file with the five tokens replaced: `@@PROJECT_NAME@@`, `@@OWNER@@`, `@@DATE@@`,
   `@@GREENFIELD_VERSION@@`, `@@GREENFIELD_COMMIT@@`. Files are created with the shell's
   no-clobber setting, so a file that appeared after the plan was made stops the run
   (exit 2) and is not overwritten.
   `Load-bearing: the stamp is written only when every planned file was handled, so a
   stamp means a complete placement.`
7. **Appends to an existing `.gitignore`.** Adds a blank line, the line
   `# >>> greenfield default rules >>>`, the template's rules, and the line
   `# <<< greenfield default rules <<<`. The existing lines are left as they were. This is
   the only existing file the script modifies.
8. **Writes the stamp** after the files, also without overwriting.
9. **Reports.** Prints a line for each file, then the next steps; when files were kept,
   says they must be reconciled by hand.
10. **Dry run.** With `--dry-run`, performs behaviors 1 to 5, prints the plan, and creates
    and writes nothing, the target directory included.

Any behavior the script performs that is not listed here is undeclared and is drift.

## Declared capability surface

- **Filesystem reads:** the template directory (every file); `VERSION` beside the script;
  existence and type tests on paths under the target; the content of an existing
  `<target>/.gitignore`, searched for the marker line. No other filesystem reads.
- **Filesystem writes:** under `--target` only, apart from the directories above a
  target that does not exist yet, which are created with it: the target directory and the
  template's subdirectories (created); the template's files and `.greenfield-stamp`
  (created, never overwritten); and `.gitignore` (appended to, when it exists). No
  temporary files: the script uses no here-document and no here-string, which bash
  before 5.1 would implement with a file under `$TMPDIR`. No other filesystem writes.
- **Network access:** No network access.
- **Subprocess invocation:** `git --no-optional-locks -c core.fsmonitor=false -C <script
  directory>` with `rev-parse` and `status --porcelain`, to learn the greenfield commit;
  Git reads that repository and its own configuration, and with those two settings
  neither refreshes the index nor starts a file-system monitor. `find`, `sort`, `grep`,
  `sed`, `mkdir`, `dirname`, and `date`. No command is run in or from the target,
  and nothing from the template is executed. No other subprocess.
- **Environment variables read:** none by the script itself, beyond `PATH` as used by the
  shell to find the commands above. For itself and the commands it runs, it unsets
  `CDPATH`, `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`,
  `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`, `GIT_NAMESPACE`, and
  `GIT_PREFIX`, and sets `LC_ALL=C`.
  Git, as always, reads its remaining `GIT_*` variables and `HOME` to find its
  configuration.
- **Secrets handled:** No secrets handled.
- **Privilege escalation:** No privilege escalation.

## Assumptions for operation

- `bash` 3.2 or later with `/dev/fd` (process substitution without a named pipe); `find`
  with `-print0`; `sort` with `-z`; `grep` with `-a` and `-o`; `sed`,
  `mkdir`, `dirname`, `date`. `git` is optional: without it the commit is `unknown`.
- The script is run from a checkout or a copy of greenfield that holds `VERSION` and,
  unless `--template` is given, `template/`.
- POSIX filesystem semantics.
- The caller is responsible for the target not being changed by another process during
  the run. The no-clobber setting stops a file from being overwritten in that case; it
  does not protect against a parent directory, or the `.gitignore` being appended to,
  being replaced by a link after the plan is made.
- A run that fails after its first write (exit 2) leaves the target partly placed, with
  no stamp. The files completed are listed on stdout; the file being written when the
  run failed is named on stderr and may be left empty; directories that were created
  are not listed. To recover, remove the listed files, the file named on stderr, and
  the marked block from `.gitignore` if it was appended, and run again; or, for a new
  directory, remove the directory.
- `--name` is checked against ASCII only. `--owner` is checked for ASCII control
  characters and the listed characters only: any other bytes, including invisible
  Unicode characters, are written as given. Both limits are counted in bytes.
- A token is `@@`, then letters, digits, and underscores, then `@@`. The five the script
  replaces are the only ones a template may hold.
- The script does not run `git init`, does not commit, and does not install the linters.
  Afterwards, whoever runs the script runs `git init` if the target is not a Git
  repository yet, and commits the placed files, with a change log entry that records
  them when the repository already had commits; the operator runs
  `make install-linters` (an agent hands it over).

## Anti-patterns this script must not do

- Do **not** overwrite or replace an existing file, under any flag. The one modification
  of an existing file is the append to `.gitignore`.
- Do **not** write through a symbolic link, or under a directory that is one. A link in
  the target could aim a write outside it.
- Do **not** pass an unvalidated value to `sed`, and do not `eval` anything.
- Do **not** run any command in the target, and do not execute anything from the
  template: the template holds a Makefile and scripts, and they are data here.
- Do **not** leave a half-placed repository because of a conflict: conflicts are found
  before the first write.

## Revision rules

- Removing a behavior, an input, an output, or an assumption requires a deliberate
  version bump.
- Added assumptions never relax previous assumptions.
- Added capabilities require operator review.
- A version is ratified only after review; one change is one bump.
- The script's file header references the contract version it was built against.

## Change log

- **v4** — 2026-11-18: the next steps the script prints name four gates,
  `make change-log docs-lint llm-size-guard reviews-lint`. `tools-test` is gone from
  the list: the template no longer places the tests or the contracts of its tools,
  which are kept in this repository under `tools/`, and the placed Makefile has no
  such target. The load-bearing note on the placed files names the same four gates;
  the test of the next steps asserts the new line, and the test of the placed files
  names scripts of the tools in place of a contract and two test files. No behavior,
  input, capability, or file written by the script changed: what is placed is whatever
  `template/` holds. The script's header comment was rewrapped, and the test's header
  reworded.
  Review: 2026-11-18, the reviewer of v3, resumed (a subagent that did not write the
  change), SAFE TO RUN; 1 flag, LOW, resolved: the entry did not name the two header
  edits (named above). The reviewer ran `make test` and `make template-check`, and had
  no Git history to compare against.
- **v3** — 2026-11-18: the next steps the script prints name five gates,
  `make change-log docs-lint llm-size-guard reviews-lint tools-test`: the template
  places the `change-log` gate, and the printed list left it out. They scope "commit
  the placed files unchanged" to a repository with no commit yet, and say that in a
  repository that already had commits `change-log` reports CL04 until an entry records
  the placed files, and that outside CI that gate may merge the upstream branch. The
  load-bearing note on the placed files names the same five gates, and the test of the
  next steps asserts the new lines. No behavior, input, capability, or file written
  changed.
  Review: 2026-11-18, a fresh subagent that did not write the change, two rounds, SAFE
  TO RUN; 6 flags, all LOW. Resolved, and confirmed by the same reviewer: the next
  steps were silent on the CL04 failure in a repository with commits, and on the gate
  merging the upstream (message, test, and contract changed); the entry did not name
  the test change. Resolved after the second round: the test did not pin the clause
  about the merge (the assertion now holds the whole line). Accepted: the list of gates
  is written by hand in six places and no test compares them, because
  `make template-check` runs the five on a fresh stamp and the test file is at its size
  limit; the test header's coverage list omits behavior 9, as it did in v2. The
  reviewer had no Git history to compare against: nothing was committed.
- **v2** — 2026-11-18: the next steps the script prints say who runs each command, name
  the three linter commands, and tell the reader to commit the placed files unchanged
  if they are not committed yet, in place of printing `git add -A && git commit`. The
  usage text names the commit among what is replaced. The assumption about what the
  script leaves undone says the same as the next steps: whoever runs the script runs
  `git init` if the target is not a repository yet and commits the placed files, and
  the operator runs `make install-linters`. The recovery sentence names what to
  remove. No behavior, input, capability, or file written changed.
  Review: 2026-11-18, the second reviewer of v1, resumed (a subagent that did not
  write the change), SAFE TO RUN; 5 flags, all LOW, all resolved and confirmed by the
  same reviewer: no test read the next steps (three checks added); the commit line
  was wrong for an existing target; `glossarian` is not a command name; the usage
  text left out the commit; an unclear "them" in the recovery sentence.
- **v1** — 2026-11-18: initial version. Note: the script was drafted before this file was
  written down, from a design held in the authoring session; the contract was then
  written from the request and the script checked against it.
  Review: 2026-11-18, fresh subagent, SAFE WITH CONDITIONS; 11 flags, all resolved
  before the next round: the target was not anchored as a path (`--target -`, a leading
  hyphen, `CDPATH`); here-documents made bash before 5.1 write temporary files; the
  stamp could be written after an incomplete loop; `git status` could rewrite the
  index; four test gaps (no-clobber after planning, the other refusals, a dry run on
  an existing target, the version and commit); three wording gaps in this contract.
  Review: 2026-11-18, a second fresh subagent, three passes, SAFE WITH CONDITIONS then
  SAFE TO RUN; 16 flags, none CRITICAL or HIGH. MEDIUM, all resolved: a template path
  with a newline or tab could forge a plan line and write beside the target (refused in
  behavior 2, tested); a failed `find` left the copy incomplete with a stamp (now exit
  2, tested); no test held the claim that Git does not refresh the index (added). LOW,
  resolved: binary files and tokens; ancestors of the target; a newline in `--target`;
  an unreadable `VERSION`; stderr and refusal wording; undeclared refusals; a stamp in
  the template; the here-document test; byte counting under a UTF-8 caller; the locale
  of the target check; recovery wording; an inherited `GIT_DIR`; a command draining the
  plan from standard input (the write loop now reads it on descriptor 3). LOW,
  accepted: the `handled`/`planned` guard before the stamp is a defensive check that no
  test reaches; the two loops that check and plan the template read their file lists
  on standard input while running `grep`, which reads only the file it is given.
