---
id: glossary
title: Glossary
is_source_of_truth: true
derives_from: []
status: current
---

# Glossary

Canonical vocabulary for @@PROJECT_NAME@@. Other documents link here; they do not redefine
terms. Each `###` entry under Definitions is one term; link to it by this file's relative
path plus `#` and the term's slug.

## Governance

```glossary
governs: ../
```

This glossary governs every document in the repository. Terms are added, renamed, and
retired in the same change that introduces or alters the thing they name. A renamed term
keeps a row in the [renames table](glossary.md#renames-and-deprecated-terms). The terms
below are used by the policy under `docs/greenfield/` and by `AGENTS.md`; the project adds
its own terms beside them and does not remove these.

## Definitions

### adversarial review
```glossary
aliases: review
short: An examination of the work at one commit by a reviewer that did not write it.
```
An examination of the work at one commit hash by a [reviewer](glossary.md#reviewer) that
did not write it, whose purpose is to find what is wrong. It follows the rubric and the
procedure under `docs/greenfield/` and ends in a
[review record](glossary.md#review-record).

### backlog item
```glossary
confusable: finding
```
One file under `backlog/` that describes one bounded piece of work belonging to the current
delivery and not yet done. The file is deleted in the change that completes the work.

### change log entry
One file under `docs/change_log/` that records what a session changed and why, under
tags that say what kind of change it is. `docs/change_log.md` is the list of the entries
and is generated from them. `docs/greenfield/change-log.md` gives the form of an
entry, the tags, and when an entry is written.

### cross-item pass
```glossary
see: per-item-pass
```
The part of an [adversarial review](glossary.md#adversarial-review) that judges everything
completed so far as one body of work, on the six cross-item axes of the rubric.

### disposition
What is to be done about a [finding](glossary.md#finding): `fix-now`, `later`, or
`declined`. It follows from two questions, whether the finding blocks the
[MVP](glossary.md#mvp) and whether it would be expensive to fix later, and is recorded in
the review's disposition file together with the finding's state.

### finding
```glossary
confusable: backlog item
```
One problem reported by a [reviewer](glossary.md#reviewer): what is there, the evidence,
and what goes wrong because of it. A finding has an ID of the form `R01-F01`, an axis, and
no severity.

### item
The unit of work one [per-item pass](glossary.md#per-item-pass) judges: a design increment,
the change that completes one [backlog item](glossary.md#backlog-item), or one pull
request.

### MVP
The minimum viable product for version 1: the smallest delivery that meets the project's
goal. `docs/design.md` defines what is in it and the end-to-end scenarios that show it
works.

### operator
The person at the machine who runs what an agent may not: `make install-linters`, and
anything that needs credentials or leaves the machine. `docs/greenfield/specification.md`
§6.1 states which commands those are. Often, but not necessarily, the owner.

### per-item pass
```glossary
see: cross-item-pass
```
The part of an [adversarial review](glossary.md#adversarial-review) that judges one
[item](glossary.md#item) on the eight per-item axes of the rubric.

### review record
The file under `reviews/` that a [reviewer](glossary.md#reviewer) writes for one
[adversarial review](glossary.md#adversarial-review). It names the commit reviewed and
holds every [finding](glossary.md#finding). It does not change once committed.

### reviewer
```glossary
confusable: working agent
```
The agent session or person that carries out an
[adversarial review](glossary.md#adversarial-review). A reviewer wrote none of the work
under review, changes neither that work, the history, nor a committed record, and does not
decide what is done about its findings.

### sandbox
The restricted environment an agent session runs in: limited file access, limited or no
network, and no access to the other processes and credentials of the
[operator](glossary.md#operator).
`docs/sandbox-testing.md` states what this project's tests can and cannot do inside one.

### stub marker
A line beginning `> **GREENFIELD-STUB**` that stands where content has not been written and
says what belongs there. `make stubs` lists every one.

### upstream
The branch that `refs/remotes/origin/HEAD` names in a clone, as the clone holds it. A
session's work is compared with its commit and has it merged in.
`docs/greenfield/change-log.md` §6 says what holds when a clone has no upstream.

### working agent
```glossary
confusable: reviewer
```
The agent session, or person, that writes the work: it commits, requests reviews, proposes
[dispositions](glossary.md#disposition), and makes fixes.

## Confusable Pairs

| Term | Confusable with | Distinction |
|---|---|---|
| [finding](glossary.md#finding) | [backlog item](glossary.md#backlog-item) | A finding is a reviewer's report of a problem and lives in a review record. A backlog item is work to be done. A finding left for later gets a backlog item; the finding itself stays in its record. |
| [working agent](glossary.md#working-agent) | [reviewer](glossary.md#reviewer) | The working agent writes and fixes. The reviewer reads and reports. One session is never both for the same work. |
| [per-item pass](glossary.md#per-item-pass) | [cross-item pass](glossary.md#cross-item-pass) | The per-item pass judges one item. The cross-item pass judges the whole body of work for what no single item shows. |

## Renames and deprecated terms

| Avoid | Use | Why |
|---|---|---|
| severity (of a finding) | disposition | A finding is not graded. What is done about it follows from two yes-or-no questions. |
| assessment | adversarial review | One name for the activity. |
| V1 | MVP | The first delivery is called the MVP for version 1. |

## Reserved Targets

None.
