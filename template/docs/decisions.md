---
id: decisions
title: Decision log
is_source_of_truth: true
derives_from: [design, glossary]
status: current
authority: >
  Canonical home for why the project is the way it is. Each entry is a settled decision
  and lives in its own file under docs/decisions/; this file is the index of those files.
  Unsettled matters live in open-questions.md, not here.
---

# Decision log

Each decision has its own file under [decisions/](decisions/). This file is the index of
those files. It holds the rules, the tag vocabulary, and the tables that list every
decision.

## Rules

Every entry records: status, date, context, decision, rationale, rejected alternatives,
and consequences. Status, date, and the relations to other decisions are in the front
matter of the entry's file. The rest is in its body. A decision that replaces another
names it under `supersedes`. A decision that changes part of another names it under
`amends`. Entries are never deleted; a reversed decision is marked `superseded` and points
to its replacement. A decision that is re-opened is entered in
[open-questions.md](open-questions.md).

`built` says whether a person or an agent who follows the repository today can act as the
decision says: `yes` when the code, the documents, the gates, or the tests carry it out;
`no` when it is decided and waits on work not yet done, which the entry's status note
names. A superseded entry keeps the value it had.

The owner of every decision is the repository owner, @@OWNER@@, unless its entry says
otherwise. Terms are defined in the [glossary](glossary.md#definitions).

## Adding a decision

1. Take the next number. Numbers run from 1 without gaps and are never reused.
2. Create `docs/decisions/d<NN>-<slug>.md`. `NN` is the number padded to two digits. The
   slug is 2 to 6 lowercase words from the title, joined by hyphens.
3. Write the front matter below, every key on one line. `id` is the file name without
   `.md`.
4. Write the body: a `# D<n>. <title>` heading, then the bullets Context, Decision,
   Rationale, Rejected, and Consequences. If the state needs a sentence (decided and not
   yet built, changed by a later decision, or which finding it answers), put it first, in
   a `**Status note:**` bullet.
5. Choose 1 to 4 tags from the vocabulary, in alphabetical order. Tags name the subject
   only. State is carried by `decision_status` and `built`.
6. If the decision supersedes or amends another, record both sides: `supersedes` here and
   `superseded_by` there, or `amends` here and `amended_by` there. A superseded entry also
   gets `decision_status: superseded`.
7. Add the row to "All decisions" and the decision to each of its tags under "By tag".
   When the decision is built, set `built: yes` in both places.

```
---
id: d07-requests-one-at-a-time
title: "D7. Requests are served one at a time"
is_source_of_truth: true
derives_from: [decisions]
status: current
decision: D7
date: 2026-01-31
decision_status: accepted
built: no
tags: [process]
supersedes: []
superseded_by: []
amends: [D3]
amended_by: []
---
```

`decision_status` is `accepted` or `superseded`. `built` is `yes` or `no`.

These rules are checked by hand today. Planned: a test, added by backlog B001 in the
project's own language, that checks every file against these rules and against the tables
below.

## Tags

A new tag is added here only when a decision fits none of these. There are at most 18
tags, and no tag is part of another tag's name.

| Tag | Subject |
|---|---|
| `process` | How this project organises its own documents, tests, reviews, and work. |
| `tooling` | The languages, tools, and dependencies the project is built with. |

## All decisions

| ID | Decision | Date | Status | Built | Tags | Relations |
|---|---|---|---|---|---|---|
| D1 | [The repository starts from the greenfield default and follows its specification](decisions/d01-starts-from-greenfield-default.md) | @@DATE@@ | accepted | yes | `process` |  |

## By tag

| Tag | Decisions |
|---|---|
| `process` | [D1](decisions/d01-starts-from-greenfield-default.md) |
| `tooling` |  |

## Querying

Run these from the repository root. Each prints the files that match.

Decisions that carry a tag (here `process`; the result is that tag's row above):

```
grep -lE '^tags: \[([a-z-]+, )*process(, [a-z-]+)*\]$' docs/decisions/*.md
```

Decisions that are not yet built, and decisions that are superseded:

```
grep -l '^built: no$' docs/decisions/*.md
grep -l '^decision_status: superseded$' docs/decisions/*.md
```

Decisions that a given decision amends or supersedes (here D7):

```
grep -lE '^(amended_by|superseded_by): \[(D[0-9]+, )*D7(, D[0-9]+)*\]$' docs/decisions/*.md
```

Two conditions at once (here tagged `process` and not yet built), and the titles in place
of the file names:

```
grep -lE '^tags: \[([a-z-]+, )*process(, [a-z-]+)*\]$' docs/decisions/*.md \
  | xargs grep -l '^built: no$'
grep -l '^built: no$' docs/decisions/*.md | xargs grep -h '^title: '
```
