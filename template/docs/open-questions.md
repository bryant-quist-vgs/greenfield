---
id: open-questions
title: Open questions
is_source_of_truth: true
derives_from: [design]
status: current
---

# Open questions

Questions the design does not yet answer. The design must not guess around them. A
resolved question is marked resolved here and its answer moves to the document named in
its entry. The [MVP](glossary.md#mvp) is defined in
[design.md §3](design.md#3-mvp-for-version-1). Terms are defined in the
[glossary](glossary.md#definitions).

Owner of every question: @@OWNER@@, unless its entry says otherwise.

Each entry has this form. IDs run from OQ-1 and are never reused.

```
## OQ-<n> <the question, as a question>

- **Blocks MVP:** yes or no, and what it holds up.
- **Needed to close:** the decision or the evidence that would settle it.
- **Depends on:** other questions, backlog items, or outside events; or nothing.
- **Answer goes to:** the document and section that will receive the answer.
```

## OQ-1 Which language or languages, and which toolchain?

- **Blocks MVP:** yes. Nothing can be built, and `make commit` cannot pass, until it is
  answered.
- **Needed to close:** the owner's choice of language and runtime version; the formatter,
  the linter, and the test runner for each; how their versions are pinned.
- **Depends on:** nothing.
- **Answer goes to:** a new decision tagged `tooling`, and the `Makefile`. Backlog B001
  does the work.
