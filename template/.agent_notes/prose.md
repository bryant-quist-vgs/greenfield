---
name: prose
description: The owner's six rules for every page in this repository; read before writing or editing prose.
type: owner
date: @@DATE@@
---

The owner's rules for prose. They apply to every page in this repository: documents,
notes, backlog items, comments, and the messages a script prints.

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

**How to apply:** in this repository the records are `docs/decisions.md` with the files
under `docs/decisions/`, the change log entries under `docs/change_log/`, committed
review records under `reviews/`, and the "Change log" section of a script contract. The
change log the rules name is the file `docs/change_log.md` here; it is generated from the
entries and is not written by hand. Which
commands an agent may run, and which the operator runs, is stated in
[docs/greenfield/specification.md §6.1](../docs/greenfield/specification.md#61-targets).
