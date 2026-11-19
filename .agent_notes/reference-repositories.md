---
name: reference-repositories
description: Outside repositories and documents worth reading before a large change to the default, and what each is useful for; read on 2026-11-18.
type: reference
date: 2026-11-18
---

All are the owner's. The repositories are siblings of this one on the owner's machine
(`~/bryant_repos/`). What is said of each was read on 2026-11-18, and they keep moving:
read them again before a large change. None is an authority for greenfield; the
specification under `template/docs/greenfield/` is.

- **`tart_taste_test/greenfield-project-specification.md`**: a specification for
  checklist-driven work ("Sedric-style"), and the document the owner's request named as
  the starting point. Useful for the fuller reasoning behind rules greenfield's
  specification shares with it: document metadata, one fact one home, the document roles,
  out of scope versus deferred, planned behavior kept apart from current, the Makefile
  targets and CI parity, the ignore-file policy, and the code-and-test rules of its
  failure-prevention table. Greenfield has none of its §4 (checklists), no
  `.checklists/`, and no gitignored `.assessments/` history; do not bring them in
  ([owner-requirements](owner-requirements.md) item 1).
- **`tart_taste_test`**: a working instance of the template's Makefile recipes for
  `docs-lint` (copy the repository's Markdown to a scratch directory so that glossarian
  does not scan ignored files) and `llm-size-guard` (a throwaway Git index so that
  untracked files are scanned), and of the tracked size-guard state file, the macOS
  ignore rules, and the pinned linter commits. Useful for comparison when one of these
  misbehaves. Its `Makefile` pins the two linters with `git+ssh` URLs, which need a key;
  the template pins them with `git+https` URLs ([design-choices](design-choices.md),
  choice 13).
- **`auditable_script`**: a working instance of the template's decision log
  (`docs/decisions.md` as an index with rules, tags, two tables, and grep queries; one
  file per decision with typed front matter) and of its forms of open questions, out of
  scope, and deferred work. Its `backlog/sec_todo/` and its decision D33 are the source
  of "cheap to fix later is a statement about cost, not about safety". Its
  `tests/test_decision_log.py` is the model for the test backlog item B001 asks each
  project to write. Its decision D1 keeps no copy of a specification and states its
  conventions in its own documents: the opposite of
  [design-choices](design-choices.md), choice 10. Its `auditable_script_skill/` holds
  the trio rules and `review-prompt.md`, the prompt a trio review uses
  ([script-reviews](script-reviews.md)).
- **`glossarian/GLOSSARIAN_SPEC.md`**: the glossary grammar. A glossary has five `##`
  sections, the last being `Reserved Targets`; the `tart_taste_test` specification names
  only the first four.
- **`llm_file_size_guard/README.md`**: thresholds, configuration layers, and the
  `accept` and `defer` state.
- **The owner's assessment rubric**, pasted into the request of 2026-11-18: the source of
  `template/docs/greenfield/review-rubric.md`. The rubric here has none of the source's
  references to decision items (D8, E25, R1 and so on), no severity ladder, and no
  severity cut; each example that sits on a rung of the source's ladder is in the rubric
  as something to look for.
