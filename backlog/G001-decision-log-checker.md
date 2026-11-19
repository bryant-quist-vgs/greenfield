# G001 A decision-log checker shipped by the template

- **State:** open.
- **Depends on:** nothing.
- **Owner:** Bryant Quist.

## Deliverable

`template/tools/decision_log_lint.sh`, with its contract and tests in `tools/`, and a
`decisions-lint` target in `template/Makefile` that `commit` runs. It checks
`docs/decisions.md` and every file under `docs/decisions/` by the rules the index states
under "Rules", "Adding a decision", and "Tags".

## Why

Backlog item B001 of every new repository asks the project to write this test in its own
language. Every project re-implements about 300 lines, the implementations drift, and the
decision log goes unchecked until pull request 1 lands, which is exactly when the design
phase writes most decisions. Two such tests, useful as examples, are
`auditable_script/tests/test_decision_log.py` and `tart_taste_test/tests/docs_test.py`.

## Implements or updates

- `template/docs/decisions.md`: where it says the rules are checked by hand, name the
  gate.
- `template/backlog/B001-language-toolchain.md` and `start-here.md` step 1: remove the
  decision-log test.
- `template/docs/greenfield/specification.md` §3.4 and §6.1.
- `VERSION`.

## Tests required

Shell tests for each of these checks: file names, front matter keys and values, numbering
without gaps, tags from the vocabulary and in order, relations recorded on both sides,
both index tables matching the files. `auditable_script/tests/test_decision_log.py` makes
the same checks in Python and is useful as a model. One planted defect for each rule, and
the placed D1 as the passing case.

## Done when

`make commit` passes here, `make template-check` runs the new gate on a fresh stamp, and
the trio is reviewed and ratified.
