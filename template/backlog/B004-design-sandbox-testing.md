---
id: backlog-b004
title: "B004 Design: end-to-end testing in the sandbox"
is_source_of_truth: true
derives_from: [greenfield-start-here, sandbox-testing]
status: current
---

# B004 Design: end-to-end testing in the sandbox

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** B002, B003.
- **Owner:** @@OWNER@@.

## Deliverable

`docs/sandbox-testing.md` written: how an agent inside its
[sandbox](../docs/glossary.md#sandbox) runs every MVP scenario from end to end, what is
stubbed and how each stand-in is kept true, what synthetic data is constructed and how,
the commands, and what a sandbox run does not prove. `docs/design.md` §10 written as a
short summary that links to it.

## Implements or updates

- Carries out
  [start-here.md §5.4](../docs/greenfield/start-here.md#54-end-to-end-testing-in-the-sandbox).
- States the sandbox's limits as observed in a real session, not as assumed. Try the thing
  (a network call, a listening port, a write outside the repository) and record the result.
- Where a scenario cannot be run in the sandbox at all, says so in §6 of that document and
  names who covers it. Where the goal or the MVP makes end-to-end testing impossible, that
  is raised with the owner as an open question, not worked around.

## Consumer

B005 designs components so that the plan here can run. Every later item's tests follow
this plan.

## Tests required

None in code yet. Every MVP scenario has a row naming its planned test; every threat
response from B003 has a planned test that attacks it.

## Done when

- No stub marker remains in `docs/sandbox-testing.md` or `docs/design.md` §10. Evidence:
  `make stubs`.
- `make commit` passes.
- The increment is committed and an adversarial review with the scope `design-increment`
  exists for that commit, with a disposition for every finding.
- Every `fix-now` finding from that review is `verified`.
- This file is deleted in the change that completes it.
