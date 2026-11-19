---
id: backlog-b001
title: "B001 Language toolchain"
is_source_of_truth: true
derives_from: [greenfield-start-here]
status: current
---

# B001 Language toolchain

- **State:** open.
- **Blocks MVP:** yes.
- **Depends on:** OQ-1 in `docs/open-questions.md` (the owner's choice of language).
- **Owner:** @@OWNER@@.

## Deliverable

Pull request 1: a pinned toolchain for the chosen language or languages, with `format`,
`format-check`, `lint`, and `test` wired to it, so that `make commit` passes locally and in
CI. No product code.

## Implements or updates

- Carries out [start-here.md step 1](../docs/greenfield/start-here.md#4-step-1-language-toolchain)
  and [specification.md §6](../docs/greenfield/specification.md#6-quality-gates).
- Adds a decision tagged `tooling`: the language, the runtime version, the formatter, the
  linter, the test runner, how versions are pinned, and the alternatives rejected.
- Marks OQ-1 resolved in `docs/open-questions.md`.
- Updates `Makefile`, `.gitignore`, `.github/workflows/ci.yml`, and, if the source file
  extension is not already scanned, `.llm-file-size-guard.toml`.
- Updates `docs/design.md` §11 and §13 and `docs/decisions.md` so that nothing still calls
  the four gates or the decision-log test planned.
- Updates `README.md` with how to set up and run the gates.

## Consumer

Every later change: `make commit` is the gate each one passes.

## Tests required

- One real test in the project's test runner, so that `make test` runs something.
- A test that the decision index and the decision files agree, by the rules under
  "Rules", "Adding a decision", and "Tags" in `docs/decisions.md`: file names, front matter
  keys and values, numbering without gaps, tags from the vocabulary, relations recorded on
  both sides, and both tables matching the files. Negative controls plant one defect in the
  text of a real entry and require that defect to be reported.
- For each of `format-check`, `lint`, and `test`: shown to fail when given something that
  should fail, and to fail, not pass, when it finds nothing to check.

## Done when

- `make commit` exits 0 locally. Evidence: the output.
- The [operator](../docs/glossary.md#operator) pushes the branch and opens the pull
  request (an agent hands it over).
- CI has run `make commit` on the pull request and passed. Evidence: the run. A statement
  that it should pass is not evidence.
- `make stubs` lists the same markers as before, less any this change wrote.
- This file is deleted in the pull request.
