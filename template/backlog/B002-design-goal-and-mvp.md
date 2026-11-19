---
id: backlog-b002
title: "B002 Design: goal and MVP"
is_source_of_truth: true
derives_from: [greenfield-start-here, design]
status: current
---

# B002 Design: goal and MVP

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** B001.
- **Owner:** @@OWNER@@. The goal and the MVP are the owner's to state; ask, do not invent.

## Deliverable

`docs/design.md` §1 to §3 written: the goal, the users and boundary, and the
[MVP](../docs/glossary.md#mvp) for version 1 with its end-to-end scenarios, each with an
ID. First entries in `docs/out-of-scope.md` and `docs/deferred-work.md` for what the MVP
leaves out.

## Implements or updates

- Carries out [start-here.md §5.1 and §5.2](../docs/greenfield/start-here.md#51-the-goal).
- Adds the project's own terms to `docs/glossary.md` as they appear.
- Records each choice made on the way as a decision; records what is not yet known as an
  open question.

## Consumer

B003, B004, and B005 are written against the goal and the scenarios defined here.

## Tests required

None in code. The scenarios are written so that B004 can turn each into a test: each names
who does what and what they observe.

## Done when

- No [stub marker](../docs/glossary.md#stub-marker) remains in `docs/design.md` §1 to §3,
  `docs/out-of-scope.md`, or `docs/deferred-work.md`. Evidence: `make stubs`.
- `make commit` passes.
- The increment is committed and an
  [adversarial review](../docs/glossary.md#adversarial-review) with the scope
  `design-increment` exists for that commit, with a disposition for every finding.
- Every `fix-now` finding from that review is `verified`.
- This file is deleted in the change that completes it.
