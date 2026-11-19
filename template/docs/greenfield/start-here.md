---
id: greenfield-start-here
title: Start here
is_source_of_truth: true
derives_from: [greenfield-specification]
status: policy
---

# Start here

For the agent, or person, beginning work in this repository. It says what the repository
holds now and what to do first. The standing policy is
[specification.md](specification.md).

## 1. What this repository is now

A default repository placed by greenfield. Nothing is designed and nothing is built. The
documents are templates, the backlog holds the first steps, and the language gates fail on
purpose until a toolchain exists. `.greenfield-stamp` records the greenfield version and
commit the repository was placed from, the project name, the owner, and the date.

The owner is the person named in `.greenfield-stamp`. Questions about what the project is
for, and what risk is acceptable, go to the owner. Do not invent the answers.

The [operator](../glossary.md#operator) runs what an agent may not, and an agent hands each
such command over. [specification.md §6.1](specification.md#61-targets) says which
commands those are.

## 2. What has been placed

| Path | What it is | State |
|---|---|---|
| `AGENTS.md` | Instructions for every agent. | Ready; the project edits it as it learns. |
| `CLAUDE.md` | A pointer to `AGENTS.md`. | Ready. |
| `.agent_notes/` | The agent memory store: `index.md` holds its rules and lists the notes. | Ready, with one note, `prose.md`: the rules for prose. |
| `README.md` | The project's front page. | Stub. |
| `Makefile` | The quality gates. | The documentation, review, and change log gates work. `format`, `format-check`, `lint`, and `test` fail until step 1. |
| `.gitignore` | macOS, editor, secret, agent, and gate rules. | Ready; step 1 adds language rules. |
| `.llm-file-size-guard.toml` | The size policy. | Ready. |
| `.greenfield-stamp` | What this repository was placed from. | Ready. Greenfield-owned. |
| `.github/workflows/ci.yml` | Installs the two documentation tools and runs `make commit`. | Fails until step 1, by design. |
| `docs/design.md` | The central design and the document map. | Stub, except the document map and the gates. |
| `docs/threat-model.md` | The threat model. | Stub. |
| `docs/sandbox-testing.md` | How agents test end to end in a sandbox. | Stub. |
| `docs/glossary.md` | The glossary, holding the terms this policy uses. | Ready; the project adds its own terms. |
| `docs/decisions.md`, `docs/decisions/` | The decision index and one decision, D1. | Ready. |
| `docs/change_log.md` | The list of change log entries. | Ready, with no entries. Generated; never edited by hand. |
| `docs/change_log/` | One file for each change log entry, and `tags.md`, where the project declares its own tags. | Ready, with no entries and no project tags. |
| `docs/open-questions.md` | Open questions, with OQ-1. | Ready. |
| `docs/out-of-scope.md`, `docs/deferred-work.md` | Their forms. | Stub. |
| `docs/greenfield/` | This policy: the specification, this guide, the review procedure, the rubric, the change log rules. | Ready. Greenfield-owned. |
| `backlog/` | The form of a backlog item, and items B001 to B006. | Ready. |
| `reviews/` | What the files are, and the blank review record and disposition forms. | Ready, with no reviews. The two `TEMPLATE-*.md` forms are greenfield-owned. |
| `tools/review_lint*` | The review linter: the script and its two awk programs. | Ready. Greenfield-owned. |
| `tools/change_log*` | The change log script, the files it reads, and its two awk programs. | Ready. Greenfield-owned. |

## 3. Before anything else

1. Read `AGENTS.md`, then `.agent_notes/index.md` and the notes it lists.
2. The gates need a Git repository. If this directory is not one yet, run `git init`.
3. The gates need `glossarian-check`, `glossarian-gather`, and `llm-size-guard` on `PATH`.
   If one is missing, the operator runs `make install-linters` (an agent hands it over).
4. Run `make change-log docs-lint llm-size-guard reviews-lint`. All four pass
   on an untouched repository. If one fails, stop and report it; do not work around it.
   One failure is expected: in a repository that already had commits, `change-log`
   reports CL04 until an entry records the placed files, and outside CI it can merge
   the upstream branch ([change-log.md](change-log.md) §4 and §6).
5. In a repository with no commit yet, commit the placed files unchanged: the first
   commit is the default repository as greenfield placed it, and it needs no change log
   entry. In a repository that already had commits, commit them with that entry.
6. Run `make stubs`. It fails and lists what is not yet written. That list is the design
   work.
7. `make commit` fails at `format-check`. That is expected until step 1 (§4) is done.

Then take the steps in order. Each is one or more backlog items; each item is one change,
committed on its own branch. The operator pushes the branch, and opens and merges its pull
request (an agent hands these over).

Every change after the first commit is recorded in the change log
([change-log.md](change-log.md)). Before `make commit`, run
`make change-log-entry TITLE="..." TAGS="..."` with one to four of the tags that document
lists, and fill in the two sections of the entry it creates. Run `make commit`, and
commit the change, the entry, and `docs/change_log.md` when it passes.
`make commit` starts with the `change-log` gate, which regenerates
`docs/change_log.md` and checks that the change is recorded and that the upstream branch
is merged. It merges the upstream itself only into a working tree with no uncommitted
change, and only where the merge is trivial: when it reports that the upstream is not
merged, commit the work, run `make commit` again, and when it passes complete the merge
it made with `git commit --no-edit`. The gate judges what the clone
holds and contacts no remote: the operator runs `git fetch`
(an agent hands it over) to bring the clone up to date.

## 4. Step 1: language toolchain

Backlog item [B001](../../backlog/B001-language-toolchain.md). This is pull request 1.

The owner states the language or languages. If the owner has not, ask; this is OQ-1 in
`docs/open-questions.md`. Then, in one change:

- record the choice as a decision, with the alternatives rejected;
- pin the runtime and every tool, with a lockfile where the ecosystem has one;
- wire `format`, `format-check`, `lint`, and `test` in the `Makefile` to real commands, and
  keep each failing when it finds nothing to check;
- add one real test, so that `make test` runs something;
- add a test that the decision index and the decision files agree, by the rules
  `docs/decisions.md` states;
- add the language's rules to `.gitignore`;
- confirm `.llm-file-size-guard.toml` scans the language's source files;
- make CI pass on `make commit`, and say so only after seeing a run pass.

No product code is written in this step. It is done when `make commit` passes locally and
in CI. CI runs on a pull request and on a push to `main`, so it has run only after the
operator pushes the branch and opens the pull request (an agent hands these over).

## 5. Step 2: design

Backlog items B002 to B006. The design is written in increments, and each increment is
committed and reviewed before the next builds on it.

### 5.1 The goal

[B002](../../backlog/B002-design-goal-and-mvp.md). In `docs/design.md`: what the project is
for, who uses it, and where its boundary is. One paragraph a newcomer can repeat.

### 5.2 The MVP for version 1

Also B002. The smallest delivery that meets the goal: what is in it, and the end-to-end
scenarios that show it works. What is left out goes to `docs/out-of-scope.md` or
`docs/deferred-work.md`, never to silence.

### 5.3 The threat model

[B003](../../backlog/B003-design-threat-model.md). In `docs/threat-model.md`: what is
protected, who is trusted with what, the trust boundaries, each threat and the design's
response, and what is not defended. An agent with write access that is wrong, or
compromised, is one of the actors.

### 5.4 End-to-end testing in the sandbox

[B004](../../backlog/B004-design-sandbox-testing.md). In `docs/sandbox-testing.md`: how an
agent, inside its [sandbox](../glossary.md#sandbox), runs every MVP scenario from end to
end. For each thing the sandbox cannot reach: what stands in for it, and how the stand-in
is kept true to the real thing. For each kind of data the scenarios need: the synthetic
data, how it is generated, and that it contains nothing real. And what a sandbox run does
not prove, with who covers that instead.

Design this before the components. A design that cannot be tested end to end in the
sandbox is changed until it can be.

### 5.5 The system

[B005](../../backlog/B005-design-system.md). The rest of `docs/design.md`: system context,
components and their owners, interfaces and data, failure handling, and invariants. Split
a section into its own document when it outgrows the size budget, and add it to the
document map.

### 5.6 Adversarial review, throughout

Each increment above is reviewed when it is committed, not at the end. The procedure is
[adversarial-review.md](adversarial-review.md) and the rubric is
[review-rubric.md](review-rubric.md). In short:

- Every review is of **one commit hash**. Commit first, then request the review with the
  full hash.
- The reviewer is a session that wrote none of the work.
- Every finding is recorded. There is no severity.
- Every finding gets a disposition from two questions: would it block the MVP, and would
  it be expensive to fix once implementation has begun?
  - Either yes: fix it now, in design.
  - Both no: file it in the backlog and leave it. Much will change during implementation,
    and a cheap fix made now may not apply then.
- Each fix is committed and **submitted for review again**, until the reviewer reports the
  finding resolved.

### 5.7 The whole design, and the exit gate

[B006](../../backlog/B006-design-review-and-exit.md). When the increments are done, the
whole design is reviewed at one commit with both passes. Implementation MUST NOT begin
until all of these are true:

- `make stubs` passes: no stub marker remains.
- `make commit` passes.
- A whole-design review exists, and every finding in every review has a disposition.
- Every `fix-now` finding is `verified`.
- Every `later` finding has its backlog file.
- No open question blocks the MVP, except one that needs evidence a named backlog item
  will produce, with the work that depends on it ordered after that item.
- The backlog holds the items that build the MVP, each in the form
  `backlog/README.md` gives.
- The owner has read the design and agreed to it. Record this as a decision.

Any "no" is design work, not a deferred feature.

## 6. After the exit gate

Implementation proceeds from the backlog, one item per change. Reviews continue at the
cadence the project chose ([adversarial-review.md §2](adversarial-review.md#2-when-a-review-is-required)).
Remove the pointer to this guide from `AGENTS.md`; the specification stays in force.
