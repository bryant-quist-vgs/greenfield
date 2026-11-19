# AGENTS.md — @@PROJECT_NAME@@

Instructions for every agent that works in this repository, whatever its vendor. This is
the only file that holds them: `CLAUDE.md` and any other vendor's entry file point here.
Keep it short. It points to documents; it does not restate them.

## Read first

1. [.agent_notes/index.md](.agent_notes/index.md): what earlier sessions learned. Read the
   index, then the notes that bear on your task.
2. [docs/greenfield/start-here.md](docs/greenfield/start-here.md): the repository is new
   and this guide says what to do first. (Remove this line when the design exit gate is
   passed.)
3. [docs/design.md](docs/design.md): what the project is. Its document map (§12) names the
   home of everything else.

## Where things are

| For | Go to |
|---|---|
| What to work on | `backlog/`: one file for each piece of work not done. |
| Why something is the way it is | `docs/decisions.md` and `docs/decisions/`. |
| What each session changed, and why | `docs/change_log.md` (generated) and `docs/change_log/`. |
| The project's own change log tags | `docs/change_log/tags.md`. |
| What is not yet known | `docs/open-questions.md`. |
| What a word means | `docs/glossary.md`. |
| The rules of this repository | `docs/greenfield/specification.md`. |
| How work is reviewed | `docs/greenfield/adversarial-review.md` and `docs/greenfield/review-rubric.md`. |

## Rules

- **Gates.** `make commit` is the gate for every change; `make help` lists the others. The
  evidence that a gate passed is its output. Never weaken, skip, or delete a test or a
  gate to make it pass.
- **Who runs what.**
  [docs/greenfield/specification.md §6.1](docs/greenfield/specification.md#61-targets)
  states which commands an agent may run and which the
  [operator](docs/glossary.md#operator) runs. Hand an operator-run command over; do not
  run it.
- **Prose.** Every page follows [.agent_notes/prose.md](.agent_notes/prose.md): what is true
  and what to do, who runs each command, no history outside the records.
- **One fact, one home.** Link to the home; do not restate it. Update documents in the
  change that alters what they describe.
- **Do not guess.** What the project is for, and what risk is acceptable, are the owner's
  to say. Record an unknown as an open question and ask.
- **Decisions are recorded** when they are made: one file under `docs/decisions/`, by the
  rules in `docs/decisions.md`.
- **Changes are recorded.** Run `make change-log-entry TITLE="..." TAGS="..."` and fill in
  the entry it creates; run `make commit`; when it passes, commit the change with the
  entry and `docs/change_log.md`. Never edit `docs/change_log.md`: it is generated. When
  `make commit` reports that the upstream branch is not merged, commit the work and run
  it again: it merges the upstream into a clean working tree where the merge is trivial,
  and `git commit --no-edit` completes that merge.
  [docs/greenfield/change-log.md](docs/greenfield/change-log.md) has the rules and the
  tags.
- **Backlog.** Work from a backlog item. Delete its file in the change that completes it.
- **Reviews are of a commit.** Commit, then request an adversarial review with the full
  hash. Never review your own work. Never edit a review record.
- **Greenfield-owned files are not edited:** `docs/greenfield/`, `tools/review_lint*`,
  `tools/change_log*`, `reviews/TEMPLATE-*.md`, `.greenfield-stamp`.
- **Stay in scope.** Do what the item asks. Leave unrelated refactoring and reformatting
  out. Add no dependency without a stated need.
- **Sandbox.** Run unreviewed code only inside the sandbox. If a task cannot be finished
  within it, say what is missing; do not work around it.
- **Secrets** are never written to the repository, a note, a review, or a log.
- **Command output.** Send long output to a file under `local/` (ignored by Git) and read
  the part you need.

## Notes

When you learn something the next session would have to rediscover, and no document under
`docs/` is its home, write a note under `.agent_notes/` by the rules in its index. Do this
before you finish, not later.
