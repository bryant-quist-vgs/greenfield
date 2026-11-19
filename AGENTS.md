# AGENTS.md — greenfield

Instructions for every agent that works in this repository, whatever its vendor.
`CLAUDE.md` points here. This repository is maintained by an agent on the owner's behalf:
read the notes before changing anything.

## Read first

1. [.agent_notes/index.md](.agent_notes/index.md): what earlier sessions learned and
   decided, and why.
2. [README.md](README.md): what greenfield is and how it is laid out.
3. [template/docs/greenfield/specification.md](template/docs/greenfield/specification.md):
   the policy this repository exists to maintain.

## What this repository is

`template/` is the default repository placed into every new project by
`greenfield_init.sh`. A change there changes every repository created afterwards, and the
agents in those repositories cannot ask what was meant. Write for a reader who has only
the placed files.

## Rules

- **Gates.** Run `make commit` before calling any change done; it runs the gates and
  creates no Git commit. The evidence is its output. Never weaken, skip, or delete a test
  or a gate to make it pass.
- **Who runs what, in this repository.** An agent may run every `make` target except
  `install-linters`, and may run `greenfield_init.sh`. The operator runs
  `make install-linters`, and commits, pushes, and releases (an agent hands these over).
  A placed repository has its own rule, in `template/docs/greenfield/specification.md`
  §6.1.
- **Prose.** Every page here and under `template/` follows
  [.agent_notes/prose.md](.agent_notes/prose.md): what is true and what to do, who runs
  each command, no history outside the records.
- **One home.** Everything a new repository receives lives under `template/` and nowhere
  else. The five documents under `template/docs/greenfield/` are the specification; do
  not restate them in `README.md` or here.
- **Template files stay under the size warning level.** A new repository cannot edit a
  greenfield-owned file, so a warning there is permanent.
- **The template stays language agnostic.** Shell and awk only, for bash 3.2 and any POSIX
  awk. A placed repository needs `bash`, `awk`, `git`, `make`, and the standard POSIX
  utilities, plus `glossarian` and `llm-size-guard`, which `make install-linters` installs
  with `uv`. Require no other tool.
- **The placed tools are managed here.** `template/tools/` holds only what a placed
  repository runs. The contract and the tests of each placed tool are in `tools/`, and
  `make test` runs them. A placed repository receives no contract and no test, and runs
  none.
- **The review form and its linter move together.** A change to the record or disposition
  form changes `adversarial-review.md`, both `reviews/TEMPLATE-*.md` files,
  `template/tools/review_lint*`, and its tests in one change. The tests include one that
  fills in the blank forms and lints them.
- **The change log rules and their script move together.** A change to the entry form, the
  tags, or a rule CL01 to CL06 changes `change-log.md`, `template/tools/change_log*`, and
  its tests in one change. The tests compare the script's baseline tags with the table in
  `change-log.md` §2.
- **Scripts are trios.** `greenfield_init.sh`, `template/tools/review_lint.sh`, and
  `template/tools/change_log.sh` each have a contract and tests: beside the script for
  the first, in `tools/` for the other two. Change the contract first. A contract
  version is ratified only after a review by a session that did not write the change.
- **The rubric has no severity,** and nothing may add one: no grade, rank, or cut in the
  rubric, the record form, or the linter. The owner requires this, because agents grade
  severity badly.
- **Version.** Bump `VERSION` in any change that alters what `template/` places.
- **Backlog.** Work on greenfield itself is in [backlog/](backlog/), one file for each
  item, deleted in the change that completes it.
- **Do not guess what the owner wants.** Ask, and write the answer down as a note.
- **Command output.** Send long output to a file under `local/` (ignored by Git) and read
  the part you need.

## Notes

When you learn something the next session would have to rediscover, write a note under
`.agent_notes/` by the rules in its index, before you finish.
