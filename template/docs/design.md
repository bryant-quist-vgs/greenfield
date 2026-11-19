---
id: design
title: "@@PROJECT_NAME@@ design"
is_source_of_truth: true
derives_from: [glossary]
status: draft
---

# @@PROJECT_NAME@@ design

The current-state description of what @@PROJECT_NAME@@ is and how its parts fit together.
Why it is this way is in [decisions.md](decisions.md). Terms are defined in the
[glossary](glossary.md#definitions). Sections marked with a
[stub marker](glossary.md#stub-marker) are not yet written;
[greenfield/start-here.md](greenfield/start-here.md) says in what order to write them.

## 1. Goal

> **GREENFIELD-STUB** State what the project is for in one paragraph a newcomer can repeat:
> the problem, for whom, and what is true once the project exists that is not true now.
> (Backlog B002.)

## 2. Users and boundary

> **GREENFIELD-STUB** Name who uses the project and how they reach it. Say where the
> project ends: what it takes in, what it gives out, and what it relies on others for.
> (Backlog B002.)

## 3. MVP for version 1

> **GREENFIELD-STUB** Define the [MVP](glossary.md#mvp): the smallest delivery that meets
> the goal. List what is in it. List the end-to-end scenarios, each with an ID (`S-1`,
> `S-2`), that show it works: who does what, and what they observe. Send everything left
> out to out-of-scope.md or deferred-work.md. (Backlog B002.)

## 4. System context

> **GREENFIELD-STUB** Describe what the project runs on and beside: operating systems,
> external tools and services, and who calls whom. (Backlog B005.)

## 5. Components and ownership

> **GREENFIELD-STUB** List each component with the one sentence that states its
> responsibility. Name the single owner of every shared interface, schema, constant set,
> and vocabulary. (Backlog B005.)

## 6. Interfaces and data

> **GREENFIELD-STUB** Specify each public or shared interface and each data format: exact
> names, fields, defaults, and edge cases. Say what state exists, who owns it, and how long
> it lives. Move this to its own document when it outgrows the size budget, and add that
> document to §12. (Backlog B005.)

## 7. Trust and threats

> **GREENFIELD-STUB** Summarize the trust boundaries in a few lines and link to
> [threat-model.md](threat-model.md), which is their home. Do not restate the threats here.
> (Backlog B003.)

## 8. Failure handling

> **GREENFIELD-STUB** For each way the project can fail, say what it does: what the caller
> sees, what is left behind, and what happens on retry. (Backlog B005.)

## 9. Invariants

> **GREENFIELD-STUB** List what must always be true, each with an ID (`I-1`, `I-2`) and the
> test or mechanism that keeps it true. (Backlog B005.)

## 10. Testing

> **GREENFIELD-STUB** Say in a few lines how the project is tested and link to
> [sandbox-testing.md](sandbox-testing.md), which is the home of the end-to-end plan.
> (Backlog B004.)

## 11. Current and planned

Nothing is built. This repository holds the default documents and gates placed by
greenfield (decision [D1](decisions/d01-starts-from-greenfield-default.md)).

When something is built, this section lists what exists. Everything else in this document
that is not yet built is marked planned and names the backlog item that will build it.

## 12. Document map

One file fills each role. When a change alters what a document describes, update that
document in the same change.

| Role | File | Update when |
|---|---|---|
| Central design | `docs/design.md` | The goal, the MVP, a component, an interface, or an invariant changes. |
| Glossary | [glossary.md](glossary.md) | A term is added, renamed, or retired. |
| Decisions | [decisions.md](decisions.md) and `docs/decisions/` | A choice is settled, amended, or reversed. |
| Change log | `docs/change_log/`, listed in [change_log.md](change_log.md) | Every change adds an entry. The list is generated and never edited by hand. |
| Change log tags of this project | `docs/change_log/tags.md` | The project adds a tag of its own. |
| Open questions | [open-questions.md](open-questions.md) | A question is found or answered. |
| Out of scope | [out-of-scope.md](out-of-scope.md) | The boundary of the project is set or moved. |
| Deferred work | [deferred-work.md](deferred-work.md) | Work is moved past the current delivery, or brought back. |
| Threat model | [threat-model.md](threat-model.md) | An asset, an actor, a boundary, or a threat response changes. |
| Sandbox testing | [sandbox-testing.md](sandbox-testing.md) | A scenario, a stand-in, or synthetic data changes. |
| Policy | [greenfield/specification.md](greenfield/specification.md) | Never in this repository. A departure is a decision. |
| Review procedure and rubric | [greenfield/adversarial-review.md](greenfield/adversarial-review.md), [greenfield/review-rubric.md](greenfield/review-rubric.md) | Never in this repository. |
| Backlog | `backlog/` | Work is found, changed, or completed. |
| Reviews | `reviews/` | A review is recorded or a finding's state changes. |
| Agent instructions | `AGENTS.md` | How agents should work here changes. |
| Agent notes | `.agent_notes/` | An agent learns something the next one would have to rediscover. |

## 13. Quality gates

The gates are targets of the `Makefile`; `make help` lists them.
[greenfield/specification.md §6](greenfield/specification.md#6-quality-gates) states what
each must do. `make commit` runs every gate except `format` and `stubs`, and is the only
gate CI runs. It starts with the `change-log` gate, which outside CI can merge the
upstream branch into the work and regenerates `docs/change_log.md`
([greenfield/change-log.md](greenfield/change-log.md)). An agent
may run every target except `install-linters`: the [operator](glossary.md#operator) runs
`make install-linters` (an agent hands it over).

`format`, `format-check`, `lint`, and `test` are planned: they fail until backlog B001
wires them to the project's toolchain.
