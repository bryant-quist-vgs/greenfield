---
id: greenfield-specification
title: Greenfield project specification
is_source_of_truth: true
derives_from: []
status: policy
authority: >
  The minimum policy for this repository: its shape, its documents, its backlog, its
  quality gates, and its reviews. Project documents may add stricter rules. They do not
  weaken this minimum without a decision record that says so.
lineage: >
  Placed by greenfield at the version named in .greenfield-stamp. Maintained in the
  greenfield repository; this copy does not change when that one does.
---

# Greenfield project specification

## 1. Purpose and normative language

This policy defines the minimum shape of a new project, so that intent, decisions, work,
quality gates, and unfinished work can be inspected by people and by agents of any vendor.

**MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative. A project
conforms when every MUST is met, or when a departure is recorded as a decision with its
owner, its reason, and the condition that ends it.

What a new repository does first is in [start-here.md](start-here.md). This document is the
policy that remains in force afterwards.

## 2. Repository shape

```text
.
├── AGENTS.md                    instructions for every agent
├── CLAUDE.md                    points to AGENTS.md
├── .agent_notes/                agent memory, shared by all vendors
│   ├── index.md                 the rules for notes, and the list of them
│   └── prose.md                 the rules for prose
├── README.md
├── Makefile                     the quality gates
├── .gitignore
├── .llm-file-size-guard.toml    size policy
├── .greenfield-stamp            what this repository was started from
├── .github/workflows/ci.yml     runs `make commit`
├── docs/
│   ├── design.md                central design, with the document map
│   ├── glossary.md              Glossarian glossary
│   ├── decisions.md             index of decisions
│   ├── decisions/               one file for each decision
│   ├── change_log.md            list of change log entries; generated
│   ├── change_log/              one file for each entry, and the project's tags
│   ├── open-questions.md
│   ├── out-of-scope.md
│   ├── deferred-work.md
│   ├── threat-model.md
│   ├── sandbox-testing.md
│   └── greenfield/              this policy; not edited in the project
├── backlog/                     one file for each piece of work not yet done
├── reviews/                     adversarial review records and dispositions
└── tools/                       the review linter and the change log script
```

A project MAY rename a document. The document map in `docs/design.md` MUST then name the
file that fills each role. The change log is the exception: `tools/change_log.sh` reads
and writes `docs/change_log.md` and `docs/change_log/` under those names (§10).

These paths are **greenfield-owned**: `docs/greenfield/`, every `tools/review_lint*` file
(the linter and its two awk programs), every `tools/change_log*` file (the change log
script, the files it reads, and its two awk programs),
`reviews/TEMPLATE-record.md`, `reviews/TEMPLATE-disposition.md`, and `.greenfield-stamp`.
A project MUST NOT edit them. A rule that does not suit the project is departed from by a
decision, not by changing the copy, so that the placed copy can be compared with another
version of greenfield.

## 3. Documents

### 3.1 Authority and metadata

Every authoritative Markdown document MUST begin with YAML front matter declaring at
least:

```yaml
---
id: stable-document-id
is_source_of_truth: true
derives_from: []
status: draft | current | policy | superseded | archived
---
```

A derived document names the IDs it derives from. A superseded document says so and points
to its replacement. Historical, generated, and exploratory documents say what they are and
do not present themselves as current authority. `AGENTS.md`, `CLAUDE.md`, and `README.md`
are exempt, because tools read them from their first line.

**One fact has one home.** Other documents link to that home and do not restate a value
that can drift. Where a reader needs a binding value (a default, an enumeration, an exact
signature, an edge case), the document quotes it and cites its home.

### 3.2 Central design

`docs/design.md` describes what the project is and how its parts fit, as it stands. It
MUST:

- state the goal, the users, and the boundary of the project;
- define the [MVP](../glossary.md#mvp) for version 1 and the end-to-end scenarios that
  show it works;
- name the components and the one owner of every shared interface, schema, constant set,
  and vocabulary;
- state the trust boundaries and invariants, and point to the threat model;
- say how the project is tested, and point to the sandbox testing plan;
- keep what is built apart from what is planned; and
- hold the document map: the file that fills each role, and when to update it.

It MUST be understandable without any file that Git ignores.

### 3.3 Glossary

There is one glossary, `docs/glossary.md`. It MUST pass `glossarian-check`, and every link
into it MUST pass `glossarian-gather`; `make docs-lint` runs both. A load-bearing term is
defined there once and linked from other documents, which do not redefine it. A rename
keeps the old term in the renames table and is followed by a search of the whole
repository.

### 3.4 Decisions

Decisions are kept as one file for each decision under `docs/decisions/`, with
`docs/decisions.md` as the index. They are not gathered into one file: a single decision
log grows past the size limit (§6.3).

Each decision records its status, date, context, the decision, the rationale, the
alternatives rejected, the consequences, and the decisions it supersedes or amends. The
index states the rules, the tag vocabulary, and the tables. Entries are never deleted. The
index and the files MUST agree. That is checked by hand until the toolchain change adds a
test that checks it ([start-here.md step 1](start-here.md#4-step-1-language-toolchain)).

An open question is never written as a decision.

### 3.5 Open questions

`docs/open-questions.md` holds what the design does not yet answer. Each question records
an ID, the question, whether it blocks the MVP, what is needed to close it, what it depends
on, and the document that will receive the answer. The design MUST NOT guess around an open
question. A resolved question is marked resolved and its answer moves to that document.

### 3.6 Out of scope and deferred work

These are different and have different documents.

- **Out of scope** is what the project deliberately does not do. Each entry says why, and
  what change of boundary would cause it to be reconsidered.
- **Deferred work** belongs to the project and is not in the current delivery. Each entry
  names its horizon, the reason, and what it depends on.

Deferral MUST NOT be used to hide unfinished MVP work. That work is in the backlog.

### 3.7 Threat model and sandbox testing

`docs/threat-model.md` states what is protected, who is trusted with what, where the trust
boundaries are, which threats the design answers and how, and which it does not answer.
Agents with write access are among its actors.

`docs/sandbox-testing.md` states how an agent verifies the project end to end from inside a
[sandbox](../glossary.md#sandbox): what is stubbed and why, what synthetic data exists and
how it is made, how to run it, and what a sandbox run does not prove.

### 3.8 Planned behavior

A description of something not yet built MUST be marked planned, proposed, or deferred, and
MUST name what will build it, what will use it, what it depends on, and the behavior today.
Planned behavior is never written in the present tense.

### 3.9 Maintenance

A change that alters documented behavior updates the documents in the same change. Links
MUST resolve to real content, not to a placeholder. Every change is recorded by an entry
in the change log (§10).

A section that has not been written carries a [stub marker](../glossary.md#stub-marker): a
line beginning `> **GREENFIELD-STUB**` that says what belongs there. `make stubs` lists
them. A marker is removed only by writing the content.

## 4. Backlog

`backlog/` holds one file for each piece of work that belongs to the current delivery and
is not done. [backlog/README.md](../../backlog/README.md) gives the form. A
[backlog item](../glossary.md#backlog-item) names one bounded deliverable, what it depends
on, what it implements or updates, the tests it requires, and the evidence expected when
it is done. It is sized so that one session can finish and verify it without memory of
another session.

An item's file is deleted in the change that completes it, so the directory lists exactly
what remains. A review [finding](../glossary.md#finding) left for later is a backlog item
named by its finding ID.

## 5. Agent files

- `AGENTS.md` is the one place for instructions to agents. It is short. It points to the
  documents; it does not restate them.
- `CLAUDE.md` contains only a pointer to `AGENTS.md`. Any other vendor's entry file is
  handled the same way.
- `.agent_notes/` is the agent memory store. `index.md` lists every note in one line; each
  note is one file. Notes are tracked in Git, so that every agent and every worktree sees
  them. A note holds what an agent would otherwise have to rediscover and what no document
  under `docs/` is the home for. A note never overrides a document. A secret is never
  written in a note.

## 6. Quality gates

### 6.1 Targets

The `Makefile` MUST provide:

| Target | Does |
|---|---|
| `format` | Applies the formatter. |
| `format-check` | Verifies formatting and changes nothing. |
| `lint` | Runs the static checks on source and tests. |
| `test` | Runs the deterministic test suite. |
| `docs-lint` | Checks `docs/glossary.md`, and every glossary link in every Markdown file of the repository. |
| `llm-size-guard` | Fails when a file is too large for an agent to maintain. |
| `reviews-lint` | Checks every review record and disposition file. |
| `change-log` | Regenerates `docs/change_log.md`, checks the change log, and merges the upstream into a clean working tree where the merge is trivial ([change-log.md §5](change-log.md)). Under CI it checks and changes nothing. |
| `commit` | Runs `change-log` first, then every other gate above except `format`. It does not create a Git commit. |
| `change-log-entry` | Creates a change log entry from `TITLE` and `TAGS` ([change-log.md §4](change-log.md)). Not part of `commit`. |
| `stubs` | Lists the stub markers that remain, and fails if there are any. Not part of `commit`. |

A gate that has nothing configured MUST fail and say so. It MUST NOT pass without checking
anything.

The placed `Makefile` also provides `help`, which lists the targets and is what `make`
alone runs, and `install-linters`, which installs `glossarian` and `llm-size-guard` at the
commits the `Makefile` pins.

**Who runs what.** An agent may run every `make` target except `install-linters`, and may
run Git commands that stay on the machine, such as `git init`, a commit, a merge of a
commit the clone already holds, or a tag. The [operator](../glossary.md#operator) runs
`make install-linters` (an agent hands it over): it downloads both tools and replaces any
copy of them already installed. The operator also runs anything that needs credentials or
leaves the machine: a fetch, a push, opening or merging a pull request, a release, a
change to repository settings. An agent prepares each of these and hands it over.

### 6.2 Formatting and linting

Each language uses a deterministic formatter whose version is pinned. Guidance about style
written in prose is not a gate. Generated code is either regenerated and checked, or
excluded with a stated reason.

### 6.3 Size

`.llm-file-size-guard.toml` states the limits. A file that reaches the warning level is
split by responsibility before it reaches the error level. The guard's `accept` is used
only for a file that will not change again, such as a review record. Accepted and deferred
files are recorded in the tracked state file, `.llm-size-guard-state.json`, so that a
suppression is reviewed like any other change.

### 6.4 Commit gate and CI

CI installs the two tools with `make install-linters` and then runs `make commit`. It does
not repeat the commands of either target. Under CI the `change-log` gate checks and
changes nothing ([change-log.md §5](change-log.md)). A change to a CI gate changes the `Makefile` in
the same change. A gate that can run only in CI is documented beside the target with its
reason. The evidence that a gate passed is its exit status and its output, never a
statement that it was run.

## 7. Ignore rules

`.gitignore` is written for the project's languages, tools, and operating systems. It
ignores local secrets, virtual environments, caches, build and test output, and editor and
operating-system files. Its directory rules are anchored. It MUST NOT hide source,
documents, backlog items, review records, agent notes, or lockfiles. Ignoring a secret file
is not a security control.

## 8. Adversarial review

Work is reviewed by a [reviewer](../glossary.md#reviewer) that did not write it, against
one commit hash, using [review-rubric.md](review-rubric.md) and the procedure in
[adversarial-review.md](adversarial-review.md). Every finding is recorded and has a
[disposition](../glossary.md#disposition). Records are tracked under `reviews/` and do not
change once committed.

## 9. Code and tests

- A test exercises the shipped subject, not a copy written inside the test, and has a
  negative control that shows it fails when its target defect is present.
- Every security control has a test that attacks it, covering the case, encoding,
  normalization, and omitted-value forms that apply.
- A change that relaxes a validation or a security rule adds a test showing that the guard
  which remains still fires.
- Each shared interface, constant set, and vocabulary has one owner. Other code consumes
  the owner and does not restate it.
- Everything built has a real caller, or names the exact backlog item that will wire it.
- A script ships with a contract that states what it is allowed to do and with its tests,
  beside it. The greenfield-owned scripts under `tools/` are the exception: their
  contracts and tests are kept in the greenfield repository, and none runs here.
- A change stays within its purpose. Unrelated refactoring and reformatting are left out.

## 10. Change log

A repository keeps a change log: one [entry](../glossary.md#change-log-entry) for each
session under `docs/change_log/`, and `docs/change_log.md`, a list that
`tools/change_log.sh` generates from the entries and that MUST NOT be edited by hand. The
form of an entry, the tags, the `change-log` gate, and what it merges are in
[change-log.md](change-log.md).
