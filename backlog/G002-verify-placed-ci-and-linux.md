# G002 Verify the placed CI workflow and the scripts on Linux

- **State:** open.
- **Depends on:** a repository on GitHub created from greenfield, or G003.
- **Owner:** Bryant Quist.

## Deliverable

Evidence, from a real run on `ubuntu-latest`, that:

1. `make install-linters` installs glossarian and llm-size-guard from the pinned
   `git+https` URLs with no credentials;
2. `make change-log docs-lint llm-size-guard reviews-lint` pass on a fresh
   stamp;
3. `template/tools/review_lint.sh` and its tests pass under the `awk` that Ubuntu provides (mawk
   or gawk) and GNU `sort`, `wc`, and `tr`;
4. `greenfield_init.sh` and its tests pass with GNU `find`, `sort -z`, `sed`, and `grep`;
5. the linter's history checks (RL09, and the refusal of shallow and partial clones)
   behave the same with the Git that Ubuntu provides. The only evidence for them is from
   Git 2.50 on macOS;
6. `template/tools/change_log.sh` and its tests pass under the same `awk` and Git, the test of a
   merge included;
7. the step of the placed workflow that sets the default branch of `origin` gives the
   `change-log` gate its upstream, on a pull request and on a push to `main`, and the
   gate then judges a pull request as `change-log.md` states: one with no change
   log entry fails under CL04, and one with an entry passes.

## Why

The only evidence that the scripts and their tests pass is from macOS, on 2026-11-18:
bash 3.2, BSD awk, BSD userland. `template/.github/workflows/ci.yml` says in its own
header that it is not verified by a run. The awk programs avoid interval expressions and
other known differences, but that is care, not evidence. If the gate in CI knows no
upstream, its base is `HEAD`, nothing differs from it in a fresh checkout, and CL04
passes without having checked anything.

## Implements or updates

- `template/.github/workflows/ci.yml`: remove "This workflow has not been verified by a
  run." once it has been.
- The "Assumptions for operation" of each contract, if a difference is found.
- `.agent_notes/`: a note recording what was verified, where, and when.

## Done when

The run exists and its link is in the note. Any difference found is fixed with a test
that would have caught it.
