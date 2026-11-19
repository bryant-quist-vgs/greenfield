# greenfield

The default starting state for a new repository, and the specification that goes with it.

`greenfield_init.sh` places the contents of [template/](template/) into a new project's
directory: templated design documents, a decision log with one file for each decision, a
change log generated from one file for each change, with a script that records a
session's changes and merges the upstream branch where the merge is trivial, a
Glossarian glossary, a backlog holding the first steps, `AGENTS.md` with a `CLAUDE.md`
pointer and a vendor-neutral agent memory store, quality gates for
[glossarian](https://github.com/bryant-quist-vgs/glossarian) and
[llm-size-guard](https://github.com/bryant-quist-vgs/llm_file_size_guard), macOS-focused
ignore rules, and a strict, machine-checked form for adversarial reviews. The default is
language agnostic; choosing a language is the new repository's first pull request.

## Start a new repository

Run the script:

```bash
bash greenfield_init.sh --target ~/src/new-project --name "New Project" --owner "Your Name"
```

In the new directory, if it is not a Git repository yet, run:

```bash
git init
```

If `glossarian-check`, `glossarian-gather`, or `llm-size-guard` is not on `PATH`, the
operator runs this command (an agent hands it over):

```bash
make install-linters
```

Then run the gates that pass on an untouched repository:

```bash
make change-log docs-lint llm-size-guard reviews-lint
```

In a repository with no commit yet, commit the placed files unchanged: the first commit
of a new repository is the default repository as greenfield placed it. In a repository
that already had commits, `change-log` reports CL04 until a change log entry records the
placed files, and outside CI it can merge the upstream branch
(`template/docs/greenfield/change-log.md` §4 and §6); commit the entry with the files.
The agent that works in the new repository starts at `docs/greenfield/start-here.md`.

`--dry-run` prints what would be written and writes nothing. An existing `.gitignore` is
appended to, never replaced; any other existing file stops the run unless
`--keep-existing` is given. The script never overwrites a file. Its full behavior is in
[greenfield_init_contract.md](greenfield_init_contract.md).

## What a new repository is given

| Document | For |
|---|---|
| [start-here.md](template/docs/greenfield/start-here.md) | The agent starting work: what has been placed, and the first steps. |
| [specification.md](template/docs/greenfield/specification.md) | The standing policy: repository shape, documents, backlog, gates, reviews. |
| [adversarial-review.md](template/docs/greenfield/adversarial-review.md) | How a review is requested, recorded, and acted on. Every review is of one commit hash. |
| [review-rubric.md](template/docs/greenfield/review-rubric.md) | What a reviewer looks for: eight per-item axes and six cross-item axes, with no severity. |
| [change-log.md](template/docs/greenfield/change-log.md) | The change log: the form of an entry, the tags, the `change-log` gate, and what it merges. |

The first steps a new repository takes:

1. **Language toolchain** (pull request 1).
2. **Design**, in increments, each reviewed at a commit before the next builds on it: the
   goal; the MVP for version 1; the threat model; how agents test end to end in the
   sandbox, with what is stubbed and what synthetic data is built; then the system. Every
   finding is tracked. A finding is fixed during design only if it would block the MVP or
   be expensive to fix later; the rest are filed in the backlog. Every fix is reviewed
   again.

## Layout

```text
greenfield_init.sh             places the template; with its contract and tests
VERSION                        the version stamped into new repositories
template/                      the default repository, exactly as placed
  docs/greenfield/             the specification, start guide, review procedure, rubric
  docs/                        design, glossary, decisions, threat model, sandbox testing, ...
  docs/change_log.md           the generated list of change log entries, with no entry
  docs/change_log/tags.md      where a project declares its own change log tags
  backlog/                     the form of a backlog item, and the first six items
  reviews/                     the blank review record and disposition forms
  tools/review_lint*           the review linter, as a placed repository runs it
  tools/change_log*            the change log script, as a placed repository runs it
tools/                         the contract and the tests of each placed tool
backlog/                       work on greenfield itself
.agent_notes/                  what the maintaining agent has learned
```

`template/` is the single home of every file a new repository receives, apart from
`.greenfield-stamp`, which `greenfield_init.sh` writes. Nothing in it is copied elsewhere
in this repository.

## Working on greenfield

```bash
make commit
```

runs every gate and creates no Git commit: `lint` (shell syntax, shellcheck, and the
linter pins of `template/Makefile`), `test` (the scripts' tests), `template-check`
(places the template in a temporary repository and runs its gates there), and
`llm-size-guard`. The gates need `shellcheck`, `glossarian-check`, `glossarian-gather`,
and `llm-size-guard` on `PATH`; the operator runs `make install-linters` (an agent hands
it over) to install them at pinned versions. Agents start at [AGENTS.md](AGENTS.md).

A change to the template is a change to every repository created afterwards. Repositories
already created keep the version named in their `.greenfield-stamp`; bump `VERSION` when
the template changes.
