---
id: backlog-b003
title: "B003 Design: threat model"
is_source_of_truth: true
derives_from: [greenfield-start-here, threat-model]
status: current
---

# B003 Design: threat model

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** B002.
- **Owner:** @@OWNER@@. What risk is acceptable is the owner's to say.

## Deliverable

`docs/threat-model.md` written: assets, actors and trust, trust boundaries, threats with
the design's response to each, what is not defended, and assumptions. `docs/design.md` §7
written as a short summary that links to it.

## Implements or updates

- Carries out [start-here.md §5.3](../docs/greenfield/start-here.md#53-the-threat-model).
- Keeps the two actor rows for the [working agent](../docs/glossary.md#working-agent) and
  the [reviewer](../docs/glossary.md#reviewer), and threat T-1, adjusted to the project.
- Each accepted risk is a decision. Each threat left for later is a row in
  `docs/deferred-work.md`. Each threat outside the boundary is an entry in
  `docs/out-of-scope.md`.

## Consumer

B004 plans a test that attacks each response. B005 places each boundary in a component.

## Tests required

None in code. Every row of the threats table names the test that will attack its response,
or the backlog item that will add it.

## Done when

- No stub marker remains in `docs/threat-model.md` or `docs/design.md` §7. Evidence:
  `make stubs`.
- `make commit` passes.
- The increment is committed and an adversarial review with the scope `design-increment`
  exists for that commit, with a disposition for every finding.
- Every `fix-now` finding from that review is `verified`.
- This file is deleted in the change that completes it.
