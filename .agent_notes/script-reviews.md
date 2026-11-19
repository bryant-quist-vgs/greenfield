---
name: script-reviews
description: What a review of either script trio needs, what the reviews of 2026-11-18 did not cover, and what a change to either goes through.
type: process
date: 2026-11-18
---

There are three trios: `greenfield_init.sh`, `template/tools/review_lint.sh` with its two
awk programs, and `template/tools/change_log.sh`. The "Change log" section of each
contract (`greenfield_init_contract.md`, `tools/review_lint_contract.md`,
`tools/change_log_contract.md`) records its reviews. Those of the first two were
all made on 2026-11-18, and the points below come from them.
What is worth knowing beyond that record:

- **A second fresh reviewer finds what the first does not.** In the reviews of
  2026-11-18 the first reviewer of each trio found the plain faults. A second fresh
  reviewer, told what the first had found and asked to verify it and then start again,
  found a different kind: for the linter, ways to show a reader something the linter
  never saw. Expect a third reviewer to find more. Do not read a reviewed contract
  version as "finished".
- **No review ran a script with crafted inputs.** The sandbox refuses
  `bash <script>` ([sandbox-limits](sandbox-limits.md)), so the reviewers ran the suites
  through `make` and probed the awk programs and Git directly. Their findings about the
  shell scripts rest on reading plus the tests. A review made where the script can be
  run with crafted inputs would be stronger.
- **Give one reviewer the contract and another the real states.** For `change_log.sh`
  one reviewer read the code against the contract, and a second ran the script's exact
  Git commands in scratch repositories in the states a session is really in. The second
  kind found what tests written by the author could not: the tests committed first, and
  a session does not. A script that drives Git needs that second review after every
  change to a command line.
- **Have the reviewer follow the advice a script prints.** `change_log.sh` stopped
  losing files in its own merge two rounds before its printed advice ("commit, then
  `git merge <hash>`") stopped losing them. A message that tells the reader to run a
  command is part of what the script does: ask the reviewer to run it, literally, in
  the state that produces the message.
- **The first-run list of gates is written by hand in six places:** the next steps of
  `greenfield_init.sh` and its test, `README.md`, the `template-check` target,
  `template/docs/greenfield/start-here.md` §3, and
  `backlog/G002-verify-placed-ci-and-linux.md`. No test compares them. A gate added to
  the template, or removed from it, changes all six, and the init script's part is a
  contract version.
- **Run the suites from the root:** `make test`. The contracts and tests of the placed
  tools are in `tools/`, and a placed repository has neither
  ([owner-requirements](owner-requirements.md), item 13).
- **When reviews keep finding rarer faults in the same code, question the design, and
  ask the owner.** The merge in `change_log.sh` went through five rounds, each fixing
  what the last found, before the owner was asked; the owner chose a simpler merge
  ([owner-requirements](owner-requirements.md), item 12). After a second round of
  findings in one piece of code, stop and put the choice to the owner: keep fixing,
  declare the rare states as limits, or change the design so the states cannot arise.
- **Give a returning reviewer the claims, not the conclusions:** "the author claims X is
  fixed at Y; verify". Resume the same reviewer to confirm fixes, which takes a few
  minutes; use a fresh one for a fresh look.
- **Nothing has been run on Linux, under mawk or gawk, or with a Git older than 2.50:**
  `backlog/G002-verify-placed-ci-and-linux.md`.

**How to apply:** a change to any of the scripts that touches an input, an output, a behavior,
a capability, or an assumption is a new contract version: mark it unratified, have a
session that did not write it review it with the review prompt of the `auditable-script`
skill (`review-prompt.md`; [reference-repositories](reference-repositories.md)), fix, and
ratify once.
