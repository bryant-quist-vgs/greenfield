---
name: prose
description: The owner's six rules for every page in this repository and in every repository placed from it; read before writing or editing prose.
type: owner
date: 2026-11-18
---

The owner's rules for prose, in the owner's words. They apply to every page here and to
every file under `template/`, which carries the same rules into each new repository as
[template/.agent_notes/prose.md](../template/.agent_notes/prose.md).

A page states what is true and what to do.

1. Say who runs a command. Write "run X" only for a command an agent may run. For a
   guarded, credentialed, or operator-run verb, write "the operator runs X (an agent hands
   it over)".
2. Agree with the code. Check every command, path, flag, and default against the script
   before writing it.
3. No history. Describe the current state, not how it came about: no "used to", "now
   lives", "no longer", "was moved", "replaces".
4. No wording relative to a version. State the behavior: no "since v6", "as of contract
   v5", "new in".
5. No date or background that is not part of the rule. No "since 2026-11-02", no "per the
   retrospective". A date stays when it is the fact itself: evidence, a staleness caveat,
   a cutoff the reader tests against. A reason stays when it changes what the reader does.
6. No wording relative to an external specification. State the behavior: no "read <x>
   from project <y> first", "design follows <x> with <y> exceptions", "Builds upon
   external specification". The exceptions to this are industry standard specifications
   and compliances that are being referenced directly, not adapted.

Records are exempt, and are where history goes: `docs/decisions.md`, `docs/changelog.md`,
and their respective log files.

**How to apply:** in this repository the records are the "Change log" section of each
script contract (`greenfield_init_contract.md`,
`tools/review_lint_contract.md`, and
`tools/change_log_contract.md`), and `template/docs/decisions.md` with the
decision files under `template/docs/decisions/`. This repository has no `reviews/`
directory and no `docs/change_log/`; in a placed repository the committed review records
under `reviews/` and the change log entries under `docs/change_log/` are records too.
The change log the rules name is the file `docs/change_log.md` in a placed repository; it
is generated from the entries and is not written by hand, and the template holds it with
no entry. That reading is the maintaining agent's, not the owner's words. Which commands
an agent may run here, and which the operator runs, is stated in the "Who runs what" rule
of [AGENTS.md](../AGENTS.md).
