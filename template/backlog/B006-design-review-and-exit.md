---
id: backlog-b006
title: "B006 Design: whole-design review and exit gate"
is_source_of_truth: true
derives_from: [greenfield-start-here, adversarial-review]
status: current
---

# B006 Design: whole-design review and exit gate

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** B002, B003, B004, B005.
- **Owner:** @@OWNER@@.

## Deliverable

A whole-design [adversarial review](../docs/glossary.md#adversarial-review) at one commit,
with both passes; every finding from every review brought to its disposition; the backlog
items that build the [MVP](../docs/glossary.md#mvp); and the owner's agreement to the
design, recorded as a decision.

## Implements or updates

- Carries out
  [start-here.md §5.7](../docs/greenfield/start-here.md#57-the-whole-design-and-the-exit-gate).
- Requests the review with the scope `whole-design` and the passes
  `per-item, cross-item`, using the strongest reviewer available for the cross-item pass.
- Fixes each `fix-now` finding and resubmits the fix for review until it is `verified`.
- Files each `later` finding as `backlog/R<NN>-F<MM>-<slug>.md`.
- Writes one backlog item for each piece of MVP work, in the form `backlog/README.md`
  gives, ordered by what each depends on.
- Records the cadence of reviews during implementation as a decision
  ([adversarial-review.md §2](../docs/greenfield/adversarial-review.md#2-when-a-review-is-required)).
- Sets `status: current` in the front matter of the design documents, and removes the
  pointer to `start-here.md` from `AGENTS.md`.

## Consumer

Implementation: no backlog item that builds the product starts before this one is done.

## Tests required

None in code.

## Done when

Every condition of the exit gate in
[start-here.md §5.7](../docs/greenfield/start-here.md#57-the-whole-design-and-the-exit-gate)
holds. Evidence: the output of `make stubs` and `make commit`; the review records and
disposition files under `reviews/`; the decision that records the owner's agreement. This
file is deleted in the change that completes it.
