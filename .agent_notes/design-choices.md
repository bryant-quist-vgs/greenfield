---
name: design-choices
description: Seventeen choices in the default repository that go beyond what the owner asked for; the owner confirmed all of them on 2026-11-18.
type: owner
date: 2026-11-18
---

None of these is in the owner's request ([owner-requirements](owner-requirements.md)).
Each is the maintaining agent's judgement, and the owner confirmed all seventeen on
2026-11-18 ("Those choices are fine"). Changing one changes what the owner agreed to: ask
first.

1. **Review records are tracked in Git under `reviews/`,** not kept in an ignored
   directory such as `.assessments/`. Reason: the owner works in Git worktrees, where
   ignored files do not follow, and "all findings are tracked" needs a tracked home.
2. **A review is two files:** a record the reviewer writes, which never changes after its
   first commit (the linter checks this), and a disposition file the working agent keeps.
   Reason: the working agent must not be able to soften a finding unnoticed.
3. **A finding has no severity. It answers two yes-or-no questions** (blocks the MVP;
   expensive later) and carries a `touches` field in which the reviewer lists the
   structural elements a fix would change. Any value other than `local` means "expensive
   later" by default. Reason: a structural fact is easier for an agent to get right than
   a grade.
4. **Opinions that state no consequence are "Remarks"**: kept in the record, not tracked
   as findings. This is a definition of a finding, not a cut, but it is the nearest thing
   to one. Reason: with no severity, preferences would otherwise flood the backlog.
5. **Only the owner may decline a finding.**
6. **A backlog item's file is deleted in the change that completes it.** A finding left
   for later must be brought to an end before the MVP is declared.
7. **The language gates fail until pull request 1 wires them,** so `make commit` and CI
   are red on a fresh repository. Reason: a gate that passes without checking anything is
   worse than one that fails.
8. **Unwritten sections carry a `GREENFIELD-STUB` marker,** and `make stubs` must pass at
   the design exit gate.
9. **`docs/threat-model.md` and `docs/sandbox-testing.md` are their own documents,** not
   sections of `design.md`. Reason: a design kept in one file outgrows it; the designs
   of `auditable_script` and `tart_taste_test` both did.
10. **The policy is copied into each new repository** under `docs/greenfield/` and marked
    greenfield-owned: not edited there, departed from by a decision record. Reason: an
    agent in a sandbox cannot read a policy kept in another repository.
11. **The decision-log consistency test is left to pull request 1,** in the project's own
    language. A shared checker shipped by the template is in the backlog (G001).
12. **The default `.gitignore` has no rule for `.assessments/`.** A placed repository
    keeps its review records under `reviews/`, tracked (choice 1).
13. **The linter pins use `git+https` URLs,** which need no credentials: both linter
    repositories answer anonymous `git ls-remote` over HTTPS (checked 2026-11-18). A
    `git+ssh` URL needs a key.
14. **This repository's own `.gitignore` holds rules for a shell-and-Markdown
    repository,** and none for a language toolchain.
15. **The review form is narrower than Markdown,** so that a program and a reader cannot
    disagree about it: a heading starts in column 1, a fence starts in column 1, a line of
    only `=` or `-` (a horizontal rule included) is refused, and a line that is one
    `<...>` is taken for an unfilled placeholder.
16. **Records and disposition files carry `form: 1`.** Reason: a later form must be
    told from this one without changing records that may not change.
17. **A review record may never be deleted or renamed once committed,** and the linter
    reports one that the history holds and the working tree lacks. The owner asked that
    all findings be tracked; this choice extends that to the records themselves.
