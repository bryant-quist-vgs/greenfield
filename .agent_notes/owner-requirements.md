---
name: owner-requirements
description: What the owner asked the default repository to be, on 2026-11-18; the test for any change to it.
type: owner
date: 2026-11-18
---

What the owner asked for, in the owner's terms. A change that breaks one of these needs
the owner's agreement first.

1. A specification for a new repository with **no checklist requirements**, a
   **Glossarian-compliant glossary**, and **llm-size-guard**, both wired as make targets.
2. **Decisions are split from the start**: an index and one file for each decision.
   Reason: a single `decisions.md` passes the size limit within days; it did in
   `auditable_script` and in `tart_taste_test`.
3. A **default repository**: templated documentation, a **stubbed backlog**, a
   **`CLAUDE.md` that points to `AGENTS.md`**, and an `AGENTS.md` that points to
   **`.agent_notes/index.md`**, a vendor-agnostic agent memory store.
4. **Language agnostic** for now, with **macOS-focused `.gitignore` rules**.
5. A **specification for the agent starting out**: what has been placed, and the first
   steps. Step 1: language toolchain, as pull request 1. Step 2: design, which covers at
   least the goal, the MVP for version 1, the threat model, and how agents test end to end
   in the sandbox (what is stubbed, what synthetic data is constructed).
6. **Adversarial review of the design throughout**, not once at the end. All findings are
   tracked. Only findings that are **expensive to fix later or would block the MVP** are
   resolved during design, because much changes during development and cheap fixes may
   stop applying. **Fixes are resubmitted for review.**
7. **Every adversarial review is against a specific commit hash.**
8. The rubric **links no specific decision items** and has **no severity cut**, because
   agents score severity badly. It has both **per-item axes** and **cross-item axes**.
9. A **template for the adversarial review that is strict enough to be machine
   parsable**.
10. A **change log**, in the owner's words: "The specification needs to include the
    docs/change_log.md as a similar corollary to docs/decisions.md. It will have it's own
    docs/change_log/. One key difference is that 'docs/change_log.md will be a fully
    generated file from the items in docs/change_log/." And "a single tool that records a
    sessions changes and makes sure that upstream changes are sufficiently merged in
    where merges are trivial. This should be wired into make commit."
11. **Change log tags with a baseline set**, in the owner's words: "Projects can extend
    the tag grammar but a baseline reasonable set needs to be available so that different
    projects don't make their own choices about what to tag maintenance or a feature or a
    security fix or a refactor, etc."

12. **A simple merge in the change log tool.** On 2026-11-18 the owner asked "why this
    is taking 6 rounds to adapt a tool that already exists", and, offered "ratify after
    round 6" or "simplify the merge" (the gate merges only when the working tree is
    clean, or only moves a branch forward, and otherwise reports that the upstream is
    not merged), answered: "Simplify the merge". The agent's reading: the owner wants a
    tool about as simple as the two it was modelled on, and does not want review rounds
    spent on rare states. Which of the two forms, and the exact conditions, are the
    agent's choice ([change-log-design](change-log-design.md), item 7).

13. **The placed tools are managed in greenfield,** in the owner's words (2026-11-18):
    "these scripts should be managed in this repository not repositories building on
    the template. Tests should not run in the repositories built on these tools." The
    agent's reading: a placed repository receives the scripts it runs and runs no test
    of them; the contracts and the tests are in `tools/` here. That the contracts are
    not placed either is the agent's choice, not the owner's words.

What the maintaining agent chose in order to build items 10 to 13, and the owner has not
confirmed, is in [change-log-design](change-log-design.md).

The documents the owner named as starting points for items 1, 2, and 8 are listed in
[reference-repositories](reference-repositories.md).

**How to apply:** before changing the template, check the change against this list.
Items 6 to 9 are the ones most easily eroded: a "priority" field on a finding is a
severity; a review of a working tree is not a review of a commit.
