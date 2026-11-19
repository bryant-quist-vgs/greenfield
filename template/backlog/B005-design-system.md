---
id: backlog-b005
title: "B005 Design: the system"
is_source_of_truth: true
derives_from: [greenfield-start-here, design]
status: current
---

# B005 Design: the system

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** B002, B003, B004.
- **Owner:** @@OWNER@@.

## Deliverable

The rest of `docs/design.md` written: §4 system context, §5 components and ownership, §6
interfaces and data, §8 failure handling, and §9 invariants. A section that outgrows the
size budget is moved to its own document and added to the document map.

## Implements or updates

- Carries out [start-here.md §5.5](../docs/greenfield/start-here.md#55-the-system).
- Every shared interface, schema, constant set, and vocabulary has one named owner.
- Every trust boundary from `docs/threat-model.md` sits in a named component.
- Every component can be exercised by the plan in `docs/sandbox-testing.md`; where it
  cannot, the design changes or the gap is recorded there.
- Records each choice as a decision and each unknown as an open question. This item may be
  split into several, one for each large section, when it is started.

## Consumer

B006 reviews the whole design and writes the implementation backlog from it.

## Tests required

None in code. Every invariant names the test or mechanism that will keep it true.

## Done when

- No stub marker remains in `docs/design.md`. Evidence: `make stubs`.
- `make commit` passes.
- Each increment is committed and has an adversarial review with the scope
  `design-increment` for its commit, with a disposition for every finding.
- Every `fix-now` finding from those reviews is `verified`.
- This file is deleted in the change that completes it.
